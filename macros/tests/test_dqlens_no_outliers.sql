{% test dqlens_no_outliers(model, column_name, lower_bound, upper_bound) %}
    {#
        Fails if any values fall outside the IQR-based bounds.

        Args:
            model: the dbt model to test
            column_name: the numeric column to check
            lower_bound: Q1 - 1.5*IQR (computed by DQLens at profile time)
            upper_bound: Q3 + 1.5*IQR (computed by DQLens at profile time)

        Generated automatically by `dbt run-operation dqlens_generate_tests`.
    #}

    select
        {{ column_name }} as outlier_value,
        case
            when {{ column_name }} < {{ lower_bound }} then 'below_lower_bound'
            when {{ column_name }} > {{ upper_bound }} then 'above_upper_bound'
        end as violation_type
    from {{ model }}
    where {{ column_name }} is not null
      and ({{ column_name }} < {{ lower_bound }} or {{ column_name }} > {{ upper_bound }})

{% endtest %}
