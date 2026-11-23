-- Falla si el total de un pedido no coincide con la suma de sus items
select o.order_id, o.net_amount, i.items_total
from {{ ref('fact_orders') }} as o
join (
    select order_key, sum(net_amount) as items_total
    from {{ ref('fact_order_items') }}
    group by order_key
) as i using (order_key)
where abs(o.net_amount - i.items_total) > 0.01
