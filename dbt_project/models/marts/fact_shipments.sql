{{ config(indexes=[{'columns': ['shipment_key'], 'unique': True}, {'columns': ['order_key']}]) }}

-- Grano: un envío
select
    row_number() over (order by s.shipment_id)::int as shipment_key,
    s.shipment_id, fo.order_key, s.order_id, s.carrier,
    s.shipped_ts, s.delivered_ts, s.promised_date, s.delivery_chronology_valid,
    case when s.delivered_ts is not null and s.promised_date is not null
         then s.delivered_ts::date <= s.promised_date end   as delivered_on_time
from {{ ref('stg_shipments') }} as s
join {{ ref('fact_orders') }} as fo on fo.order_id = s.order_id
