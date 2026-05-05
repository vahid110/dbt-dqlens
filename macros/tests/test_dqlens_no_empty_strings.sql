{% test dqlens_no_empty_strings(model, column_name, max_pct=30) %}
    {#
        Fails if the percentage of empty strings in a column exceeds max_pct.
        Empty strings pass not_null checks but carry no information.

        Args:
            model: the dbt model to test
            column_name: the column to check
            max_pct: maximum acceptable empty string percentage (default 30%)

        Generated automatically by `dbt run-operation dqlens_generate_tests`.
    #}

    select
        '{{ column_name }}' as column_name,
        count(*) filter (where {{ column_name }} is not null) as non_null_count,
        count(*) filter (where {{ column_name }} = '') as empty_count,
        round(
            count(*) filter (where {{ column_name }} = '')::numeric
            / nullif(count(*) filter (where {{ column_name }} is not null), 0) * 100, 2
        ) as empty_pct
    from {{ model }}
    having
        round(
            count(*) filter (where {{ column_name }} = '')::numeric
            / nullif(count(*) filter (where {{ column_name }} is not null), 0) * 100, 2
        ) > {{ max_pct }}

{% endtest %}
