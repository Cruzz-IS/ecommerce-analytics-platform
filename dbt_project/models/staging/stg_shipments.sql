{{ config(alias='shipments', indexes=[{'columns': ['shipment_id'], 'unique': True}, {'columns': ['order_id']}]) }}

with latest as (
    {{ latest_version(source('raw', 'shipments'), 'shipment_id') }}
),

typed as (
    select
        nullif(btrim(shipment_id), '') as shipment_id,
        nullif(btrim(order_id), '') as order_id,
        nullif(btrim(carrier), '') as carrier,
        nullif(btrim(shipped_ts), '')::timestamp as shipped_ts,
        nullif(btrim(delivered_ts), '')::timestamp as delivered_ts,
        nullif(btrim(promised_date), '')::date as promised_date,
        _batch_id, _loaded_at, _source_file
    from latest
)

select
    *,
    case
        when delivered_ts is null or shipped_ts is null then null
        else delivered_ts >= shipped_ts
    end as delivery_chronology_valid
from typed
