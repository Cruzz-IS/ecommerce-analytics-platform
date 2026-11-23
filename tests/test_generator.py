"""Pruebas del generador de datos sinteticos"""

import hashlib
import re
from pathlib import Path

import pandas as pd

from pipelines.load_raw import TABLE_COLUMNS

EMAIL_RE = re.compile(r"^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$")


def md5_por_archivo(carpeta: Path) -> dict:
    return {
        str(f.relative_to(carpeta)): hashlib.md5(f.read_bytes()).hexdigest()
        for f in sorted(carpeta.rglob("*.csv"))
    }


def leer(carpeta: Path, lote: str, tabla: str) -> pd.DataFrame:
    return pd.read_csv(carpeta / lote / f"{tabla}.csv", dtype=str, keep_default_na=False)


def pedidos_unicos(carpeta: Path) -> pd.DataFrame:
    return leer(carpeta, "batch_001", "orders").drop_duplicates("order_id")


# ---prueba de generacion de datos

def test_misma_semilla_genera_archivos_identicos(generator, tmp_path):
    a = generator(tmp_path / "a", orders=2_000, customers=400, products=60, seed=42)
    b = generator(tmp_path / "b", orders=2_000, customers=400, products=60, seed=42)
    assert md5_por_archivo(a) == md5_por_archivo(b)


def test_otra_semilla_cambia_los_datos(generator, tmp_path):
    a = generator(tmp_path / "a", orders=2_000, customers=400, products=60, seed=42)
    b = generator(tmp_path / "b", orders=2_000, customers=400, products=60, seed=7)
    assert md5_por_archivo(a)["batch_001/orders.csv"] != md5_por_archivo(b)["batch_001/orders.csv"]


# --prueba para verificar que los encabezados de los archivos generados coinciden con lo que espera load_raw.py

def test_encabezados_coinciden_con_lo_que_espera_load_raw(generated_data):
    for archivo in sorted(generated_data.rglob("*.csv")):
        encabezado = list(pd.read_csv(archivo, nrows=0).columns)
        esperado = TABLE_COLUMNS[archivo.stem]
        assert set(encabezado) == set(esperado), archivo
        assert len(encabezado) == len(set(encabezado)), f"columnas repetidas en {archivo}"


# ---prueba de errores intencionales 

def test_pedidos_duplicados_cercanos_al_1_por_ciento(generated_data):
    pedidos = leer(generated_data, "batch_001", "orders")
    tasa = pedidos["order_id"].duplicated().mean()
    assert 0.007 <= tasa <= 0.013, tasa


def test_pedidos_huerfanos_cercanos_al_0_2_por_ciento(generated_data):
    clientes = set(leer(generated_data, "batch_001", "customers")["customer_id"])
    pedidos = pedidos_unicos(generated_data)
    tasa = (~pedidos["customer_id"].isin(clientes)).mean()
    assert 0.001 <= tasa <= 0.004, tasa


def test_correos_invalidos_o_vacios_cercanos_al_3_por_ciento(generated_data):
    correos = leer(generated_data, "batch_001", "customers")["email"].str.lower().str.strip()
    tasa = (~correos.apply(lambda e: bool(EMAIL_RE.match(e)))).mean()
    assert 0.02 <= tasa <= 0.045, tasa


def test_entregas_anteriores_al_envio_cercanas_al_0_5_por_ciento(generated_data):
    envios = leer(generated_data, "batch_001", "shipments")
    envios = envios[envios["delivered_ts"] != ""]
    mala = pd.to_datetime(envios["delivered_ts"]) < pd.to_datetime(envios["shipped_ts"])
    assert 0.002 <= mala.mean() <= 0.010, mala.mean()


# --Prueba para validar la consistencia de las tablas

def test_monto_del_pago_es_la_suma_de_los_items_del_pedido(generated_data):
    items = leer(generated_data, "batch_001", "order_items")
    items["total"] = items["quantity"].astype(int) * items["unit_price"].astype(float)
    esperado = items.groupby("order_id")["total"].sum().round(2)
    pagos = leer(generated_data, "batch_001", "payments").set_index("order_id")["amount"].astype(float)
    comparado = pd.concat([esperado, pagos], axis=1, keys=["items", "pago"]).dropna()
    assert len(comparado) == len(pagos)
    assert ((comparado["items"] - comparado["pago"]).abs() < 0.011).all()


def test_pedidos_shipped_no_tienen_fecha_de_entrega(generated_data):
    pedidos = pedidos_unicos(generated_data)[["order_id", "status"]]
    envios = leer(generated_data, "batch_001", "shipments").merge(pedidos, on="order_id")
    shipped = envios[envios["status"] == "shipped"]
    assert len(shipped) > 0
    assert (shipped["delivered_ts"] == "").all()


def test_pedidos_cancelados_no_tienen_pagos_paid(generated_data):
    pedidos = pedidos_unicos(generated_data)[["order_id", "status"]]
    pagos = leer(generated_data, "batch_001", "payments").merge(
        pedidos, on="order_id", suffixes=("_pago", "_pedido")
    )
    cancelados = pagos[pagos["status_pedido"] == "cancelled"]
    assert len(cancelados) > 0
    assert not (cancelados["status_pago"] == "paid").any()


def test_segundo_lote_solo_actualiza_pedidos_existentes(generated_data):
    base = pedidos_unicos(generated_data).set_index("order_id")
    update = leer(generated_data, "batch_002", "orders").set_index("order_id")
    assert update.index.isin(base.index).all()
    assert 0.08 <= len(update) / len(base) <= 0.12
    assert (update["status"] != base.loc[update.index, "status"]).all()