{{ config(indexes=[
    {'columns': ['order_item_key'], 'unique': True},
    {'columns': ['order_key']},
    {'columns': ['product_key']},
    {'columns': ['customer_key']},
    {'columns': ['order_date_key']}
]) }}

-- Grano: un ítem dentro de un pedido
select
    row_number() over (order by oi.order_item_id)::int as order_item_key,
    oi.order_item_id,
    fo.order_key,
    oi.order_id,   
    fo.customer_key,
    coalesce(dp.product_key, -1) as product_key,
    fo.order_date_key,
    fo.order_date,
    oi.quantity, oi.unit_price, oi.discount_pct,
    (oi.quantity * dp.list_price)::numeric(14,2) as gross_amount,
    (oi.quantity * oi.unit_price)::numeric(14,2 as net_amount,
    (oi.quantity * (dp.list_price - oi.unit_price))::numeric(14,2) as discount_amount,
    (oi.quantity * dp.unit_cost)::numeric(14,2) as cost_amount,
    (oi.quantity * (oi.unit_price - dp.unit_cost))::numeric(14,2) as margin_amount
from {{ ref('stg_order_items') }} as oi
join {{ ref('fact_orders') }} as fo       on fo.order_id = oi.order_id
left join {{ ref('dim_product') }} as dp  on dp.product_id = oi.product_id
