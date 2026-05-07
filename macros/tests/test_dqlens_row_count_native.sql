{% test dqlens_row_count_native(model, threshold_pct=30) %}
    {#
        Native row count anomaly detection.
        Fails if any table's row count changed more than threshold_pct from baseline.
    #}

    WITH current_counts AS (
        SELECT DISTINCT
            table_name,
            FIRST_VALUE(row_count) OVER (PARTITION BY table_name ORDER BY column_name) as row_count
        FROM {{ ref('dqlens_profile_results') }}
        WHERE profiled_at = (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
    ),

    baseline_counts AS (
        SELECT DISTINCT
            table_name,
            FIRST_VALUE(row_count) OVER (PARTITION BY table_name ORDER BY column_name) as row_count
        FROM {{ ref('dqlens_baseline') }}
    )

    SELECT
        c.table_name,
        c.row_count as current_count,
        b.row_count as baseline_count,
        ROUND(
            (CAST(c.row_count AS {{ dbt.type_float() }}) - b.row_count)
            / NULLIF(CAST(b.row_count AS {{ dbt.type_float() }}), 0) * 100, 1
        ) as change_pct
    FROM current_counts c
    JOIN baseline_counts b ON c.table_name = b.table_name
    WHERE b.row_count > 0
        AND ABS(
            (CAST(c.row_count AS {{ dbt.type_float() }}) - b.row_count)
            / NULLIF(CAST(b.row_count AS {{ dbt.type_float() }}), 0) * 100
        ) > {{ threshold_pct }}

{% endtest %}
