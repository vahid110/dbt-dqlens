{% test dqlens_no_orphans(model, column_name, target_model, target_column) %}
    {#
        Fails if any non-null values in column_name don't exist in
        target_model.target_column (FK integrity check).

        Args:
            model: the dbt model containing the foreign key
            column_name: the FK column
            target_model: the referenced model
            target_column: the referenced column

        Generated automatically by `dbt run-operation dqlens_generate_tests`.
    #}

    select
        {{ column_name }} as orphaned_value,
        count(*) as orphaned_count
    from {{ model }} as src
    where {{ column_name }} is not null
      and {{ column_name }} not in (
          select {{ target_column }}
          from {{ target_model }}
          where {{ target_column }} is not null
      )
    group by {{ column_name }}

{% endtest %}
