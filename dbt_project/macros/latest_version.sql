{# Devuelve la version mas reciente de cada registro: gana el lote mas nuevo es decir el (_batch_id) mas alto
   y, dentro del mismo lote, la carga mas reciente (_loaded_at). #}
{% macro latest_version(relation, key) %}
    select *
    from (
        select r.*,
               row_number() over (
                   partition by {{ key }}
                   order by _batch_id desc, _loaded_at desc
               ) as rn
        from {{ relation }} as r
    ) as ranked
    where rn = 1
{% endmacro %}
