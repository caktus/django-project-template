include:
  - memcached
  - postfix
  - version-control
  - python
  - supervisor

root_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/
    - user: {{ pillar['project_name'] }}
    - group: admin
    - mode: 775
    - makedirs: True
    - require:
      - user: project_user

log_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/log/
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

public_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/public/
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

venv:
  virtualenv.managed:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/env/
    - no_site_packages: True
    - distribute: True
    - require:
      - pip: virtualenv
      - file: root_dir

venv_dir:
  file.directory:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/env/
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - recurse:
      - user
      - group
    - require:
      - virtualenv: venv

activate:
  file.append:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/env/bin/activate
    - text: source /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/env/bin/secrets
    - require:
      - virtualenv: venv

secrets:
  file.managed:
    - name: /var/www/{{ pillar['project_name'] }}-{{ pillar['environment'] }}/env/bin/secrets
    - source: salt://project/env_secrets.jinja2
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - template: jinja
    - require:
      - file: activate

group_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-{{ pillar['environment'] }}-group.conf
    - source: salt://project/supervisor/group.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        programs: "{{ pillar['project_name'] }}-{{ pillar['environment'] }}-server"
    - require:
      - pkg: supervisor
      - file: log_dir

gunicorn_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-{{ pillar['environment'] }}-gunicorn.conf
    - source: salt://project/supervisor/gunicorn.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/log"
        virtualenv_root: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/env"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
    - require:
      - pkg: supervisor
      - file: log_dir

gunicorn_process:
  supervisord:
    - name: {{ pillar['project_name'] }}-{{ pillar['environment'] }}:{{ pillar['project_name'] }}-{{ pillar['environment'] }}-server
    - running
    - restart: True
    - require:
      - pkg: supervisor
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