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

ssl_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/ssl/
    - user: root
    - group: www-data
    - mode: 644
    - makedirs: True
    - require:
      - file: root_dir

ssl_cert:
  cmd.run:
    - name: /var/lib/nginx/generate-cert.sh {{ pillar['domain'] }}
    - cwd: /var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/ssl
    - user: root
    - unless: test -e /var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/ssl/{{ pillar['domain'] }}.crt
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
      - htpasswd {% if loop.first -%}-c{%- endif %} -bd /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/.htpasswd {{ key }} {{ value }}
{% endfor %}
    - require:
      - pkg: apache2-utils
      - file: root_dir

/var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/.htpasswd:
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
    - name: /etc/nginx/sites-enabled/{{ pillar['project_name'] }}-{{ pillar['environment'] }}.conf
    - source: salt://project/nginx.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        public_root: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/public"
        log_dir: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/log"
        ssl_dir: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/ssl"
        {%- if 'http_auth' in pillar %}
        auth_file: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/.htpasswd"
        {% endif %}
    - require:
      - pkg: nginx
      - file: log_dir
      - file: ssl_dir
      {%- if 'http_auth' in pillar %}
      - cmd: auth_file
      {% endif %}
extend:
  nginx:
    service:
      - running
      - watch:
        - file: nginx_conf