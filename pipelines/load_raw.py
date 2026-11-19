"""Carga CSV a PostgreSQL RAW con COPY y una transacción por lote."""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
from pathlib import Path

import psycopg
from psycopg import sql
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = ROOT / "data" / "raw"
LOG_DIR = ROOT / "logs"

TABLE_COLUMNS = {
    "customers": ["customer_id", "first_name", "last_name", "email", "phone", "city", "state", "country", "signup_date", "acquisition_channel"],
    "products": ["product_id", "product_name", "category", "subcategory", "brand", "unit_cost", "list_price"],
    "orders": ["order_id", "customer_id", "order_ts", "status", "channel", "promo_code"],
    "order_items": ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_pct"],
    "payments": ["payment_id", "order_id", "method", "amount", "paid_ts", "status"],
    "shipments": ["shipment_id", "order_id", "carrier", "shipped_ts", "delivered_ts", "promised_date"],
}


def setup_logger():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("load_raw")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    fmt = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")
    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(fmt)
    file_handler = logging.FileHandler(LOG_DIR / "load_raw.log", encoding="utf-8")
    file_handler.setFormatter(fmt)
    logger.addHandler(console)
    logger.addHandler(file_handler)
    return logger


def connect():
    load_dotenv(ROOT / ".env")
    required = ["PG_USER", "PG_PASSWORD", "PG_DB"]
    missing = [key for key in required if not os.getenv(key)]
    if missing:
        raise RuntimeError("Faltan variables en .env: " + ", ".join(missing))
    return psycopg.connect(
        host=os.getenv("PG_HOST", "localhost"),
        port=os.getenv("PG_PORT", "5432"),
        user=os.environ["PG_USER"],
        password=os.environ["PG_PASSWORD"],
        dbname=os.environ["PG_DB"],
        connect_timeout=10,
    )


def find_batches(names):
    if names:
        paths = [(DATA_ROOT / name).resolve() for name in names]
        for path in paths:
            if path.parent != DATA_ROOT.resolve() or not path.is_dir():
                raise FileNotFoundError(f"Lote inválido: {path}")
        return paths
    paths = sorted(p for p in DATA_ROOT.glob("batch_*") if p.is_dir())
    if not paths:
        raise FileNotFoundError(f"No hay directorios batch_* en {DATA_ROOT}")
    return paths

##funcion principal para cargar los csv, con parametros de
##cur: cursor de postgres, path ruta, batch_id: identificador del lote, logger: para registrar la informacion.
def load_csv(cur, path, batch_id, logger):
    ##validacion para reconocer la tabla que se va a cargar, y que los nombrs del csv coincidan con la tabla esperada.
    table = path.stem
    if table not in TABLE_COLUMNS:
        raise ValueError(f"Archivo no reconocido: {path.name}")
    
    ##leer el encabezado del csv y validar que coincida con las columnas esperadas para la tabla.
    with path.open("r", newline="", encoding="utf-8-sig") as f:
        header = next(csv.reader(f), None)
    expected = TABLE_COLUMNS[table]
    if not header or len(header) != len(set(header)) or set(header) != set(expected):
        raise ValueError(f"Encabezado inválido en {path}. Esperado: {expected}; recibido: {header}")

    # Se respeta el orden del encabezado del CSV.
    ##consulta sql para crear una tabla temporal, copiar los datos del csv a la tabla temporal.
    cols = sql.SQL(", ").join(sql.Identifier(c) for c in header)
    temp = sql.Identifier("tmp_" + table)
    definitions = sql.SQL(", ").join(
        sql.SQL("{} TEXT").format(sql.Identifier(c)) for c in header
    )
    ##crear la tabla temporal con las columnas definidas, y se elimina al finalizar la transaccion.
    #esto permite que si hay un error en la carga de un archivo, se revierta todo el lote sin afectar la tabla final.
    cur.execute(
        sql.SQL("CREATE TEMP TABLE {} ({}) ON COMMIT DROP").format(temp, definitions)
    )

    ##copy es una forma eficiente de cargar datos en postgres, se utiliza para copiar los datos del csv a la tabla temporal y sirve para importar o exportar grandes cxantidades de registros.
    copy_stmt = sql.SQL(
        "COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE)"
    ).format(temp, cols)
    with cur.copy(copy_stmt) as copy, path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            copy.write(chunk)

    ##se eliminan las filas existentes en la tabla final que pertenecen al mismo lote, y se insertan las filas de la tabla temporal a la tabla final
    target = sql.Identifier("raw", table)
    cur.execute(
        sql.SQL("DELETE FROM {} WHERE _batch_id = %s").format(target),
        (batch_id,),
    )
    ##insertar los datos de la tabla temporal a la tabla final, agregando el batch_id, la fecha de carga y el nombre del archivo fuente.
    insert_stmt = sql.SQL(
        "INSERT INTO {} ({}, _batch_id, _loaded_at, _source_file) "
        "SELECT {}, %s, NOW(), %s FROM {}"
    ).format(target, cols, cols, temp)
    source_file = path.relative_to(ROOT).as_posix()
    cur.execute(insert_stmt, (batch_id, source_file))
    count = cur.rowcount
    logger.info("raw.%s | batch=%s | file=%s | rows=%s", table, batch_id, source_file, count)
    return count


def process_batch(conn, batch_dir, logger):
    batch_id = batch_dir.name  # ID estable: repetir el mismo lote reemplaza sus filas.
    csv_files = sorted(batch_dir.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No hay CSV en {batch_dir}")
    total = 0
    logger.info("Iniciando %s (%s archivos)", batch_id, len(csv_files))

    # Si un archivo falla, se revierte la carga de todas las tablas de este lote.
    with conn.transaction():
        with conn.cursor() as cur:
            for path in csv_files:
                total += load_csv(cur, path, batch_id, logger)

    logger.info("COMMIT lote=%s | total=%s", batch_id, total)
    return total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", action="append", help="Lote específico; puede repetirse.")
    args = parser.parse_args()
    logger = setup_logger()
    conn = None
    try:
        batches = find_batches(args.batch)
        logger.info("Lotes: %s", [p.name for p in batches])
        conn = connect()
        total = 0
        for batch_dir in batches:
            total += process_batch(conn, batch_dir, logger)
        logger.info("INGESTA FINALIZADA | filas=%s", total)
        return 0
    except Exception:
        logger.exception("Falló la ingesta. Revisa el error; el lote en curso fue revertido.")
        return 1
    #3se ejecuta tanto si elm procdeso termina correctamente como si ocurre una excepcion
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
