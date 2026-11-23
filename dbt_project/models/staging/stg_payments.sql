{{ config(alias='payments', indexes=[{'columns': ['payment_id'], 'unique': True}, {'columns': ['order_id']}]) }}

with latest as (
    {{ latest_version(source('raw', 'payments'), 'payment_id') }}
)

select
    nullif(btrim(payment_id), '') as payment_id,
    nullif(btrim(order_id), '') as order_id,
    lower(nullif(btrim(method), '')) as method,
    nullif(btrim(amount), '')::numeric(12,2) as amount,
    nullif(btrim(paid_ts), '')::timestamp as paid_ts,
    lower(nullif(btrim(status), '')) as status,
    _batch_id, _loaded_at, _source_file
from latest
