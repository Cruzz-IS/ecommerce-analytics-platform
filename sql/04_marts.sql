-- Modelo analitico inicial mediante tablas
DROP SCHEMA IF EXISTS marts CASCADE;    
CREATE SCHEMA marts;

-- Dimensiones 
CREATE TABLE marts.dim_date AS
SELECT to_char(d, 'YYYYMMDD')::int           AS date_key,
       d::date                               AS date,
       EXTRACT(year FROM d)::int             AS year,
       EXTRACT(quarter FROM d)::int          AS quarter,
       EXTRACT(month FROM d)::int            AS month,
       TO_CHAR(d, 'IW')            AS week_number,    
       trim(to_char(d, 'Month'))             AS month_name,
       EXTRACT(isodow FROM d)::int           AS day_of_week,
       EXTRACT(isodow FROM d) IN (6, 7)      AS is_weekend
FROM generate_series(
       (SELECT date_trunc('year', min(order_ts))::date FROM staging.orders),
       (SELECT (date_trunc('year', max(order_ts)) + interval '1 year' - interval '1 day')::date FROM staging.orders),
       interval '1 day') AS d;


CREATE TABLE marts.dim_customer AS
SELECT row_number() OVER (ORDER BY customer_id)::int AS customer_key,
       customer_id, first_name, last_name,
       concat_ws(' ', first_name, last_name) AS full_name,
       email, email_is_valid, phone, city, state, country, signup_date, acquisition_channel
FROM staging.customers
UNION ALL
SELECT -1, 'UNKNOWN', 'Desconocido', NULL, 'Desconocido', NULL, FALSE, NULL, NULL, NULL, NULL, NULL, NULL;

CREATE TABLE marts.dim_product AS
SELECT row_number() OVER (ORDER BY product_id)::int AS product_key,
       product_id, product_name, category, subcategory, brand, unit_cost, list_price
FROM staging.products
UNION ALL
SELECT -1, 'UNKNOWN', 'Desconocido', 'Unknown', NULL, NULL, NULL, NULL;


-- CREATE TABLE marts.dim_products AS
-- SELECT product_id, product_name, category, subcategory, brand, unit_cost, list_price
-- FROM staging.products;


-- tablas de hechos
--un pedido
CREATE TABLE marts.fact_orders AS
WITH items AS (
    SELECT oi.order_id,
           count(*)                                                   AS items_count,
           sum(oi.quantity)                                           AS units,
           sum(oi.quantity * p.list_price)                            AS gross_amount,
           sum(oi.quantity * oi.unit_price)                           AS net_amount,
           sum(oi.quantity * (p.list_price - oi.unit_price))          AS discount_amount,
           sum(oi.quantity * (oi.unit_price - p.unit_cost))           AS margin_amount
    FROM staging.order_items oi
    LEFT JOIN staging.products p ON p.product_id = oi.product_id
    GROUP BY oi.order_id
),
pay AS (
    SELECT order_id, sum(amount) FILTER (WHERE status = 'paid') AS paid_amount
    FROM staging.payments GROUP BY order_id
)
SELECT row_number() OVER (ORDER BY o.order_id)::int AS order_key,
       o.order_id,
       COALESCE(dc.customer_key, -1)                AS customer_key,
       to_char(o.order_ts, 'YYYYMMDD')::int         AS order_date_key,
       o.order_ts,
       o.order_ts::date                             AS order_date,
       o.status, o.channel, o.promo_code,
       COALESCE(i.items_count, 0)::int              AS items_count,
       COALESCE(i.units, 0)::int                    AS units,
       COALESCE(i.gross_amount, 0)::numeric(14,2)     AS gross_amount,
       COALESCE(i.net_amount, 0)::numeric(14,2)       AS net_amount,
       COALESCE(i.discount_amount, 0)::numeric(14,2)  AS discount_amount,
       COALESCE(i.margin_amount, 0)::numeric(14,2)    AS margin_amount,
       COALESCE(pay.paid_amount, 0)::numeric(14,2)    AS paid_amount,
       CASE WHEN s.delivery_chronology_valid IS FALSE THEN NULL
            ELSE s.shipped_ts::date - o.order_ts::date END                              AS days_to_ship,
       CASE WHEN s.delivery_chronology_valid IS TRUE
            THEN round(EXTRACT(EPOCH FROM (s.delivered_ts - s.shipped_ts)) / 86400, 2) END AS days_to_deliver,
       CASE WHEN s.delivery_chronology_valid IS TRUE
            THEN s.delivered_ts::date <= s.promised_date END                            AS delivered_on_time
FROM staging.orders o
LEFT JOIN marts.dim_customer dc ON dc.customer_id = o.customer_id
LEFT JOIN items i               ON i.order_id = o.order_id
LEFT JOIN pay                   ON pay.order_id = o.order_id
LEFT JOIN staging.shipments s   ON s.order_id = o.order_id;

-- CREATE TABLE marts.fact_orders AS
-- SELECT order_id, customer_id, order_ts, order_ts::DATE AS order_date,
--        status, channel, promo_code, customer_exists
-- FROM staging.orders;

