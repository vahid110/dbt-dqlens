{{
    config(
        materialized='incremental',
        unique_key=['table_name', 'column_name', 'profiled_at'],
        tags=['dqlens', 'dqlens_profile']
    )
}}

{{ dqlens_get_profile_query() }}
