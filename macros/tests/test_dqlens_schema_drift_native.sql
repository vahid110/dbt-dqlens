{% test dqlens_schema_drift_native(model) %}
    {#
        Native schema drift detection.
        Compares current column set against baseline.
        Fails if columns were added, removed, or changed type.
    #}

    WITH current_profile AS (
        SELECT DISTINCT table_name, column_name, data_type
        FROM {{ ref('dqlens_profile_results') }}
        WHERE profiled_at = (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
    ),

    baseline AS (
        SELECT DISTINCT table_name, column_name, data_type
        FROM {{ ref('dqlens_baseline') }}
    ),

    -- Columns removed (in baseline but not in current)
    removed AS (
        SELECT
            b.table_name,
            b.column_name,
            'column_removed' as drift_type,
            b.data_type as baseline_type,
            CAST(NULL AS {{ dbt.type_string() }}) as current_type
        FROM baseline b
        LEFT JOIN current_profile c
            ON b.table_name = c.table_name AND b.column_name = c.column_name
        WHERE c.column_name IS NULL
    ),

    -- Columns added (in current but not in baseline)
    added AS (
        SELECT
            c.table_name,
            c.column_name,
            'column_added' as drift_type,
            CAST(NULL AS {{ dbt.type_string() }}) as baseline_type,
            c.data_type as current_type
        FROM current_profile c
        LEFT JOIN baseline b
            ON c.table_name = b.table_name AND c.column_name = b.column_name
        WHERE b.column_name IS NULL
    ),

    -- Type changes
    type_changed AS (
        SELECT
            c.table_name,
            c.column_name,
            'type_changed' as drift_type,
            b.data_type as baseline_type,
            c.data_type as current_type
        FROM current_profile c
        JOIN baseline b
            ON c.table_name = b.table_name AND c.column_name = b.column_name
        WHERE c.data_type != b.data_type
    )

    SELECT * FROM removed
    UNION ALL
    SELECT * FROM added
    UNION ALL
    SELECT * FROM type_changed

{% endtest %}
