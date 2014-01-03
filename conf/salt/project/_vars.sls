{% set root_dir = "/var/www/" + pillar['project_name'] + "/" %}

{% macro build_path(root, name) -%}
  {{ root }}{%- if not root.endswith('/') -%}/{%- endif -%}{{ name }}
{%- endmacro %}

{% macro path_from_root(name) -%}
  {{ build_path(root_dir, name) }}
{%- endmacro %}

{% set log_dir = path_from_root('log') %}
{% set source_dir = path_from_root('source') %}
{% set venv_dir = path_from_root('env') %}
{% set public_dir = path_from_root('public') %}
{% set ssl_dir = path_from_root('ssl') %}
