{{ config(indexes=[{'columns': ['customer_key'], 'unique': True}, {'columns': ['customer_id'], 'unique': True}]) }}

select
    row_number() over (order by customer_id)::int   as customer_key,
    customer_id, first_name, last_name,
    concat_ws(' ', first_name, last_name)           as full_name,
    email, email_is_valid, phone, city, state, country, signup_date, acquisition_channel
from {{ ref('stg_customers') }}

union all

-- Miembro "Desconocido": los pedidos con cliente inexistente apuntan aquí
select -1, 'UNKNOWN', 'Desconocido', null, 'Desconocido', null, false, null, null, null, null, null, null
