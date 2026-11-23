"""Pruebas en la base de datos de Postgre.
"""

import psycopg
import pytest

from pipelines.config import db_params

pytestmark = pytest.mark.db


def existe_vista(conn, esquema, nombre):
    return conn.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_schema = %s AND table_name = %s",
        (esquema, nombre),
    ).fetchone() is not None

# -raw - staging

def test_raw_tiene_los_dos_lotes(conn):
    lotes = {r[0] for r in conn.execute("SELECT DISTINCT _batch_id FROM raw.orders")}
    assert {"batch_001", "batch_002"} <= lotes


def test_staging_pedidos_sin_duplicados(scalar):
    assert scalar("SELECT count(*) - count(DISTINCT order_id) FROM staging.orders") == 0


def test_staging_deja_un_registro_por_pedido_de_raw(scalar):
    en_raw = scalar("SELECT count(DISTINCT btrim(order_id)) FROM raw.orders")
    assert scalar("SELECT count(*) FROM staging.orders") == en_raw


def test_gana_la_version_del_lote_mas_reciente(scalar):
    distintos = scalar("""
        SELECT count(*) FROM staging.orders s
        JOIN raw.orders r ON btrim(r.order_id) = s.order_id AND r._batch_id = 'batch_002'
        WHERE s.status <> lower(btrim(r.status))
    """)
    assert distintos == 0


def test_staging_normaliza_categorias(conn):
    categorias = [r[0] for r in conn.execute("SELECT DISTINCT category FROM staging.products")]
    assert len(categorias) == len({c.lower().strip() for c in categorias})


# - staging - marts

@pytest.mark.parametrize("origen, destino", [
    ("staging.orders", "marts.fact_orders"),
    ("staging.order_items", "marts.fact_order_items"),
    ("staging.payments", "marts.fact_payments"),
    ("staging.shipments", "marts.fact_shipments"),
])
def test_los_hechos_no_pierden_filas(scalar, origen, destino):
    assert scalar(f"SELECT count(*) FROM {origen}") == scalar(f"SELECT count(*) FROM {destino}")


@pytest.mark.parametrize("tabla, clave", [
    ("marts.dim_customer", "customer_key"),
    ("marts.dim_product", "product_key"),
    ("marts.fact_orders", "order_key"),
    ("marts.fact_order_items", "order_item_key"),
])
def test_claves_sustitutas_unicas_y_sin_nulos(scalar, tabla, clave):
    assert scalar(f"SELECT count(*) - count(DISTINCT {clave}) FROM {tabla}") == 0
    assert scalar(f"SELECT count(*) FROM {tabla} WHERE {clave} IS NULL") == 0


@pytest.mark.parametrize("hecho, columna, dimension, clave", [
    ("marts.fact_orders", "customer_key", "marts.dim_customer", "customer_key"),
    ("marts.fact_orders", "order_date_key", "marts.dim_date", "date_key"),
    ("marts.fact_order_items", "order_key", "marts.fact_orders", "order_key"),
    ("marts.fact_order_items", "product_key", "marts.dim_product", "product_key"),
    ("marts.fact_payments", "order_key", "marts.fact_orders", "order_key"),
    ("marts.fact_shipments", "order_key", "marts.fact_orders", "order_key"),
])
def test_todo_hecho_apunta_a_una_dimension_existente(scalar, hecho, columna, dimension, clave):
    sin_dimension = scalar(f"""
        SELECT count(*) FROM {hecho} f
        LEFT JOIN {dimension} d ON d.{clave} = f.{columna}
        WHERE d.{clave} IS NULL
    """)
    assert sin_dimension == 0


def test_clientes_desconocidos_son_los_pedidos_huerfanos(scalar):
    huerfanos = scalar("""
        SELECT count(*) FROM staging.orders o
        WHERE NOT EXISTS (SELECT 1 FROM staging.customers c WHERE c.customer_id = o.customer_id)
    """)
    assert huerfanos > 0
    assert scalar("SELECT count(*) FROM marts.fact_orders WHERE customer_key = -1") == huerfanos


