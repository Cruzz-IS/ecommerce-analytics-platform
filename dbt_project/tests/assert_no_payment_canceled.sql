-- Falla si existe un pago en un pedido cancelado.
select p.payment_id, o.order_id, o.status, p.status as payment_status
from {{ ref('fact_payments') }} as p
join {{ ref('fact_orders') }} as o using (order_key)
where o.status = 'cancelled' and p.status = 'paid'
