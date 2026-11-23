{{ config(indexes=[{'columns': ['date_key'], 'unique': True}]) }}

select
    to_char(d, 'YYYYMMDD')::int as date_key,
    d::date as date,
    extract(year from d)::int as year,
    extract(quarter from d)::int as quarter,
    extract(month from d)::int as month,
    trim(to_char(d, 'Month')) as month_name,
    extract(isodow from d)::int as day_of_week,
    extract(isodow from d) in (6, 7) as is_weekend
from generate_series(
    (select date_trunc('year', min(order_ts))::date from {{ ref('stg_orders') }}),
    (select (date_trunc('year', max(order_ts)) + interval '1 year' - interval '1 day')::date from {{ ref('stg_orders') }}),
    interval '1 day'
) as d
