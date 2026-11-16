CREATE OR REPLACE VIEW staging.orders AS
SELECT DISTINCT ON (r.order_id)
       NULLIF(trim(r.order_id), '')::int        AS order_id,
       NULLIF(trim(r.customer_id), '')::int     AS customer_id,
       NULLIF(trim(r.order_ts), '')::timestamp  AS order_ts,
       lower(trim(r.status))                    AS status,
       lower(trim(r.channel))                   AS channel,
       NULLIF(upper(trim(r.promo_code)), '')    AS promo_code,
       r._batch_id,
       r._loaded_at
FROM raw.orders AS r
WHERE NULLIF(trim(r.order_id), '') IS NOT NULL
ORDER BY r.order_id, r._loaded_at DESC;