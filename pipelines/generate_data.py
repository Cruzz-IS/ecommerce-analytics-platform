"""
Generador de datos para una plataforma e-commerce.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from collections import defaultdict


CUSTOMER_COLUMNS = [
    "customer_id", "first_name", "last_name", "email", "phone",
    "city", "state", "country", "signup_date", "acquisition_channel",
]
PRODUCT_COLUMNS = [
    "product_id", "product_name", "category", "subcategory",
    "brand", "unit_cost", "list_price",
]
ORDER_COLUMNS = [
    "order_id", "customer_id", "order_ts", "status", "channel", "promo_code",
]
ORDER_ITEM_COLUMNS = [
    "order_item_id", "order_id", "product_id", "quantity",
    "unit_price", "discount_pct",
]
PAYMENT_COLUMNS = [
    "payment_id", "order_id", "method", "amount", "paid_ts", "status",
]
SHIPMENT_COLUMNS = [
    "shipment_id", "order_id", "carrier", "shipped_ts",
    "delivered_ts", "promised_date",
]

FIRST_NAMES = [
    "Ana", "Carlos", "Maria", "Jose", "Sofia", "Daniel", "Valeria",
    "Luis", "Gabriela", "Miguel", "Andrea", "David", "Camila",
    "Jorge", "Isabella", "Fernando", "Lucia", "Diego", "Paula", "Mateo",
]
LAST_NAMES = [
    "Garcia", "Rodriguez", "Lopez", "Martinez", "Hernandez", "Gonzalez",
    "Perez", "Sanchez", "Ramirez", "Torres", "Flores", "Rivera",
    "Gomez", "Diaz", "Cruz", "Reyes", "Morales", "Castro",
]
CITIES = [
    ("Tegucigalpa", "Francisco Morazan", "Honduras"),
    ("San Pedro Sula", "Cortes", "Honduras"),
    ("La Ceiba", "Atlantida", "Honduras"),
    ("Comayagua", "Comayagua", "Honduras"),
    ("Choloma", "Cortes", "Honduras"),
    ("Roatan", "Islas de la Bahia", "Honduras"),
    ("Guatemala City", "Guatemala", "Guatemala"),
    ("San Salvador", "San Salvador", "El Salvador"),
]
CHANNELS = ["web", "mobile_app", "marketplace", "store"]
ACQUISITION_CHANNELS = ["organic", "paid_search", "social_media", "referral", "email"]
ORDER_STATUSES = ["pending", "processing", "shipped", "delivered", "cancelled"]
STATUS_WEIGHTS = [8, 14, 18, 52, 8]
PAYMENT_METHODS = ["credit_card", "debit_card", "bank_transfer", "cash_on_delivery", "wallet"]
PAYMENT_STATUSES = ["paid", "pending", "failed", "refunded"]
CARRIERS = ["DHL", "FedEx", "UPS", "USPS", "Cargo Expreso", "Honduras Express"]
CATEGORIES = {
    "Electronics": ["Smartphones", "Laptops", "Accessories", "Audio"],
    "Clothing": ["Men", "Women", "Shoes", "Accessories"],
    "Home & Kitchen": ["Furniture", "Kitchenware", "Decoration"],
    "Beauty": ["Skincare", "Makeup", "Haircare"],
    "Sports": ["Fitness", "Outdoor", "Sportswear"],
    "Books": ["Fiction", "Education", "Technology"],
    "Toys": ["Educational", "Games", "Outdoor Toys"],
}
BRANDS = [
    "NovaTech", "UrbanStyle", "HomePro", "Luma", "ActiveLife",
    "BrightHouse", "Apex", "Northstar", "Everyday", "Vertex",
]


def random_datetime(rng: random.Random, start: datetime, end: datetime) -> datetime:
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=rng.randint(0, seconds))


def money(value: Decimal) -> str:
    return f"{value:.2f}"


def write_csv(path: Path, columns: list[str], rows) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
            count += 1
    return count

## funcion para generar los clintes.
def generate_customers(rng: random.Random, count: int) -> list[dict]:
    rows = []
    ##calcular el 3% de los clientes para introducir errores intencionales.
    bad_count = round(count * 0.03)
    ##selecionar las 600 posiciones de los 20,000 clientes para introducir errores intencionales.
    ##set almacena las 600 posiciones como conjunto.
    ##la mitad de estas posiciones se seleccionaran para introducir valores nulos en el campo email.
    bad_indices = set(rng.sample(range(count), bad_count))
    null_count = bad_count // 2
    null_indices = set(rng.sample(sorted(bad_indices), null_count))

    ##generacion de los clientes con datos correctos y errores intencionales en el campo email.
    for i in range(1, count + 1):
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        email = f"{first.lower()}.{last.lower()}{i}@example.com"

        if i - 1 in bad_indices:
            if i - 1 in null_indices:
                email = ""
            else:
                email = rng.choice([
                    f"{first.lower()}..{last.lower()}@",
                    f"{first.lower()}@example",
                    f"{first.lower()} {last.lower()}@example.com",
                    "not-an-email",
                ])

        city, state, country = rng.choice(CITIES)
        signup = date(2023, 1, 1) + timedelta(days=rng.randint(0, 1000))
        rows.append({
            "customer_id": f"C{i:07d}",
            "first_name": first,
            "last_name": last,
            "email": email,
            "phone": f"+504{rng.randint(20000000, 99999999)}",
            "city": city,
            "state": state,
            "country": country,
            "signup_date": signup.isoformat(),
            "acquisition_channel": rng.choice(ACQUISITION_CHANNELS),
        })
    return rows


def generate_products(rng: random.Random, count: int) -> list[dict]:
    rows = []
    category_names = list(CATEGORIES)
    ##generar variantes de la categoria "Electronics" para introducir errores intencionales en el campo category.
    ##para practica de normalizacion de datos en SQL.
    electronics_variant_values = ["Electronics", "electronics ", "ELECTRONICS"]

    for i in range(1, count + 1):
        category = rng.choice(category_names)
        if category == "Electronics" and rng.random() < 0.65:
            category = rng.choice(electronics_variant_values)

        canonical = category.strip().title()
        if canonical == "Electronics":
            canonical = "Electronics"
        subcategories = CATEGORIES.get(canonical, ["General"])
        
        subcategory = rng.choice(subcategories)
        brand = rng.choice(BRANDS)
        
        ##calculos de costos y precios
        unit_cost = Decimal(rng.randint(300, 50000)) / Decimal("100")
        markup = Decimal(rng.randint(115, 220)) / Decimal("100")
        list_price = (unit_cost * markup).quantize(Decimal("0.01"))

        rows.append({
            "product_id": f"P{i:06d}",
            "product_name":  f"{brand} {subcategory} Model {i:04d}",
            "category": category,
            "subcategory": subcategory, "brand": brand,
            "brand": rng.choice(BRANDS),
            "unit_cost": money(unit_cost),
            "list_price": money(list_price),
        })
    return rows


def generate_orders(
    rng: random.Random,
    count: int,
    customer_ids: list[str],
    start: datetime,
    end: datetime,
) -> list[dict]:
    rows = []
    orphan_count = round(count * 0.002)
    orphan_indices = set(rng.sample(range(count), orphan_count))

    for i in range(1, count + 1):
        customer_id = rng.choice(customer_ids)
        if i - 1 in orphan_indices:
            customer_id = f"C999{rng.randint(1000, 9999)}"

        order_ts = random_datetime(rng, start, end)
        rows.append({
            "order_id": f"O{i:09d}",
            "customer_id": customer_id,
            "order_ts": order_ts.strftime("%Y-%m-%d %H:%M:%S"),
            ## status se elige con pesos para reflejar la distribución realista de estados de pedidos, seleccionando los elementos de la lisa y asignandoles un peso.
            "status": rng.choices(ORDER_STATUSES, weights=STATUS_WEIGHTS, k=1)[0],
            "channel": rng.choice(CHANNELS),
            "promo_code": rng.choice(["", "", "", "WELCOME10", "SUMMER15", "FREESHIP"]),
        })

    # Agrega aproximadamente 1% de filas duplicadas adicionales solo al CSV.
    base_rows = rows.copy()
    duplicate_count = round(count * 0.01)
    duplicate_indices = rng.sample(range(count), duplicate_count)
    output_rows = rows + [rows[index].copy() for index in duplicate_indices]
    rng.shuffle(output_rows)
    return base_rows, output_rows


def generate_order_items(
    rng: random.Random,
    base_orders: list[dict],
    products: list[dict],
) -> list[dict]:
    ##transforma la lista de los productos en un diccionario para acceder a ellos por product_id.
    product_by_id = {p["product_id"]: p for p in products}
    rows = []
    item_number = 1

    for order in base_orders:
        item_count = rng.randint(1, 5)
        for _ in range(item_count):
            product = rng.choice(products)
            quantity = rng.randint(1, 4)
            list_price = Decimal(product["list_price"])
            discount = rng.choice([0, 0, 0, 5, 10, 15, 20])
            ##calculo del precio unitario aplicando el descuento al precio de lista y redondeando a dos decimales.
            unit_price = (list_price * (Decimal("1") - Decimal(discount) / 100)).quantize(
                Decimal("0.01")
            )
            rows.append({
                "order_item_id": f"OI{item_number:010d}",
                "order_id": order["order_id"],
                "product_id": product["product_id"],
                "quantity": str(quantity),
                "unit_price": money(unit_price),
                "discount_pct": str(discount),
            })
            item_number += 1

    return rows

##generar pagos por cada orden, con un tiempo de pago aleatorio y un monto basado en un rango de valores.
def order_totals(order_items):
    totals = defaultdict(Decimal)
    for item in order_items:
        totals[item["order_id"]] += Decimal(item["unit_price"]) * Decimal(item["quantity"])
    return totals

def payment_status(rng, order_status):
    if order_status == "cancelled":
        return rng.choices(["failed", "refunded", "pending"], weights=[50, 30, 20], k=1)[0]
    if order_status in ("pending", "processing"):
        return rng.choices(["paid", "pending"], weights=[60, 40], k=1)[0]
    return rng.choices(["paid", "refunded"], weights=[97, 3], k=1)[0]

def generate_payments(rng, base_orders, order_items):
    totals = order_totals(order_items)
    rows = []
    for i, order in enumerate(base_orders, start=1):
        order_ts = datetime.strptime(order["order_ts"], "%Y-%m-%d %H:%M:%S")
        paid_ts = order_ts + timedelta(minutes=rng.randint(1, 180))
        amount = totals[order["order_id"]].quantize(Decimal("0.01"))
        rows.append({
            "payment_id": f"PAY{i:09d}",
            "order_id": order["order_id"],
            "method": rng.choice(PAYMENT_METHODS),
            "amount": money(amount),
            "paid_ts": paid_ts.strftime("%Y-%m-%d %H:%M:%S"),
            "status": payment_status(rng, order["status"]),
        })
    return rows

## solo se considera elegible para generar envios aquellos pedidos que tengan un estado de "shipped" o "delivered". Se genera un tiempo de envio y entrega aleatorio para cada pedido elegible, y se introduce un pequeño porcentaje de errores intencionales donde la fecha de entrega es anterior a la fecha de envio.
def generate_shipments(
    rng: random.Random,
    base_orders: list[dict],
) -> list[dict]:
    rows = []
    eligible = [o for o in base_orders if o["status"] in ("shipped", "delivered")]
    shipment_orders = [o for o in eligible if rng.random() < 0.96]
    delivered_idx = [k for k, o in enumerate(shipment_orders) if o["status"] == "delivered"]
    bad_count = round(len(delivered_idx) * 0.005)
    bad_indices = set(rng.sample(delivered_idx, bad_count)) if bad_count else set()

    delivered_ts = None
    if order["status"] == "delivered":
        delivered_ts = shipped_ts + timedelta(hours=rng.randint(12, 120))
        if i - 1 in bad_indices:
            delivered_ts = shipped_ts - timedelta(hours=rng.randint(1, 48))
    # en el diccionario:
    "delivered_ts": delivered_ts.strftime("%Y-%m-%d %H:%M:%S") if delivered_ts else "", if bad_count else set()

    for i, order in enumerate(shipment_orders, start=1):
        order_ts = datetime.strptime(order["order_ts"], "%Y-%m-%d %H:%M:%S")
        shipped_ts = order_ts + timedelta(hours=rng.randint(2, 72))
        delivered_ts = shipped_ts + timedelta(hours=rng.randint(12, 120))

        ##aqui es donde se introducen los errores de fechas, de manera intencional
        if i - 1 in bad_indices:
            delivered_ts = shipped_ts - timedelta(hours=rng.randint(1, 48))

        promised_date = (shipped_ts.date() + timedelta(days=rng.randint(2, 7))).isoformat()
        rows.append({
            "shipment_id": f"SH{i:09d}",
            "order_id": order["order_id"],
            "carrier": rng.choice(CARRIERS),
            "shipped_ts": shipped_ts.strftime("%Y-%m-%d %H:%M:%S"),
            "delivered_ts": delivered_ts.strftime("%Y-%m-%d %H:%M:%S"),
            "promised_date": promised_date,
        })
    return rows


def generate_order_updates(
    rng: random.Random,
    base_orders: list[dict],
    update_rate: float,
) -> list[dict]:
    ###definir las transiciones de estado de los pedidos.
    ##### Para hacer cargas incrementales de datos.
    transitions = {
        "pending": "processing",
        "processing": "shipped",
        "shipped": "delivered",
        "delivered": "completed",
    }
    ##seciencia de cambios posibles de las ordenes, para hacer un seguimiento de los cambios de estado de los pedidos.
    eligible = [o for o in base_orders if o["status"] in transitions]
    ##seleccionamos las ordenes que pueden avanzar de estado, y calculamos cuantas de estas ordenes se van a actualizar en el segundo lote de datos.
    update_count = min(len(eligible), round(len(base_orders) * update_rate))
    selected = rng.sample(eligible, update_count)
    updates = []

    ##seleccionar ordenes que recibiran una nueva version en el segundo lote de datos, y actualizamos su estado segun las transiciones definidas.
    for original in selected:
        updated = original.copy()
        updated["status"] = transitions[original["status"]]
        updates.append(updated)

    rng.shuffle(updates)
    return updates


def main() -> None:
    ##configurar el puno de entrada del generardor de datos, para que el usuario pueda especificar la cantidad de pedidos, clientes y productos a generar, asi como la semilla para la reproducibilidad y la tasa de actualizacion para el segundo lote de datos.
    parser = argparse.ArgumentParser(description="Genera CSV sintéticos para e-commerce.")
    parser.add_argument("--orders", type=int, default=100_000, help="Cantidad de pedidos base.")
    parser.add_argument("--customers", type=int, default=20_000, help="Cantidad de clientes.")
    parser.add_argument("--products", type=int, default=500, help="Cantidad de productos.")
    parser.add_argument("--seed", type=int, default=42, help="Semilla para reproducibilidad.")
    parser.add_argument(
        "--update-rate", type=float, default=0.10,
        help="Proporción de pedidos base que tendrá actualización en batch_002.",
    )
    parser.add_argument(
        "--output", type=Path, default=Path("data/raw"),
        help="Directorio raíz de salida.",
    )
    args = parser.parse_args()

    if args.orders < 1 or args.customers < 1 or args.products < 1:
        parser.error("orders, customers y products deben ser mayores que cero.")
    if not 0 <= args.update_rate <= 1:
        parser.error("--update-rate debe estar entre 0 y 1.")

##generador de datos reproducible con la semilla proporcionada, lo que significa que si se ejecuta el script con la misma semilla, se obtendran los mismos datos de salida. Esto nos servira como una para pruebas y desarrollo, ya que permite generar conjuntos de datos consistentes y comparables.
    rng = random.Random(args.seed)
    batch_001 = args.output / "batch_001"
    batch_002 = args.output / "batch_002"
    batch_001.mkdir(parents=True, exist_ok=True)
    batch_002.mkdir(parents=True, exist_ok=True)

    start = datetime(2025, 1, 1)
    end = datetime(2026, 10, 31, 23, 59, 59)

    print("Generando clientes...")
    customers = generate_customers(rng, args.customers)
    customer_count = write_csv(batch_001 / "customers.csv", CUSTOMER_COLUMNS, customers)
    customer_ids = [c["customer_id"] for c in customers]

    print("Generando productos...")
    products = generate_products(rng, args.products)
    product_count = write_csv(batch_001 / "products.csv", PRODUCT_COLUMNS, products)

    print("Generando pedidos...")
    base_orders, all_order_rows = generate_orders(
        rng, args.orders, customer_ids, start, end
    )
    order_count = write_csv(batch_001 / "orders.csv", ORDER_COLUMNS, all_order_rows)

    print("Generando artículos de pedido...")
    order_items = generate_order_items(rng, base_orders, products)
    order_item_count = write_csv(
        batch_001 / "order_items.csv", ORDER_ITEM_COLUMNS, order_items
    )

    print("Generando pagos...")
    payments = generate_payments(rng, base_orders, order_items)
    payment_count = write_csv(batch_001 / "payments.csv", PAYMENT_COLUMNS, payments)

    print("Generando envíos...")
    shipments = generate_shipments(rng, base_orders)
    shipment_count = write_csv(batch_001 / "shipments.csv", SHIPMENT_COLUMNS, shipments)

    print("Generando segundo lote de actualizaciones...")
    updates = generate_order_updates(rng, base_orders, args.update_rate)
    update_count = write_csv(batch_002 / "orders.csv", ORDER_COLUMNS, updates)

    manifest = {
        "seed": args.seed,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "base_orders_requested": args.orders,
        "update_rate": args.update_rate,
        "files": {
            "batch_001/customers.csv": customer_count,
            "batch_001/products.csv": product_count,
            "batch_001/orders.csv": order_count,
            "batch_001/order_items.csv": order_item_count,
            "batch_001/payments.csv": payment_count,
            "batch_001/shipments.csv": shipment_count,
            "batch_002/orders.csv": update_count,
        },
        "intentional_quality_issues": {
            "orders_duplicate_rows": round(args.orders * 0.01),
            "customers_email_null_or_malformed": round(args.customers * 0.03),
            "products_electronics_category_variants": "Electronics / electronics  / ELECTRONICS",
            "shipments_delivered_before_shipped": round(shipment_count * 0.005),
            "orders_with_nonexistent_customer": round(args.orders * 0.002),
            "orders_updated_in_batch_002": update_count,
        },
        "notes": [
            "Los porcentajes son aproximados y se calculan sobre el volumen base indicado.",
            "Los CSV no incluyen _batch_id, _loaded_at ni _source_file; los agrega la ingesta.",
            "batch_002/orders.csv contiene versiones más recientes de order_id existentes.",
            "El generador es reproducible si se usa la misma semilla (--seed).",
        ],
    }
    manifest_path = args.output / "generation_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print("\nGeneración completada.")
    print(f"Directorio: {args.output.resolve()}")
    for filename, count in manifest["files"].items():
        print(f"  {filename}: {count:,} filas")
    print(f"  Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
