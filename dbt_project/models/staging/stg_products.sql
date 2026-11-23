{{ config(alias='products', indexes=[{'columns': ['product_id'], 'unique': True}]) }}

with latest as (
    {{ latest_version(source('raw', 'products'), 'product_id') }}
)

select
    nullif(btrim(product_id), '') as product_id,
    nullif(btrim(product_name), '') as product_name,
    coalesce(initcap(nullif(btrim(category), '')), 'Unknown') as category,
    initcap(nullif(btrim(subcategory), '')) as subcategory,
    nullif(btrim(brand), '') as brand,
    nullif(btrim(unit_cost), '')::numeric(12,2) as unit_cost,
    nullif(btrim(list_price), '')::numeric(12,2) as list_price,
    _batch_id, _loaded_at, _source_file
from latest
