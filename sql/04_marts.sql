-- Modelo analitico inicial mediante vistas.
DROP SCHEMA IF EXISTS marts CASCADE;     -- en 04
CREATE SCHEMA marts;


CREATE OR REPLACE VIEW marts.dim_customers AS
SELECT customer_id, first_name, last_name, email, email_is_valid,
       phone, city, state, country, signup_date, acquisition_channel
FROM staging.customers;

CREATE OR REPLACE VIEW marts.dim_products AS
SELECT product_id, product_name, category, subcategory, brand, unit_cost, list_price
FROM staging.products;

CREATE OR REPLACE VIEW marts.fact_orders AS
SELECT order_id, customer_id, order_ts, order_ts::DATE AS order_date,
       status, channel, promo_code, customer_exists
FROM staging.orders;

CREATE OR REPLACE VIEW marts.fact_order_items AS
SELECT
    oi.order_item_id, oi.order_id, o.customer_id, oi.product_id,
    o.order_ts::DATE AS order_date, oi.quantity, oi.unit_price,
    oi.discount_pct, p.list_price,
    (oi.quantity * p.list_price)::NUMERIC(14,2) AS gross_amount,
    (oi.quantity * oi.unit_price)::NUMERIC(14,2) AS net_amount,
    (oi.quantity * (p.list_price - oi.unit_price))::NUMERIC(14,2) AS discount_amount,
    oi.product_exists
FROM staging.order_items oi
LEFT JOIN staging.orders o ON o.order_id = oi.order_id
LEFT JOIN staging.products p ON p.product_id = oi.product_id;

CREATE OR REPLACE VIEW marts.fact_payments AS
SELECT payment_id, order_id, method, amount, paid_ts,
       paid_ts::DATE AS payment_date, status
FROM staging.payments;

CREATE OR REPLACE VIEW marts.fact_shipments AS
SELECT shipment_id, order_id, carrier, shipped_ts, delivered_ts,
       promised_date, delivery_chronology_valid,
       CASE
           WHEN delivered_ts IS NOT NULL AND promised_date IS NOT NULL
           THEN delivered_ts::DATE <= promised_date
           ELSE NULL
       END AS delivered_on_time
FROM staging.shipments;

CREATE OR REPLACE VIEW marts.sales_daily AS
SELECT order_date,
       COUNT(DISTINCT order_id) AS total_orders,
       SUM(net_amount)::NUMERIC(16,2) AS net_sales,
       SUM(gross_amount)::NUMERIC(16,2) AS gross_sales,
       SUM(discount_amount)::NUMERIC(16,2) AS discounts
FROM marts.fact_order_items
WHERE order_date IS NOT NULL
GROUP BY order_date;
