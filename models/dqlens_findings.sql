{{
    config(
        materialized='table',
        schema=var('dqlens', {}).get('dqlens_schema', 'dqlens'),
        tags=['dqlens']
    )
}}

{#
    This model materializes DQLens findings as a queryable table.
    It reads from the _dqlens_raw_findings seed/source populated by the profiler.

    If no findings exist yet, it creates an empty table with the correct schema.
#}

{% if execute %}
    {% set source_exists = adapter.get_relation(
        database=target.database,
        schema=target.schema ~ '_dqlens',
        identifier='raw_findings'
    ) %}
{% else %}
    {% set source_exists = none %}
{% endif %}

{% if source_exists %}

select
    finding_id,
    table_name,
    column_name,
    severity,
    category,
    message,
    detail,
    current_value,
    baseline_value,
    detected_at
from {{ source_exists }}
where severity >= '{{ var("dqlens", {}).get("min_severity", "LOW") }}'
order by
    case severity
        when 'HIGH' then 1
        when 'MEDIUM' then 2
        when 'LOW' then 3
    end,
    table_name,
    column_name

{% else %}

{# Empty scaffold when no findings exist yet #}
select
    cast(null as {{ dbt.type_string() }}) as finding_id,
    cast(null as {{ dbt.type_string() }}) as table_name,
    cast(null as {{ dbt.type_string() }}) as column_name,
    cast(null as {{ dbt.type_string() }}) as severity,
    cast(null as {{ dbt.type_string() }}) as category,
    cast(null as {{ dbt.type_string() }}) as message,
    cast(null as {{ dbt.type_string() }}) as detail,
    cast(null as {{ dbt.type_string() }}) as current_value,
    cast(null as {{ dbt.type_string() }}) as baseline_value,
    cast(null as {{ dbt.type_timestamp() }}) as detected_at
where 1 = 0

{% endif %}