--un item por pedido
CREATE TABLE marts.fact_order_items AS
SELECT row_number() OVER (ORDER BY oi.order_item_id)::int AS order_item_key,
       oi.order_item_id,
       fo.order_key,
       oi.order_id,                       -- dimensión degenerada, para trazabilidad
       fo.customer_key,
       COALESCE(dp.product_key, -1)       AS product_key,
       fo.order_date_key,
       fo.order_date,
       oi.quantity, oi.unit_price, oi.discount_pct,
       (oi.quantity * dp.list_price)::numeric(14,2)                   AS gross_amount,
       (oi.quantity * oi.unit_price)::numeric(14,2)                   AS net_amount,
       (oi.quantity * (dp.list_price - oi.unit_price))::numeric(14,2) AS discount_amount,
       (oi.quantity * dp.unit_cost)::numeric(14,2)                    AS cost_amount,
       (oi.quantity * (oi.unit_price - dp.unit_cost))::numeric(14,2)  AS margin_amount
FROM staging.order_items oi
JOIN marts.fact_orders fo        ON fo.order_id = oi.order_id
LEFT JOIN marts.dim_product dp   ON dp.product_id = oi.product_id;

-- un pago

CREATE TABLE marts.fact_payments AS
SELECT row_number() OVER (ORDER BY p.payment_id)::int AS payment_key,
       p.payment_id, fo.order_key, p.order_id, p.method, p.amount,
       p.paid_ts, p.paid_ts::date AS payment_date, p.status
FROM staging.payments p
JOIN marts.fact_orders fo ON fo.order_id = p.order_id;


--un envio
CREATE TABLE marts.fact_shipments AS
SELECT row_number() OVER (ORDER BY s.shipment_id)::int AS shipment_key,
       s.shipment_id, fo.order_key, s.order_id, s.carrier,
       s.shipped_ts, s.delivered_ts, s.promised_date, s.delivery_chronology_valid,
       CASE WHEN s.delivered_ts IS NOT NULL AND s.promised_date IS NOT NULL
            THEN s.delivered_ts::date <= s.promised_date END AS delivered_on_time
FROM staging.shipments s
JOIN marts.fact_orders fo ON fo.order_id = s.order_id;

-- CREATE TABLE marts.sales_daily AS
-- SELECT order_date,
--        COUNT(DISTINCT order_id) AS total_orders,
--        SUM(net_amount)::NUMERIC(16,2) AS net_sales,
--        SUM(gross_amount)::NUMERIC(16,2) AS gross_sales,
--        SUM(discount_amount)::NUMERIC(16,2) AS discounts
-- FROM marts.fact_order_items
-- WHERE order_date IS NOT NULL
-- GROUP BY order_date;

-- Claves, relaciones e indices
ALTER TABLE marts.dim_date          ADD PRIMARY KEY (date_key);
ALTER TABLE marts.dim_customer      ADD PRIMARY KEY (customer_key);
ALTER TABLE marts.dim_product       ADD PRIMARY KEY (product_key);
ALTER TABLE marts.fact_orders       ADD PRIMARY KEY (order_key);
ALTER TABLE marts.fact_order_items  ADD PRIMARY KEY (order_item_key);
ALTER TABLE marts.fact_payments     ADD PRIMARY KEY (payment_key);
ALTER TABLE marts.fact_shipments    ADD PRIMARY KEY (shipment_key);

CREATE UNIQUE INDEX ON marts.dim_customer (customer_id);
CREATE UNIQUE INDEX ON marts.dim_product (product_id);
CREATE UNIQUE INDEX ON marts.fact_orders (order_id);

ALTER TABLE marts.fact_orders      ADD FOREIGN KEY (customer_key)    REFERENCES marts.dim_customer (customer_key);
ALTER TABLE marts.fact_orders      ADD FOREIGN KEY (order_date_key)  REFERENCES marts.dim_date (date_key);
ALTER TABLE marts.fact_order_items ADD FOREIGN KEY (order_key)       REFERENCES marts.fact_orders (order_key);
ALTER TABLE marts.fact_order_items ADD FOREIGN KEY (customer_key)    REFERENCES marts.dim_customer (customer_key);
ALTER TABLE marts.fact_order_items ADD FOREIGN KEY (product_key)     REFERENCES marts.dim_product (product_key);
ALTER TABLE marts.fact_order_items ADD FOREIGN KEY (order_date_key)  REFERENCES marts.dim_date (date_key);
ALTER TABLE marts.fact_payments    ADD FOREIGN KEY (order_key)       REFERENCES marts.fact_orders (order_key);
ALTER TABLE marts.fact_shipments   ADD FOREIGN KEY (order_key)       REFERENCES marts.fact_orders (order_key);

CREATE INDEX ON marts.fact_orders (customer_key);
CREATE INDEX ON marts.fact_orders (order_date_key);
CREATE INDEX ON marts.fact_order_items (order_key);
CREATE INDEX ON marts.fact_order_items (product_key);
CREATE INDEX ON marts.fact_order_items (customer_key);
CREATE INDEX ON marts.fact_order_items (order_date_key);
CREATE INDEX ON marts.fact_payments (order_key);
CREATE INDEX ON marts.fact_shipments (order_key);


-- ACTUALIZACIÓN DE ESTADÍSTICAS (ANALYZE)
-- Recalcula las estadisticas internas del optimizador de consultas de PostgreSQL.
-- Este es vital por: Despues de poblar las tablas con un proceso ETL o por medio de dbt, 
-- el motor necesita saber el volumen y la distribucion real de los datos  
-- para elegir los planes de ejecucion que pueden ser mas rapidos al hacer JOINS y reportes.

ANALYZE marts.dim_date; ANALYZE marts.dim_customer; ANALYZE marts.dim_product;
ANALYZE marts.fact_orders; ANALYZE marts.fact_order_items;
ANALYZE marts.fact_payments; ANALYZE marts.fact_shipments;
