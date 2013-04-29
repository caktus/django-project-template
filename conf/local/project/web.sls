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
    - remove_groups: False
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

/var/www/env/:
  virtualenv.managed:
    - no_site_packages: True
    - distribute: True
    - require:
      - pip: virtualenv

/var/www/env/bin/activate:
  file.append:
    - text: source /var/www/env/bin/secrets
    - require:
      - virtualenv: /var/www/env/

/var/www/env/bin/secrets:
  file.managed:
    - source: salt://project/env_secrets.jinja2
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - template: jinja
    - require:
      - file: /var/www/env/bin/activate

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

/etc/supervisor/conf.d/group.conf:
  file.managed:
    - source: salt://project/supervisor/group.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        code_root: "/var/www/{{ pillar['project_name']}}"
        log_dir: "/var/www/log"
    - require:
      - file: nginx_log

/etc/supervisor/conf.d/gunicorn.conf:
  file.managed:
    - source: salt://project/supervisor/gunicorn.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        code_root: "/var/www/{{ pillar['project_name']}}"
        log_dir: "/var/www/log"
        virtualenv_root: "/var/www/env"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
    - require:
      - file: nginx_log
