{% import 'project/_vars.sls' as vars with context %}
{% set auth_file=vars.auth_file %}
{% set self_signed='ssl_key' not in pillar or 'ssl_cert' not in pillar %}

include:
  - nginx
  - nginx.cert
  - ufw
  - project.dirs

http_firewall:
  ufw.allow:
    - names:
      - '80'
      - '443'
    - enabled: true

public_dir:
  file.directory:
    - name: {{ vars.public_dir }}
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

ssl_dir:
  file.directory:
    - name: {{ vars.ssl_dir }}
    - user: root
    - group: www-data
    - mode: 644
    - makedirs: True
    - require:
      - file: root_dir

{% if self_signed %}
ssl_cert:
  cmd.run:
    - name: cd {{ vars.ssl_dir }} && /var/lib/nginx/generate-cert.sh {{ pillar['domain'] }}
    - cwd: {{ vars.ssl_dir }}
    - user: root
    - unless: test -e {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".crt") }}
    - require:
      - file: ssl_dir
      - file: generate_cert
    - watch_in:
      - service: nginx
{% else %}
ssl_key:
  file.managed:
    - name: {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".key") }}
    - contents_pillar: ssl_key
    - user: root
    - mode: 600
    - require:
      - file: ssl_dir
    - watch_in:
      - service: nginx

ssl_cert:
  file.managed:
    - name: {{ vars.build_path(vars.ssl_dir, pillar['domain'] + ".crt") }}
    - contents_pillar: ssl_cert
    - user: root
    - mode: 600
    - require:
      - file: ssl_dir
    - watch_in:
      - service: nginx
{% endif %}


{% if 'http_auth' in pillar %}
apache2-utils:
  pkg:
    - installed

clear_auth_file:
  file.absent:
    - name: {{ auth_file }}
    - require:
      - file: root_dir
      - pkg: apache2-utils

auth_file:
  cmd.run:
    - names:
{%- for key, value in pillar['http_auth'].items() %}
      - htpasswd -bd {{ auth_file }} {{ key }} {{ value }}
{% endfor %}
    - require:
      - pkg: apache2-utils
      - file: root_dir
      - file: clear_auth_file
      - file: {{ auth_file }}

{{ auth_file }}:
  file.managed:
    - user: root
    - group: www-data
    - mode: 640
    - require:
      - file: root_dir
      - file: clear_auth_file
    - watch_in:
      - service: nginx
{% endif %}

nginx_conf:
  file.managed:
    - name: /etc/nginx/sites-enabled/{{ pillar['project_name'] }}.conf
    - source: salt://project/web/site.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        public_root: "{{ vars.public_dir }}"
        log_dir: "{{ vars.log_dir }}"
        ssl_dir: "{{ vars.ssl_dir }}"
        servers:
{% for host, ifaces in vars.web_minions.items() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
          - {% if host_addr == vars.current_ip %}'127.0.0.1'{% else %}{{ host_addr }}{% endif %}
{% endfor %}
        {%- if 'http_auth' in pillar %}
        auth_file: "{{ auth_file }}"
        {% endif %}
    - require:
      - pkg: nginx
      - file: log_dir
      - file: ssl_dir
      {%- if self_signed %}
      - cmd: ssl_cert
      {% else %}
      - file: ssl_key
      - file: ssl_cert
      {% endif %}
      {%- if 'http_auth' in pillar %}
      - cmd: auth_file
      {% endif %}
    - watch_in:
      - service: nginx
