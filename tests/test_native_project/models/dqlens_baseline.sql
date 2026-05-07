{{
    config(
        materialized='view',
        tags=['dqlens']
    )
}}

WITH ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY profiled_at DESC) as run_rank
    FROM {{ ref('dqlens_profile_results') }}
)

SELECT
    table_name,
    column_name,
    data_type,
    row_count,
    null_count,
    null_pct,
    distinct_count,
    min_value,
    max_value,
    empty_string_count,
    profiled_at
FROM ranked
WHERE run_rank = 2
