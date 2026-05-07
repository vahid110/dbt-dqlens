{{
    config(
        materialized='incremental',
        unique_key=['table_name', 'column_name', 'profiled_at'],
        schema=var('dqlens', {}).get('dqlens_schema', 'dqlens'),
        tags=['dqlens', 'dqlens_profile']
    )
}}

{#
    DQLens Profile Results
    Stores column-level statistics for every table in the target schema.
    Incremental: appends a new profile snapshot on each run.

    Usage:
        dbt run --select dqlens_profile_results
#}

{{ dqlens_get_profile_query() }}
