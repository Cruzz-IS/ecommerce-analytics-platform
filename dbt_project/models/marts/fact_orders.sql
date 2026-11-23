{{ config(indexes=[
    {'columns': ['order_key'], 'unique': True},
    {'columns': ['order_id'], 'unique': True},
    {'columns': ['customer_key']},
    {'columns': ['order_date_key']}
]) }}

--un pedido
with items as (
    select oi.order_id,
           count(*) as items_count,
           sum(oi.quantity) as units,
           sum(oi.quantity * p.list_price) as gross_amount,
           sum(oi.quantity * oi.unit_price) as net_amount,
           sum(oi.quantity * (p.list_price - oi.unit_price)) as discount_amount,
           sum(oi.quantity * (oi.unit_price - p.unit_cost)) as margin_amount
    from {{ ref('stg_order_items') }} as oi
    left join {{ ref('stg_products') }} as p on p.product_id = oi.product_id
    group by oi.order_id
),

pay as (
    select order_id, sum(amount) filter (where status = 'paid') as paid_amount
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    row_number() over (order by o.order_id)::int        as order_key,
    o.order_id,
    coalesce(dc.customer_key, -1)                       as customer_key,
    to_char(o.order_ts, 'YYYYMMDD')::int                as order_date_key,
    o.order_ts,
    o.order_ts::date                                    as order_date,
    o.status, o.channel, o.promo_code,
    coalesce(i.items_count, 0)::int                     as items_count,
    coalesce(i.units, 0)::int                           as units,
    coalesce(i.gross_amount, 0)::numeric(14,2)          as gross_amount,
    coalesce(i.net_amount, 0)::numeric(14,2)            as net_amount,
    coalesce(i.discount_amount, 0)::numeric(14,2)       as discount_amount,
    coalesce(i.margin_amount, 0)::numeric(14,2)         as margin_amount,
    coalesce(pay.paid_amount, 0)::numeric(14,2)         as paid_amount,
    case when s.delivery_chronology_valid is false then null
         else s.shipped_ts::date - o.order_ts::date end                              as days_to_ship,
    case when s.delivery_chronology_valid is true
         then round(extract(epoch from (s.delivered_ts - s.shipped_ts)) / 86400, 2) end as days_to_deliver,
    case when s.delivery_chronology_valid is true
         then s.delivered_ts::date <= s.promised_date end                            as delivered_on_time
from {{ ref('stg_orders') }} as o
left join {{ ref('dim_customer') }} as dc on dc.customer_id = o.customer_id
left join items i                         on i.order_id = o.order_id
left join pay                             on pay.order_id = o.order_id
left join {{ ref('stg_shipments') }} as s on s.order_id = o.order_id
