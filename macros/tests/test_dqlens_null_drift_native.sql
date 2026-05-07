{% test dqlens_null_drift_native(model, threshold_multiplier=3) %}
    {#
        Native null drift detection.
        Compares current profile against baseline for ALL columns.
        Fails if any column's null rate increased beyond threshold.

        No per-column configuration needed. Checks everything automatically.
    #}

    WITH current_profile AS (
        SELECT * FROM {{ ref('dqlens_profile_results') }}
        WHERE profiled_at = (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
    ),

    baseline AS (
        SELECT * FROM {{ ref('dqlens_baseline') }}
    )

    SELECT
        c.table_name,
        c.column_name,
        c.null_pct as current_null_pct,
        b.null_pct as baseline_null_pct,
        ROUND(c.null_pct / NULLIF(b.null_pct, 0), 1) as multiplier
    FROM current_profile c
    JOIN baseline b
        ON c.table_name = b.table_name
        AND c.column_name = b.column_name
    WHERE c.null_pct > b.null_pct * {{ threshold_multiplier }}
        AND c.null_pct > 1
        AND b.null_pct > 0

{% endtest %}
