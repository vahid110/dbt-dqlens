{% test dqlens_freshness_native(model, max_hours=48) %}
    {#
        Native freshness detection.
        Fails if the most recent profile is older than max_hours.
        This checks when the PROFILE was last run, not the data itself.
        (Data freshness requires timestamp column detection, which is in the full profiler.)
    #}

    WITH latest_profile AS (
        SELECT MAX(profiled_at) as last_profiled
        FROM {{ ref('dqlens_profile_results') }}
    )

    SELECT
        last_profiled,
        {{ dbt.current_timestamp() }} as current_time,
        {{ dbt.datediff("last_profiled", dbt.current_timestamp(), "hour") }} as hours_since_profile
    FROM latest_profile
    WHERE {{ dbt.datediff("last_profiled", dbt.current_timestamp(), "hour") }} > {{ max_hours }}

{% endtest %}
