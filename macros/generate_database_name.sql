{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- if custom_database_name is none -%}
        {{ target.database }}
    {%- else -%}
        {%- if target.name | lower == 'pro' -%}
            {{ custom_database_name }}_PRO
        {%- else -%}
            {{ custom_database_name }}_DEV
        {%- endif -%}
    {%- endif -%}
{%- endmacro %}
