import os
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

RAW_DIR = ROOT / "data" / "raw"
LOG_DIR = ROOT / "logs"

TABLES = ["customers", "products", "orders", "order_items", "payments", "shipments"]


def db_params() -> dict:
    required = ["PG_USER", "PG_PASSWORD", "PG_DB"]
    missing = [key for key in required if not os.getenv(key)]
    if missing:
        raise RuntimeError("Faltan variables en .env: " + ", ".join(missing))
    return {
        "host": os.getenv("PG_HOST", "localhost"),
        "port": int(os.getenv("PG_PORT", "5432")),
        "dbname": os.environ["PG_DB"],
        "user": os.environ["PG_USER"],
        "password": os.environ["PG_PASSWORD"],
    }


# DB = {
#     "host": os.getenv("PG_HOST", "localhost"),
#     "port": int(os.getenv("PG_PORT", "5433")),
#     "dbname": os.environ["PG_DB"],
#     "user": os.environ["PG_USER"],
#     "password": os.environ["PG_PASSWORD"],
# }
