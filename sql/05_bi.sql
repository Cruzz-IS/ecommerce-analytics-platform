DROP VIEW IF EXISTS bi.sales_detail CASCADE;
CREATE VIEW bi.sales_detail AS
SELECT
    i.order_item_id,
    i.order_id,
    o.order_date,
    date_trunc('month', o.order_date)::date AS order_month,
    o.status,
    (o.status <> 'cancelled') AS is_valid_sale,
    o.channel,
    c.customer_key
   (c.customer_key <> -1) AS customer_exists,
    c.customer_id, c.city, c.country, c.acquisition_channel,
    p.product_id, p.product_name, p.category, p.subcategory, p.brand,
    i.quantity,
    i.gross_amount,
    i.discount_amount,
    i.net_amount,
    (i.quantity * p.unit_cost)::numeric(14,2) AS cost_amount,
    (i.net_amount - i.quantity * p.unit_cost)::numeric(14,2)  AS margin_amount
FROM marts.fact_order_items i
JOIN marts.fact_orders o   ON (o.order_key = i.order_key)
JOIN marts.dim_customer c  ON (c.customer_key = i.customer_key)
JOIN marts.dim_product p   ON (p.product_key  = i.product_key);

DROP VIEW IF EXISTS bi.kpi_summary CASCADE;
CREATE VIEW bi.kpi_summary AS
WITH sales AS (
    SELECT count(DISTINCT order_id) AS orders,
           count(DISTINCT customer_id) FILTER (WHERE customer_exists)  AS customers,
           coalesce(sum(net_amount), 0)::numeric(18,2) AS net_sales,
           coalesce(sum(margin_amount), 0)::numeric(18,2) AS margin
    FROM bi.sales_detail WHERE is_valid_sale
),
cancel AS (
    SELECT round(
        100.0 * count(*) FILTER (WHERE status = 'cancelled') 
    / nullif(count(*), 0),
            2
        ) AS cancellation_rate_pct
    FROM marts.fact_orders
),
delivery AS (
    SELECT 
    round(
        100.0 * count(*) FILTER (WHERE delivered_on_time)
                 / nullif(count(*) FILTER (WHERE delivered_on_time IS NOT NULL), 0), 2) 
                 AS on_time_pct
    FROM marts.fact_shipments
    WHERE delivery_chronology_valid IS NOT FALSE
)
SELECT s.net_sales, s.orders, s.customers,
       round(s.net_sales / s.orders, 2) AS avg_order_value,
       round(100.0 * s.margin / s.net_sales, 2) AS margin_pct,
       d.on_time_pct, c.cancellation_rate_pct
FROM sales s, cancel c, delivery d;


---NUEVAS METRICAS PARA EL DASHBOARD DE BI

--ventas por mes
DROP VIEW IF EXISTS bi.sales_monthly CASCADE;
CREATE VIEW bi.sales_monthly AS
WITH calendar_months AS (
    SELECT
        date_trunc('month', min(date))::date AS first_month,
        date_trunc('month', max(date))::date AS last_month
    FROM marts.dim_date
),
month_spine AS (
    SELECT generate_series(
        first_month,
        last_month,
        interval '1 month'
    )::date AS order_month
    FROM calendar_months
    WHERE first_month IS NOT NULL
),
monthly_sales AS (
    SELECT
        date_trunc('month', order_date)::date AS order_month,
        coalesce(sum(net_amount), 0)::numeric(18,2) AS net_sales,
        count(DISTINCT order_id) AS orders,
        count(DISTINCT customer_id)
            FILTER (WHERE customer_exists) AS customers,
        coalesce(sum(quantity), 0)::bigint AS units_sold,
        coalesce(sum(margin_amount), 0)::numeric(18,2) AS margin_amount
    FROM bi.sales_detail
    WHERE is_valid_sale
    GROUP BY 1
),
monthly AS (
    SELECT
        m.order_month,
        coalesce(s.net_sales, 0)::numeric(18,2) AS net_sales,
        coalesce(s.orders, 0)::bigint AS orders,
        coalesce(s.customers, 0)::bigint AS customers,
        coalesce(s.units_sold, 0)::bigint AS units_sold,
        coalesce(s.margin_amount, 0)::numeric(18,2) AS margin_amount
    FROM month_spine AS m
    LEFT JOIN monthly_sales AS s USING (order_month)
),
with_lags AS (
    SELECT
        *,
        LAG(net_sales, 1) OVER (ORDER BY order_month) AS previous_month_sales,
        LAG(net_sales, 12) OVER (ORDER BY order_month) AS previous_year_sales
    FROM monthly
)
SELECT
    order_month,
    EXTRACT(year FROM order_month)::int AS sales_year,
    EXTRACT(month FROM order_month)::int AS sales_month,
    net_sales,
    orders,
    customers,
    units_sold,
    margin_amount,
    round(net_sales / nullif(orders, 0), 2) AS avg_order_value,
    previous_month_sales,
    round(
        100.0 * (net_sales - previous_month_sales)
        / nullif(previous_month_sales, 0),
        2
    ) AS mom_growth_pct,
    previous_year_sales,
    round(
        100.0 * (net_sales - previous_year_sales)
        / nullif(previous_year_sales, 0),
        2
    ) AS yoy_growth_pct
