{#
    dbt-dqlens test generation is done via the CLI, not dbt macros.

    Usage (from your terminal):

        dqlens-dbt generate-tests
        dbt test --select tag:dqlens

    This file exists so the package structure is valid on dbt Hub.
    The actual logic lives in the dqlens_dbt Python package (pip install dbt-dqlens).
#}

{% macro dqlens_generate_tests() %}
    {{ exceptions.raise_compiler_error(
        "dbt-dqlens: test generation runs via CLI, not dbt macros.\n"
        "Run this in your terminal instead:\n\n"
        "    dqlens-dbt generate-tests\n\n"
        "See: https://github.com/vahid110/dbt-dqlens"
    ) }}
{% endmacro %}
