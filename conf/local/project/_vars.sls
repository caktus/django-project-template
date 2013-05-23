{% set project = pillar['project_name'] + "-" + pillar['environment'] %}
{% set root_dir = "/var/www/" + project + "/" %}
{% set run_dir = "/var/run/" + project + "/" %}

{% macro build_path(root, name) -%}
  {{ root }}{%- if not root.endswith('/') -%}/{%- endif -%}{{ name }}
{%- endmacro %}

{% macro path_from_root(name) -%}
  {{ build_path(root_dir, name) }}
{%- endmacro %}

{% set log_dir = path_from_root('log') %}
{% set server_socket = build_path(run_dir, project + '.sock') %}