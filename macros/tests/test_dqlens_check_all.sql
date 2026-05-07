{% test dqlens_check_all(model, null_drift_multiplier=3, row_count_threshold=30, empty_string_max=30) %}
    {#
        THE CATCH-ALL TEST.
        One test that checks ALL columns across ALL tables for ALL anomalies.
        No per-model configuration needed. Add this once to your project and you're done.

        Usage in dbt_project.yml:
            tests:
              dqlens:
                dqlens_profile_results:
                  - dqlens_check_all

        Or in schema.yml:
            models:
              - name: dqlens_profile_results
                tests:
                  - dqlens_check_all
    #}

    WITH current_profile AS (
        SELECT *
        FROM {{ ref('dqlens_profile_results') }}
        WHERE profiled_at = (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
    ),

    baseline AS (
        SELECT * FROM {{ ref('dqlens_baseline') }}
    ),

    -- Check 1: Null drift
    null_drift AS (
        SELECT
            c.table_name,
            c.column_name,
            'null_drift' as check_type,
            'Null rate increased ' || CAST(ROUND(c.null_pct / NULLIF(b.null_pct, 0), 1) AS {{ dbt.type_string() }}) || 'x ('
                || CAST(b.null_pct AS {{ dbt.type_string() }}) || '% -> '
                || CAST(c.null_pct AS {{ dbt.type_string() }}) || '%)' as message
        FROM current_profile c
        JOIN baseline b ON c.table_name = b.table_name AND c.column_name = b.column_name
        WHERE c.null_pct > b.null_pct * {{ null_drift_multiplier }}
            AND c.null_pct > 1
            AND b.null_pct > 0
    ),

    -- Check 2: Row count anomaly
    row_anomaly AS (
        SELECT DISTINCT
            c.table_name,
            CAST(NULL AS {{ dbt.type_string() }}) as column_name,
            'row_count_anomaly' as check_type,
            'Row count changed ' || CAST(
                ROUND(CAST((CAST(c.row_count AS NUMERIC) - b.row_count) / NULLIF(CAST(b.row_count AS NUMERIC), 0) * 100 AS NUMERIC), 1)
            AS {{ dbt.type_string() }}) || '%' as message
        FROM current_profile c
        JOIN baseline b ON c.table_name = b.table_name AND c.column_name = b.column_name
        WHERE b.row_count > 0
            AND ABS(
                (CAST(c.row_count AS NUMERIC) - b.row_count)
                / NULLIF(CAST(b.row_count AS NUMERIC), 0) * 100
            ) > {{ row_count_threshold }}
    ),

    -- Check 3: Empty strings
    empty_strings AS (
        SELECT
            c.table_name,
            c.column_name,
            'empty_strings' as check_type,
            'Empty string rate: ' || CAST(
                ROUND(CAST(c.empty_string_count AS NUMERIC) / NULLIF(CAST(c.row_count - c.null_count AS NUMERIC), 0) * 100, 1)
            AS {{ dbt.type_string() }}) || '%' as message
        FROM current_profile c
        WHERE c.empty_string_count > 0
            AND CAST(c.empty_string_count AS NUMERIC) / NULLIF(CAST(c.row_count - c.null_count AS NUMERIC), 0) * 100 > {{ empty_string_max }}
    ),

    -- Check 4: Schema drift (columns removed)
    schema_removed AS (
        SELECT
            b.table_name,
            b.column_name,
            'schema_drift' as check_type,
            'Column removed (was type: ' || b.data_type || ')' as message
        FROM baseline b
        LEFT JOIN current_profile c ON b.table_name = c.table_name AND b.column_name = c.column_name
        WHERE c.column_name IS NULL
    ),

    -- Check 5: Schema drift (type changed)
    schema_type_change AS (
        SELECT
            c.table_name,
            c.column_name,
            'schema_drift' as check_type,
            'Type changed: ' || b.data_type || ' -> ' || c.data_type as message
        FROM current_profile c
        JOIN baseline b ON c.table_name = b.table_name AND c.column_name = b.column_name
        WHERE c.data_type != b.data_type
    )

    SELECT * FROM null_drift
    UNION ALL
    SELECT * FROM row_anomaly
    UNION ALL
    SELECT * FROM empty_strings
    UNION ALL
    SELECT * FROM schema_removed
    UNION ALL
    SELECT * FROM schema_type_change

{% endtest %}
