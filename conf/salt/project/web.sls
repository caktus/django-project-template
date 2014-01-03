{% import 'project/_vars.sls' as vars with context %}
{% set ssl_dir = vars.path_from_root('ssl') %}
{% set public_dir = vars.path_from_root('public') %}
{% set auth_file = vars.path_from_root(".htpasswd") %}

include:
  - nginx
  - nginx.cert
  - ufw

http_firewall:
  ufw.allow:
    - names:
      - '80'
      - '443'
    - enabled: true

public_dir:
  file.directory:
    - name: {{ public_dir }}
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

ssl_dir:
  file.directory:
    - name: {{ ssl_dir }}
    - user: root
    - group: www-data
    - mode: 644
    - makedirs: True
    - require:
      - file: root_dir

ssl_cert:
  cmd.run:
    - name: cd {{ ssl_dir }} && /var/lib/nginx/generate-cert.sh {{ pillar['domain'] }}
    - cwd: {{ ssl_dir }}
    - user: root
    - unless: test -e {{ vars.build_path(ssl_dir, pillar['domain'] + ".crt") }}
    - require:
      - file: ssl_dir
      - file: generate_cert

{% if 'http_auth' in pillar %}
apache2-utils:
  pkg:
    - installed

auth_file:
  cmd.run:
    - names:
{%- for key, value in pillar['http_auth'].items() %}
      - htpasswd {% if loop.first -%}-c{%- endif %} -bd {{ auth_file }} {{ key }} {{ value }}
{% endfor %}
    - require:
      - pkg: apache2-utils
      - file: root_dir

{{ auth_file }}:
  file.managed:
    - user: root
    - group: www-data
    - mode: 640
    - require:
      - file: root_dir
      - cmd: auth_file
{% endif %}

nginx_conf:
  file.managed:
    - name: /etc/nginx/sites-enabled/{{ vars.project }}.conf
    - source: salt://project/nginx.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        public_root: "{{ public_dir }}"
        log_dir: "{{ vars.log_dir }}"
        ssl_dir: "{{ ssl_dir }}"
        socket: "{{ vars.server_socket }}"
        {%- if 'http_auth' in pillar %}
        auth_file: "{{ auth_file }}"
        {% endif %}
    - require:
      - pkg: nginx
      - file: log_dir
      - file: ssl_dir
      - cmd: ssl_cert
      {%- if 'http_auth' in pillar %}
      - cmd: auth_file
      {% endif %}

extend:
  nginx:
    service:
      - running
      - watch:
        - file: nginx_conf