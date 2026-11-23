-- Falla si las ventas realizadas no coinciden entre pedidos, items y pagos
with from_orders as (
    select sum(net_amount) as v
    from {{ ref('fact_orders') }}
    where status <> 'cancelled'
),
from_items as (
    select sum(i.net_amount) as v
    from {{ ref('fact_order_items') }} as i
    join {{ ref('fact_orders') }} as o using (order_key)
    where o.status <> 'cancelled'
),
from_payments as (
    select sum(p.amount) as v
    from {{ ref('fact_payments') }} as p
    join {{ ref('fact_orders') }} as o using (order_key)
    where o.status <> 'cancelled'
)
select fo.v as desde_pedidos, fi.v as desde_items, fp.v as desde_pagos
from from_orders fo, from_items fi, from_payments fp
where abs(fo.v - fi.v) > 0.01 or abs(fo.v - fp.v) > 0.01
