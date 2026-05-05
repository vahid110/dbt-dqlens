{% macro dqlens_generate_tests(output_path=none) %}
    {#
        Generates dbt-native test YAML from DQLens profile results.
        Outputs a _dqlens_tests.yml file that can be committed to the repo.

        Usage:
            dbt run-operation dqlens_generate_tests
            dbt run-operation dqlens_generate_tests --args '{"output_path": "models/staging/_dqlens_tests.yml"}'
    #}

    {% set out = output_path or "models/_dqlens_tests.yml" %}

    {{ log("dbt-dqlens: generating tests from latest profile...", info=True) }}
    {{ log("dbt-dqlens: output will be written to '" ~ out ~ "'", info=True) }}
    {{ log("dbt-dqlens: review the generated file, then commit it to your repo.", info=True) }}

    {# Actual generation happens via Python. This macro is the entry point
       that delegates to the Python runner. See models/dqlens_generate_runner.py #}

{% endmacro %}
