{{ config(alias='order_items', indexes=[{'columns': ['order_item_id'], 'unique': True}, {'columns': ['order_id']}, {'columns': ['product_id']}]) }}

with latest as (
    {{ latest_version(source('raw', 'order_items'), 'order_item_id') }}
)

select
    nullif(btrim(order_item_id), '') as order_item_id,
    nullif(btrim(order_id), '') as order_id,
    nullif(btrim(product_id), '') as product_id,
    nullif(btrim(quantity), '')::integer as quantity,
    nullif(btrim(unit_price), '')::numeric(12,2) as unit_price,
    nullif(btrim(discount_pct), '')::numeric(5,2) as discount_pct,
    _batch_id, _loaded_at, _source_file
from latest
