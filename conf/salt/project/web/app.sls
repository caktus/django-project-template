{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv
  - project.django
  - postfix
  - ufw

gunicorn_requirements:
  pip.installed:
    - name: "gunicorn>=19.1,<19.2"
    - bin_env: {{ vars.venv_dir }}
    - upgrade: true
    - require:
      - virtualenv: venv

gunicorn_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-gunicorn.conf
    - source: salt://project/web/gunicorn.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
{% if 'newrelic_license_key' in pillar['secrets'] %}
        newrelic_config_file: "{{ vars.services_dir }}/newrelic-app.ini"
{% endif %}
        log_dir: "{{ vars.log_dir }}"
        settings: "{{ pillar['project_name'] }}.settings.{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
    - require:
      - pip: supervisor
      - file: log_dir
      - pip: pip_requirements
      - pip: gunicorn_requirements
    - watch_in:
      - cmd: supervisor_update

gunicorn_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-server
    - restart: True
    - require:
      - file: gunicorn_conf

{% for host, ifaces in vars.balancer_minions.items() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
app_allow-{{ host_addr }}:
  ufw.allow:
    - name: '8000'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}

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
    - name: npm install less@{{ pillar['less_version'] }} -g
    - user: root
    - unless: "which lessc && lessc --version | grep {{ pillar['less_version'] }}"
    - require:
      - pkg: nodejs

collectstatic:
  cmd.run:
    - name: "{{ vars.path_from_root('manage.sh') }} collectstatic --noinput"
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - require:
      - file: manage

migrate:
  cmd.run:
    - name: "{{ vars.path_from_root('manage.sh') }} migrate --noinput"
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - onlyif: "{{ vars.path_from_root('manage.sh') }} migrate --list | grep '\\[ \\]'"
    - require:
      - file: manage
    - order: last
