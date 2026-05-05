{% test dqlens_no_null_drift(model, column_name, baseline_pct, threshold_multiplier=3) %}
    {#
        Fails if the null rate of a column has increased beyond threshold
        compared to the profiled baseline.

        Args:
            model: the dbt model to test
            column_name: the column to check
            baseline_pct: null percentage at last profile time
            threshold_multiplier: how many times the baseline is acceptable (default 3x)

        Generated automatically by `dbt run-operation dqlens_generate_tests`.
    #}

    {% set threshold = baseline_pct * threshold_multiplier %}

    select
        '{{ column_name }}' as column_name,
        count(*) as total_rows,
        count(*) filter (where {{ column_name }} is null) as null_count,
        round(
            count(*) filter (where {{ column_name }} is null)::numeric
            / nullif(count(*), 0) * 100, 2
        ) as null_pct,
        {{ baseline_pct }} as baseline_pct,
        {{ threshold }} as threshold_pct
    from {{ model }}
    having
        round(
            count(*) filter (where {{ column_name }} is null)::numeric
            / nullif(count(*), 0) * 100, 2
        ) > {{ threshold }}

{% endtest %}
