{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv

gunicorn_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-gunicorn.conf
    - source: salt://project/web/gunicorn.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        settings: "{{ pillar['project_name'] }}.settings.{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
    - require:
      - pip: supervisor
      - file: log_dir
      - virtualenv: venv
    - watch_in:
      - cmd: supervisor_update

gunicorn_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-server
    - restart: True
    - require:
      - file: gunicorn_conf

node_ppa:
  pkgrepo.managed:
    - ppa: chris-lea/node.js

nodejs:
  pkg.installed:
    - require:
      - pkgrepo: node_ppa
    - refresh: True

less:
  cmd.run:
    - name: npm install less@1.6.0 -g
    - user: root
    - unless: "which lessc && lessc --version | grep 1.6.0"
    - require:
      - pkg: nodejs