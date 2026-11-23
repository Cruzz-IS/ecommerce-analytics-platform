{{ config(indexes=[{'columns': ['product_key'], 'unique': True}, {'columns': ['product_id'], 'unique': True}]) }}

select
    row_number() over (order by product_id)::int as product_key,
    product_id, product_name, category, subcategory, brand, unit_cost, list_price
from {{ ref('stg_products') }}

union all

select -1, 'UNKNOWN', 'Desconocido', 'Unknown', null, null, null, null
