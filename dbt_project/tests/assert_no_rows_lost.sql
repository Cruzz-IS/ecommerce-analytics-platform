-- Falla si un hecho tiene menos filas que su origen en staging
select 'pedidos' as tabla, s.n as staging, m.n as marts
from (select count(*) n from {{ ref('stg_orders') }}) s, (select count(*) n from {{ ref('fact_orders') }}) m
where s.n <> m.n
union all
select 'items', s.n, m.n
from (select count(*) n from {{ ref('stg_order_items') }}) s, (select count(*) n from {{ ref('fact_order_items') }}) m
where s.n <> m.n
union all
select 'pagos', s.n, m.n
from (select count(*) n from {{ ref('stg_payments') }}) s, (select count(*) n from {{ ref('fact_payments') }}) m
where s.n <> m.n
union all
select 'envios', s.n, m.n
from (select count(*) n from {{ ref('stg_shipments') }}) s, (select count(*) n from {{ ref('fact_shipments') }}) m
where s.n <> m.n
