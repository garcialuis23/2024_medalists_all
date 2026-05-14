{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- set env = target.name | upper -%}
    {%- if custom_database_name is none -%}
        {{ target.database }}
    {%- else -%}
        {{ custom_database_name }}_{{ env }}
    {%- endif -%}
{%- endmacro %}
