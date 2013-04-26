include:
  - memcached
  - postfix
  - version-control
  - nginx
  - python
  - supervisor

project_user:
  user.present:
    - name: {{ pillar['project_name'] }}
    - groups: [www-data]

/var/www/:
  file.directory:
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - makedirs: True

/var/www/log/:
  file.directory:
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - makedirs: True

/home/www/env/:
  virtualenv.managed:
    - no_site_packages: True
    - distribute: True

nginx_log:
  file.managed:
    - name: /var/www/log/error.log
    - user: {{ pillar['project_name'] }}

/etc/nginx/sites-enabled/{{ pillar['project_name'] }}.conf:
  file.managed:
    - source: salt://project/nginx.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        code_root: "/var/www/{{ pillar['project_name']}}"
        log_dir: "/var/www/log"
    - require:
      - file: nginx_log
