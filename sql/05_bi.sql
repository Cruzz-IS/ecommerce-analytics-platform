DROP VIEW IF EXISTS bi.sales_detail CASCADE;
CREATE VIEW bi.sales_detail AS
SELECT
    i.order_item_id,
    i.order_id,
    o.order_date,
    date_trunc('month', o.order_date)::date AS order_month,
    o.status,
    (o.status <> 'cancelled')               AS is_valid_sale,
    o.channel,
   (c.customer_key <> -1) AS customer_exists,
    c.customer_id, c.city, c.country, c.acquisition_channel,
    p.product_id, p.product_name, p.category, p.subcategory, p.brand,
    i.quantity,
    i.gross_amount,
    i.discount_amount,
    i.net_amount,
    (i.quantity * p.unit_cost)::numeric(14,2)                 AS cost_amount,
    (i.net_amount - i.quantity * p.unit_cost)::numeric(14,2)  AS margin_amount
FROM marts.fact_order_items i
JOIN marts.fact_orders o   ON o.order_key    = i.order_key
JOIN marts.dim_customer c  ON c.customer_key = i.customer_key
JOIN marts.dim_product p   ON p.product_key  = i.product_key;

DROP VIEW IF EXISTS bi.kpi_summary CASCADE;
CREATE VIEW bi.kpi_summary AS
WITH sales AS (
    SELECT count(DISTINCT order_id)                                    AS orders,
           count(DISTINCT customer_id) FILTER (WHERE customer_exists)  AS customers,
           sum(net_amount)                                             AS net_sales,
           sum(margin_amount)                                          AS margin
    FROM bi.sales_detail WHERE is_valid_sale
),
cancel AS (
    SELECT round(100.0 * count(*) FILTER (WHERE status = 'cancelled') / count(*), 2) AS cancellation_rate_pct
    FROM marts.fact_orders
),
delivery AS (
    SELECT round(100.0 * count(*) FILTER (WHERE delivered_on_time)
                 / NULLIF(count(*) FILTER (WHERE delivered_on_time IS NOT NULL), 0), 2) AS on_time_pct
    FROM marts.fact_shipments
    WHERE delivery_chronology_valid IS NOT FALSE
)
SELECT s.net_sales, s.orders, s.customers,
       round(s.net_sales / s.orders, 2)          AS avg_order_value,
       round(100.0 * s.margin / s.net_sales, 2)  AS margin_pct,
       d.on_time_pct, c.cancellation_rate_pct
FROM sales s, cancel c, delivery d;