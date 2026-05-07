{% test dqlens_empty_strings_native(model, max_pct=30) %}
    {#
        Native empty string detection.
        Fails if any text column has more than max_pct empty strings.
    #}

    WITH current_profile AS (
        SELECT *
        FROM {{ ref('dqlens_profile_results') }}
        WHERE profiled_at = (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
    )

    SELECT
        table_name,
        column_name,
        empty_string_count,
        row_count - null_count as non_null_count,
        ROUND(
            CAST(empty_string_count AS {{ dbt.type_float() }})
            / NULLIF(CAST(row_count - null_count AS {{ dbt.type_float() }}), 0) * 100, 2
        ) as empty_string_pct
    FROM current_profile
    WHERE empty_string_count > 0
        AND ROUND(
            CAST(empty_string_count AS {{ dbt.type_float() }})
            / NULLIF(CAST(row_count - null_count AS {{ dbt.type_float() }}), 0) * 100, 2
        ) > {{ max_pct }}

{% endtest %}
