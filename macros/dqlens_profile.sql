{#
    dbt-dqlens profiling is done via the CLI, not dbt macros.
    dbt's Jinja engine cannot call external Python tools.

    Usage (from your terminal, after dbt run):

        dqlens-dbt profile
        dqlens-dbt generate-tests
        dbt test --select tag:dqlens

    This file exists so the package structure is valid on dbt Hub.
    The actual logic lives in the dqlens_dbt Python package (pip install dbt-dqlens).
#}

{% macro dqlens_profile() %}
    {{ exceptions.raise_compiler_error(
        "dbt-dqlens: profiling runs via CLI, not dbt macros.\n"
        "Run this in your terminal instead:\n\n"
        "    dqlens-dbt profile\n"
        "    dqlens-dbt generate-tests\n\n"
        "See: https://github.com/vahid110/dbt-dqlens"
    ) }}
{% endmacro %}
