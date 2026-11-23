{{ config(alias='customers', indexes=[{'columns': ['customer_id'], 'unique': True}]) }}

with latest as (
    {{ latest_version(source('raw', 'customers'), 'customer_id') }}
)

select
    nullif(btrim(customer_id), '') as customer_id,
    nullif(btrim(first_name), '') as first_name,
    nullif(btrim(last_name), '') as last_name,
    lower(nullif(btrim(email), '')) as email,
    nullif(btrim(phone), '') as phone,
    nullif(btrim(city), '') as city,
    nullif(btrim(state), '') as state,
    nullif(btrim(country), '') as country,
    nullif(btrim(signup_date), '')::date as signup_date,
    lower(nullif(btrim(acquisition_channel), ''))   as acquisition_channel,
    (lower(btrim(coalesce(email, ''))) ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$') as email_is_valid,
    _batch_id, _loaded_at, _source_file
from latest
