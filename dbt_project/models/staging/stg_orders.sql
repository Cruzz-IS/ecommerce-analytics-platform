{{ config(alias='orders', indexes=[{'columns': ['order_id'], 'unique': True}, {'columns': ['customer_id']}]) }}

with latest as (
    {{ latest_version(source('raw', 'orders'), 'order_id') }}
)

select
    nullif(btrim(order_id), '') as order_id,
    nullif(btrim(customer_id), '') as customer_id,
    nullif(btrim(order_ts), '')::timestamp  as order_ts,
    lower(nullif(btrim(status), '')) as status,
    lower(nullif(btrim(channel), '')) as channel,
    nullif(btrim(promo_code), '') as promo_code,
    _batch_id, _loaded_at, _source_file
from latest
