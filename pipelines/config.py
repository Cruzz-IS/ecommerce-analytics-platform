import os
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

RAW_DIR = ROOT / "data" / "raw"

DB = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "dbname": os.environ["PG_DB"],
    "user": os.environ["PG_USER"],
    "password": os.environ["PG_PASSWORD"],
}

TABLES = ["customers", "products", "orders", "order_items", "payments", "shipments"]