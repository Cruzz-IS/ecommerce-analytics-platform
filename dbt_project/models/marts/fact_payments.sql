{{ config(indexes=[{'columns': ['payment_key'], 'unique': True}, {'columns': ['order_key']}]) }}

-- Grano: un pago
select
    row_number() over (order by p.payment_id)::int  as payment_key,
    p.payment_id, fo.order_key, p.order_id, p.method, p.amount,
    p.paid_ts, p.paid_ts::date                      as payment_date, p.status
from {{ ref('stg_payments') }} as p
join {{ ref('fact_orders') }} as fo on fo.order_id = p.order_id
