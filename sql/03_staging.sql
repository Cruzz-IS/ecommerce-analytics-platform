DROP SCHEMA IF EXISTS staging CASCADE;   -- en 03
CREATE SCHEMA staging;


CREATE OR REPLACE VIEW staging.customers AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.customers r
)
SELECT
    NULLIF(BTRIM(customer_id), '') AS customer_id,
    NULLIF(BTRIM(first_name), '') AS first_name,
    NULLIF(BTRIM(last_name), '') AS last_name,
    LOWER(NULLIF(BTRIM(email), '')) AS email,
    NULLIF(BTRIM(phone), '') AS phone,
    NULLIF(BTRIM(city), '') AS city,
    NULLIF(BTRIM(state), '') AS state,
    NULLIF(BTRIM(country), '') AS country,
    NULLIF(BTRIM(signup_date), '')::DATE AS signup_date,
    LOWER(NULLIF(BTRIM(acquisition_channel), '')) AS acquisition_channel,
    (LOWER(BTRIM(COALESCE(email, ''))) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$') AS email_is_valid,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;


CREATE OR REPLACE VIEW staging.products AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.products r
)
SELECT
    NULLIF(BTRIM(product_id), '') AS product_id,
    NULLIF(BTRIM(product_name), '') AS product_name,
    CASE
        WHEN LOWER(BTRIM(category)) = 'electronics' THEN 'Electronics'
        WHEN NULLIF(BTRIM(category), '') IS NULL THEN 'Unknown'
        ELSE INITCAP(BTRIM(category))
    END AS category,
    INITCAP(NULLIF(BTRIM(subcategory), '')) AS subcategory,
    INITCAP(NULLIF(BTRIM(brand), '')) AS brand,
    NULLIF(BTRIM(unit_cost), '')::NUMERIC(12,2) AS unit_cost,
    NULLIF(BTRIM(list_price), '')::NUMERIC(12,2) AS list_price,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;


CREATE OR REPLACE VIEW staging.orders AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.orders r
)
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(BTRIM(customer_id), '') AS customer_id,
    NULLIF(BTRIM(order_ts), '')::TIMESTAMP AS order_ts,
    LOWER(NULLIF(BTRIM(status), '')) AS status,
    LOWER(NULLIF(BTRIM(channel), '')) AS channel,
    NULLIF(BTRIM(promo_code), '') AS promo_code,
    EXISTS (
        SELECT 1 FROM staging.customers c
        WHERE c.customer_id = NULLIF(BTRIM(ranked.customer_id), '')
    ) AS customer_exists,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;


CREATE OR REPLACE VIEW staging.order_items AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.order_items r
)
SELECT
    NULLIF(BTRIM(order_item_id), '') AS order_item_id,
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(BTRIM(product_id), '') AS product_id,
    NULLIF(BTRIM(quantity), '')::INTEGER AS quantity,
    NULLIF(BTRIM(unit_price), '')::NUMERIC(12,2) AS unit_price,
    NULLIF(BTRIM(discount_pct), '')::NUMERIC(5,2) AS discount_pct,
    EXISTS (
        SELECT 1 FROM staging.products p
        WHERE p.product_id = NULLIF(BTRIM(ranked.product_id), '')
    ) AS product_exists,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;


CREATE OR REPLACE VIEW staging.payments AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.payments r
)
SELECT
    NULLIF(BTRIM(payment_id), '') AS payment_id,
    NULLIF(BTRIM(order_id), '') AS order_id,
    LOWER(NULLIF(BTRIM(method), '')) AS method,
    NULLIF(BTRIM(amount), '')::NUMERIC(12,2) AS amount,
    NULLIF(BTRIM(paid_ts), '')::TIMESTAMP AS paid_ts,
    LOWER(NULLIF(BTRIM(status), '')) AS status,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;


CREATE OR REPLACE VIEW staging.shipments AS
WITH ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (PARTITION BY shipment_id ORDER BY _batch_id DESC, _loaded_at DESC) AS rn
    FROM raw.shipments r
)
SELECT
    NULLIF(BTRIM(shipment_id), '') AS shipment_id,
    NULLIF(BTRIM(order_id), '') AS order_id,
    INITCAP(NULLIF(BTRIM(carrier), '')) AS carrier,
    NULLIF(BTRIM(shipped_ts), '')::TIMESTAMP AS shipped_ts,
    NULLIF(BTRIM(delivered_ts), '')::TIMESTAMP AS delivered_ts,
    NULLIF(BTRIM(promised_date), '')::DATE AS promised_date,
    CASE
        WHEN NULLIF(BTRIM(delivered_ts), '') IS NULL OR NULLIF(BTRIM(shipped_ts), '') IS NULL THEN NULL
        ELSE NULLIF(BTRIM(delivered_ts), '')::TIMESTAMP >= NULLIF(BTRIM(shipped_ts), '')::TIMESTAMP
    END AS delivery_chronology_valid,
    _batch_id, _loaded_at, _source_file
FROM ranked WHERE rn = 1;
