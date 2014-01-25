{% set root_dir = "/var/www/" + pillar['project_name'] + "/" %}

{% macro get_primary_ip(ifaces) -%}
  {{ ifaces.get(salt['pillar.get']('primary_iface', 'eth0'), {}).get('inet', [{}])[0].get('address') }}
{%- endmacro %}

{% macro build_path(root, name) -%}
  {{ root }}{%- if not root.endswith('/') -%}/{%- endif -%}{{ name }}
{%- endmacro %}

{% macro path_from_root(name) -%}
  {{ build_path(root_dir, name) }}
{%- endmacro %}

{% set auth_file = path_from_root(".htpasswd") %}
{% set current_ip = grains['ip_interfaces'].get(salt['pillar.get']('primary_iface', 'eth0'), [])[0] %}
{% set log_dir = path_from_root('log') %}
{% set public_dir = path_from_root('public') %}
{% set ssh_dir = "/home/" + pillar['project_name'] + "/.ssh/" %}
{% set ssl_dir = path_from_root('ssl') %}
{% set source_dir = path_from_root('source') %}
{% set venv_dir = path_from_root('env') %}
