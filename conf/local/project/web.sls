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

root_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}/
    - user: {{ pillar['project_name'] }}
    - group: admin
    - mode: 775
    - makedirs: True
    - require:
      - user: project_user

log_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}/log/
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

public_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}/public/
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

venv:
  virtualenv.managed:
    - name: /var/www/{{ pillar['project_name'] }}/env/
    - no_site_packages: True
    - distribute: True
    - require:
      - pip: virtualenv
      - file: root_dir

venv_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}/env/
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - recurse:
      - user
      - group
    - require:
      - virtualenv: venv

activate:
  file.append:
    - name: /var/www/{{ pillar['project_name'] }}/env/bin/activate
    - text: source /var/www/{{ pillar['project_name'] }}/env/bin/secrets
    - require:
      - virtualenv: venv

secrets:
  file.managed:
    - name: /var/www/{{ pillar['project_name'] }}/env/bin/secrets
    - source: salt://project/env_secrets.jinja2
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - template: jinja
    - require:
      - file: activate

nginx_conf:
  file.managed:
    - name: /etc/nginx/sites-enabled/{{ pillar['project_name'] }}.conf
    - source: salt://project/nginx.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        public_root: "/var/www/{{ pillar['project_name']}}/public"
        log_dir: "/var/www/{{ pillar['project_name']}}/log"
    - require:
      - pkg: nginx
      - file: log_dir

extend:
  nginx:
    service:
      - running
      - watch:
        - file: nginx_conf

group_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-group.conf
    - source: salt://project/supervisor/group.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: supervisor
      - file: log_dir

gunicorn_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-gunicorn.conf
    - source: salt://project/supervisor/gunicorn.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "/var/www/{{ pillar['project_name']}}/log"
        virtualenv_root: "/var/www/{{ pillar['project_name']}}/env"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
    - require:
      - pkg: supervisor
      - file: log_dir

extend:
  supervisor:
    service:
      - running
      - watch:
        - file: group_conf
        - file: gunicorn_conf

npm:
  pkg:
    - installed

less:
  cmd.run:
    - name: npm install less -g
    - user: root
    - unless: which lessc
    - require:
      - pkg: npm
  file.symlink:
    - name: /usr/bin/lessc
    - target: /usr/local/bin/lessc