def test_ventas_validas_cuadran_entre_pedidos_items_y_pagos(scalar):
    pedidos = scalar("SELECT sum(net_amount) FROM marts.fact_orders WHERE status <> 'cancelled'")
    items = scalar("""
        SELECT sum(i.net_amount) FROM marts.fact_order_items i
        JOIN marts.fact_orders o USING (order_key) WHERE o.status <> 'cancelled'
    """)
    pagos = scalar("""
        SELECT sum(p.amount) FROM marts.fact_payments p
        JOIN marts.fact_orders o USING (order_key) WHERE o.status <> 'cancelled'
    """)
    assert abs(pedidos - items) < 0.01
    assert abs(pedidos - pagos) < 0.01


def test_no_hay_pagos_paid_en_pedidos_cancelados(scalar):
    assert scalar("""
        SELECT count(*) FROM marts.fact_payments p
        JOIN marts.fact_orders o USING (order_key)
        WHERE o.status = 'cancelled' AND p.status = 'paid'
    """) == 0


def test_tiempos_de_entrega_solo_en_pedidos_entregados(scalar):
    assert scalar("""
        SELECT count(*) FROM marts.fact_orders
        WHERE days_to_deliver IS NOT NULL AND status NOT IN ('delivered', 'completed')
    """) == 0


# - capa 5 de bi 

@pytest.fixture
def requiere_bi(conn):
    if not existe_vista(conn, "bi", "kpi_summary"):
        pytest.skip("Todavía no existe bi.kpi_summary (ejecuta sql/05_bi.sql)")


def test_kpi_summary_coincide_con_marts(scalar, requiere_bi):
    ventas = scalar("SELECT sum(net_amount) FROM marts.fact_orders WHERE status <> 'cancelled'")
    assert abs(scalar("SELECT net_sales FROM bi.kpi_summary") - ventas) < 0.01
    assert scalar("SELECT count(*) FROM bi.kpi_summary") == 1


def test_sales_daily_coincide_con_kpi_summary(scalar, conn, requiere_bi):
    if not existe_vista(conn, "bi", "sales_daily"):
        pytest.skip("Todavía no existe bi.sales_daily")
    diario = scalar("SELECT sum(net_sales) FROM bi.sales_daily")
    assert abs(diario - scalar("SELECT net_sales FROM bi.kpi_summary")) < 0.01


def test_rfm_tiene_los_mismos_clientes_que_el_kpi(scalar, conn, requiere_bi):
    if not existe_vista(conn, "bi", "customer_rfm"):
        pytest.skip("Todavía no existe bi.customer_rfm")
    assert scalar("SELECT count(*) FROM bi.customer_rfm") == scalar("SELECT customers FROM bi.kpi_summary")


def test_cohortes_empiezan_en_100_por_ciento(scalar, conn, requiere_bi):
    if not existe_vista(conn, "bi", "cohort_retention"):
        pytest.skip("Todavía no existe bi.cohort_retention")
    assert scalar("SELECT min(retention_pct) FROM bi.cohort_retention WHERE months_since = 0") == 100


# --seguridad de la base de datos

def test_bi_reader_lee_bi_pero_no_marts_ni_escribe(bi_reader_password, requiere_bi):
    params = {**db_params(), "user": "bi_reader", "password": bi_reader_password}
    with psycopg.connect(**params, connect_timeout=5, autocommit=True) as c:
        assert c.execute("SELECT count(*) FROM bi.kpi_summary").fetchone()[0] == 1
        assert c.execute("SHOW default_transaction_read_only").fetchone()[0] == "on"
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            c.execute("SELECT 1 FROM marts.fact_orders LIMIT 1")
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            c.execute("SELECT 1 FROM raw.orders LIMIT 1")
        with pytest.raises((psycopg.errors.ReadOnlySqlTransaction, psycopg.errors.InsufficientPrivilege)):
            c.execute("CREATE TABLE bi.prueba_no_permitida (a int)")