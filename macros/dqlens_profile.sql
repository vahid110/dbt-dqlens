{#
    DQLens Profile Macro (Native SQL)
    Generates a SQL query that profiles all tables and columns in the target schema.

    Usage: This macro is called by the dqlens_profile_results model.
#}

{% macro dqlens_get_profile_query(schema_name=none) %}
    {% set target_schema = schema_name or target.schema %}

    {# Get list of tables from information_schema #}
    {% if execute %}
        {% set tables_query %}
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '{{ target_schema }}'
                AND table_type = 'BASE TABLE'
                AND table_name NOT LIKE 'dqlens_%'
            ORDER BY table_name
        {% endset %}

        {% set tables_result = run_query(tables_query) %}
        {% set table_names = tables_result.columns[0].values() %}
    {% else %}
        {% set table_names = [] %}
    {% endif %}

    {% if table_names | length == 0 %}
        SELECT
            CAST(NULL AS {{ dbt.type_string() }}) as table_name,
            CAST(NULL AS {{ dbt.type_string() }}) as column_name,
            CAST(NULL AS {{ dbt.type_string() }}) as data_type,
            CAST(0 AS {{ dbt.type_bigint() }}) as row_count,
            CAST(0 AS {{ dbt.type_bigint() }}) as null_count,
            CAST(0.0 AS {{ dbt.type_float() }}) as null_pct,
            CAST(0 AS {{ dbt.type_bigint() }}) as distinct_count,
            CAST(NULL AS {{ dbt.type_float() }}) as min_value,
            CAST(NULL AS {{ dbt.type_float() }}) as max_value,
            CAST(0 AS {{ dbt.type_bigint() }}) as empty_string_count,
            CAST(NULL AS {{ dbt.type_timestamp() }}) as profiled_at
        WHERE 1 = 0
    {% else %}
        {% set queries = [] %}

        {% for table_name in table_names %}
            {# Get columns for this table #}
            {% set cols_query %}
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = '{{ target_schema }}'
                    AND table_name = '{{ table_name }}'
                ORDER BY ordinal_position
            {% endset %}

            {% set cols_result = run_query(cols_query) %}

            {% for i in range(cols_result.rows | length) %}
                {% set col_name = cols_result.rows[i][0] %}
                {% set col_type = cols_result.rows[i][1] %}
                {% set is_numeric = col_type in ('integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision', 'float') %}
                {% set is_text = col_type in ('character varying', 'varchar', 'text', 'char', 'character') %}

                {% set col_sql %}
                SELECT
                    '{{ table_name }}' as table_name,
                    '{{ col_name }}' as column_name,
                    '{{ col_type }}' as data_type,
                    CAST(COUNT(*) AS BIGINT) as row_count,
                    CAST(SUM(CASE WHEN "{{ col_name }}" IS NULL THEN 1 ELSE 0 END) AS BIGINT) as null_count,
                    ROUND(
                        CAST(SUM(CASE WHEN "{{ col_name }}" IS NULL THEN 1 ELSE 0 END) AS NUMERIC)
                        / NULLIF(CAST(COUNT(*) AS NUMERIC), 0) * 100, 2
                    ) as null_pct,
                    CAST(COUNT(DISTINCT "{{ col_name }}") AS BIGINT) as distinct_count,
                    {% if is_numeric %}
                    CAST(MIN("{{ col_name }}") AS DOUBLE PRECISION) as min_value,
                    CAST(MAX("{{ col_name }}") AS DOUBLE PRECISION) as max_value,
                    {% else %}
                    CAST(NULL AS DOUBLE PRECISION) as min_value,
                    CAST(NULL AS DOUBLE PRECISION) as max_value,
                    {% endif %}
                    {% if is_text %}
                    CAST(SUM(CASE WHEN "{{ col_name }}" = '' THEN 1 ELSE 0 END) AS BIGINT) as empty_string_count,
                    {% else %}
                    CAST(0 AS BIGINT) as empty_string_count,
                    {% endif %}
                    CAST('{{ run_started_at }}' AS TIMESTAMP) as profiled_at
                FROM "{{ target_schema }}"."{{ table_name }}"
                {% endset %}

                {% do queries.append(col_sql) %}
            {% endfor %}
        {% endfor %}

        {{ queries | join("\nUNION ALL\n") }}
    {% endif %}
{% endmacro %}
