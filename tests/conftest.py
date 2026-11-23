"""Caracteristicas compartidos por las pruebas."""

import os
import subprocess
import sys

import psycopg
import pytest

from pipelines.config import ROOT, db_params


def run_generator(output_dir, orders=20_000, customers=4_000, products=200, seed=42):
    """Prueba para ejecutar el generador de los csv"""
    cmd = [
        sys.executable, "-m", "pipelines.generate_data",
        "--output", str(output_dir),
        "--orders", str(orders),
        "--customers", str(customers),
        "--products", str(products),
        "--seed", str(seed),
    ]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return output_dir


@pytest.fixture(scope="session")
def generator():
    return run_generator


@pytest.fixture(scope="session")
def generated_data(tmp_path_factory):
    """Datos sinteticos que se generan una sola vez para todas las pruebas."""
    return run_generator(tmp_path_factory.mktemp("datos"))


@pytest.fixture(scope="session")
def conn():
    """prueba de la conexion a la base. Si no hay base disponible se omiten las pruebas"""
    try:
        connection = psycopg.connect(**db_params(), connect_timeout=5)
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"No hay base de datos disponible: {exc}")
    yield connection
    connection.close()


@pytest.fixture(scope="session")
def scalar(conn):
    """ejecuta una consulta y devuelve el primer valor de la primera fila."""
    def _scalar(query, params=None):
        return conn.execute(query, params).fetchone()[0]
    return _scalar


@pytest.fixture(scope="session")
def bi_reader_password():
    password = os.getenv("BI_READER_PASSWORD")
    if not password:
        pytest.skip("Define BI_READER_PASSWORD en tu entorno para probar el rol de solo lectura")
    return password