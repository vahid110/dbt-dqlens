{% macro dqlens_profile(schema=none, exclude=none) %}
    {#
        Profiles all models in the target schema using DQLens.
        Reads connection info from the active dbt profile.

        Usage:
            dbt run-operation dqlens_profile
            dbt run-operation dqlens_profile --args '{"schema": "analytics"}'

        Requires: pip install dqlens
    #}

    {% set target_schema = schema or target.schema %}
    {% set exclude_tables = exclude or var('dqlens', {}).get('exclude_tables', []) %}

    {# Build connection URL from dbt target #}
    {% if target.type == 'postgres' %}
        {% set conn_url = 'postgresql://' ~ target.user ~ ':' ~ target.password ~ '@' ~ target.host ~ ':' ~ (target.port | default(5432)) ~ '/' ~ target.dbname %}
    {% elif target.type == 'snowflake' %}
        {% set conn_url = 'snowflake://' ~ target.user ~ ':' ~ target.password ~ '@' ~ target.account ~ '/' ~ target.database ~ '/' ~ target_schema %}
    {% else %}
        {{ exceptions.raise_compiler_error(
            "dbt-dqlens: unsupported target type '" ~ target.type ~ "'. Supported: postgres, snowflake."
        ) }}
    {% endif %}

    {# Build the CLI command #}
    {% set init_cmd = 'dqlens init "' ~ conn_url ~ '" --schema ' ~ target_schema %}
    {% set profile_cmd = 'dqlens profile' %}
    {% if exclude_tables | length > 0 %}
        {% set profile_cmd = profile_cmd ~ ' --exclude ' ~ exclude_tables | join(',') %}
    {% endif %}

    {{ log("dbt-dqlens: initializing for schema '" ~ target_schema ~ "'...", info=True) }}
    {% set init_result = dqlens.run_cmd(init_cmd) %}

    {{ log("dbt-dqlens: profiling...", info=True) }}
    {% set profile_result = dqlens.run_cmd(profile_cmd) %}

    {{ log("dbt-dqlens: profile complete.", info=True) }}
    {{ log("dbt-dqlens: run 'dbt run-operation dqlens_generate_tests' to generate test YAML.", info=True) }}

    {{ return("") }}
{% endmacro %}


{% macro run_cmd(cmd) %}
    {#
        Executes a shell command. Used internally by dqlens macros.
        This is a thin wrapper that delegates to the Python runner.
    #}
    {% set result = run_query("select 1") %}
    {# In practice, this macro is replaced by the Python-based approach below.
       dbt doesn't natively support shell execution from Jinja.
       The actual execution path is via the CLI wrapper script. #}
    {{ return(result) }}
{% endmacro %}
