{% import 'project/_vars.sls' as vars with context %}
{% set venv_dir = vars.path_from_root('env') %}

include:
  - memcached
  - postfix
  - version-control
  - python
  - supervisor

root_dir:
  file.directory:
    - name: {{ vars.root_dir }}
    - user: {{ pillar['project_name'] }}
    - group: admin
    - mode: 775
    - makedirs: True
    - require:
      - user: project_user

run_dir:
  file.directory:
    - name: {{ vars.run_dir }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 775
    - makedirs: True
    - require:
      - user: project_user

log_dir:
  file.directory:
    - name: {{ vars.log_dir }}
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - mode: 775
    - makedirs: True
    - require:
      - file: root_dir

venv:
  virtualenv.managed:
    - name: {{ venv_dir }}
    - no_site_packages: True
    - distribute: True
    - require:
      - pip: virtualenv
      - file: root_dir

venv_dir:
  file.directory:
    - name: {{ venv_dir }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - recurse:
      - user
      - group
    - require:
      - virtualenv: venv

activate:
  file.append:
    - name: {{ vars.build_path(venv_dir, "bin/activate") }}
    - text: source {{ vars.build_path(venv_dir, "bin/secrets") }}
    - require:
      - virtualenv: venv

secrets:
  file.managed:
    - name: {{ vars.build_path(venv_dir, "bin/secrets") }}
    - source: salt://project/env_secrets.jinja2
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - template: jinja
    - require:
      - file: activate

group_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ vars.project }}-group.conf
    - source: salt://project/supervisor/group.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        programs: "{{ vars.project }}-server"
        project: "{{ vars.project }}"
    - require:
      - pkg: supervisor
      - file: log_dir
    - watch_in:
      - cmd: supervisor_update

gunicorn_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ vars.project }}-gunicorn.conf
    - source: salt://project/supervisor/gunicorn.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        virtualenv_root: "{{ venv_dir }}"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        project: "{{ vars.project }}"
        socket: "{{ vars.server_socket }}"
    - require:
      - pkg: supervisor
      - file: log_dir
    - watch_in:
      - cmd: supervisor_update

gunicorn_process:
  supervisord:
    - name: {{ vars.project }}:{{ vars.project }}-server
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
    - name: npm install less@1.3.3 -g
    - user: root
    - unless: which lessc
    - require:
      - pkg: npm
  file.symlink:
    - name: /usr/bin/lessc
    - target: /usr/local/bin/lessc