FROM with_lags;


---ventas por categoria

DROP VIEW IF EXISTS bi.sales_by_category CASCADE;
CREATE VIEW bi.sales_by_category AS
WITH category_totals AS (
    SELECT
        category,
        coalesce(sum(quantity), 0)::bigint AS units_sold,
        coalesce(sum(net_amount), 0)::numeric(18,2) AS net_sales,
        coalesce(sum(cost_amount), 0)::numeric(18,2) AS cost_amount,
        coalesce(sum(margin_amount), 0)::numeric(18,2) AS margin_amount,
        count(DISTINCT order_id) AS orders
    FROM bi.sales_detail
    WHERE is_valid_sale
    GROUP BY category
)
SELECT
    category,
    units_sold,
    net_sales,
    cost_amount,
    margin_amount,
    round(100.0 * margin_amount / nullif(net_sales, 0), 2) AS margin_pct,
    round(
        100.0 * net_sales / nullif(sum(net_sales) OVER (), 0),
        2
    ) AS sales_share_pct,
    orders
FROM category_totals;



--CUSTOMER RFM
DROP VIEW IF EXISTS bi.customer_rfm CASCADE;
CREATE VIEW bi.customer_rfm AS
WITH base AS (
    SELECT
        f.customer_key,
        c.customer_id,
        c.full_name AS customer_name,
        max(f.order_date)::date AS last_order_date,
        count(*)::bigint AS frequency,
        coalesce(sum(f.net_amount), 0)::numeric(18,2) AS monetary
    FROM marts.fact_orders AS f
    JOIN marts.dim_customer AS c
      ON c.customer_key = f.customer_key
    WHERE f.status <> 'cancelled'
      AND f.customer_key <> -1
    GROUP BY f.customer_key, c.customer_id, c.full_name
),
recency AS (
    SELECT
        *,
        (max(last_order_date) OVER () - last_order_date)::int AS recency_days
    FROM base
),
scores AS (
    SELECT
        *,
        ntile(5) OVER (ORDER BY last_order_date ASC) AS r_score,
        ntile(5) OVER (ORDER BY frequency ASC) AS f_score,
        ntile(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM recency
)
SELECT
    *,
    (r_score + f_score + m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
            THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 4
            THEN 'Loyal customers'
        WHEN r_score >= 4 AND f_score <= 2
            THEN 'New customers'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
            THEN 'At risk'
        WHEN r_score <= 2 AND f_score <= 2
            THEN 'Hibernating'
        ELSE 'Potential loyalists'
    END AS customer_segment
FROM scores;


--cohort retention
DROP VIEW IF EXISTS bi.cohort_retention CASCADE;
CREATE VIEW bi.cohort_retention AS
WITH valid_orders AS (
    SELECT customer_key, order_date
    FROM marts.fact_orders
    WHERE status <> 'cancelled'
      AND customer_key <> -1
),
first_order AS (
    SELECT
        customer_key,
        date_trunc('month', min(order_date))::date AS cohort_month
    FROM valid_orders
    GROUP BY customer_key
),
cohort_sizes AS (
    SELECT
        cohort_month,
        count(*)::bigint AS cohort_size
    FROM first_order
    GROUP BY cohort_month
),
activity AS (
    SELECT DISTINCT
        f.customer_key,
        fo.cohort_month,
        (
            (EXTRACT(year FROM date_trunc('month', f.order_date))
             - EXTRACT(year FROM fo.cohort_month)) * 12
            + EXTRACT(month FROM date_trunc('month', f.order_date))
            - EXTRACT(month FROM fo.cohort_month)
        )::int AS month_n
    FROM valid_orders AS f
    JOIN first_order AS fo USING (customer_key)
),
retention AS (
    SELECT
        cohort_month,
        month_n,
        count(DISTINCT customer_key)::bigint AS active_customers
    FROM activity
    GROUP BY cohort_month, month_n
)
SELECT
    r.cohort_month,
    r.month_n,
    cs.cohort_size,
    r.active_customers,
    round(
        100.0 * r.active_customers / nullif(cs.cohort_size, 0),
        2
    ) AS retention_pct
FROM retention AS r
JOIN cohort_sizes AS cs USING (cohort_month);


--delivery sla 
DROP VIEW IF EXISTS bi.delivery_sla CASCADE;
CREATE VIEW bi.delivery_sla AS
SELECT
    carrier,
    date_trunc('month', shipped_ts)::date AS shipment_month,
    count(*)::bigint AS delivered_shipments,
    count(*) FILTER (WHERE delivered_on_time IS TRUE)::bigint
        AS on_time_shipments,
    round(
        100.0 * count(*) FILTER (WHERE delivered_on_time IS TRUE)
        / nullif(count(*) FILTER (WHERE delivered_on_time IS NOT NULL), 0),
        2
    ) AS on_time_percentage,
    round(
        AVG(EXTRACT(EPOCH FROM (delivered_ts - shipped_ts)) / 86400.0)::numeric,
        2
    ) AS avg_delivery_days
FROM marts.fact_shipments
WHERE delivery_chronology_valid IS TRUE
  AND delivered_ts IS NOT NULL
  AND shipped_ts IS NOT NULL
GROUP BY carrier, date_trunc('month', shipped_ts)::date;


---calidad de los datos 

DROP VIEW IF EXISTS bi.data_quality CASCADE;

CREATE VIEW bi.data_quality AS
SELECT
    'orders_without_matching_customer'::text AS issue_name,
    count(*)::bigint AS affected_rows
FROM marts.fact_orders
WHERE customer_key = -1

UNION ALL

SELECT
    'customers_with_invalid_email'::text AS issue_name,
    count(*)::bigint AS affected_rows
FROM marts.dim_customer
WHERE customer_key <> -1
  AND (
      email IS NULL
      OR BTRIM(email) = ''
      OR email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  )

UNION ALL

SELECT
    'shipments_with_invalid_chronology'::text AS issue_name,
    count(*)::bigint AS affected_rows
FROM marts.fact_shipments
WHERE delivery_chronology_valid IS FALSE

UNION ALL

SELECT
    'order_items_without_matching_product'::text AS issue_name,
    count(*)::bigint AS affected_rows
FROM marts.fact_order_items
WHERE product_key = -1;



 --SELECT * FROM bi.sales_detail;
 --SELECT * FROM bi.kpi_summary;
 --SELECT * FROM bi.sales_monthly ORDER BY order_month;
 --SELECT * FROM bi.sales_by_category ORDER BY net_sales DESC;
 --SELECT * FROM bi.customer_rfm LIMIT 20;
 --SELECT * FROM bi.cohort_retention ORDER BY cohort_month, month_n;
 --SELECT * FROM bi.delivery_sla ORDER BY shipment_month, carrier;
 --SELECT * FROM bi.data_quality ORDER BY issue_name;


 --comprobar las vistas existentes

-- SELECT table_name
-- FROM information_schema.views
-- WHERE table_schema = 'bi'
-- ORDER BY table_name;

