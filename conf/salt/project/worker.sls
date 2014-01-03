{% import 'project/_vars.sls' as vars with context %}
{% set venv_dir = vars.path_from_root('env') %}

include:
  - project.app
  - rabbitmq.project
  - supervisor

celery_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ vars.project }}-celery.conf
    - source: salt://project/supervisor/celery.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        virtualenv_root: "{{ venv_dir }}"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        flags: "-B --loglevel=INFO --schedule={{ vars.root_dir }}celerybeat-schedule"
        project: "{{ vars.project }}"
    - require:
      - pkg: supervisor
      - file: log_dir
    - watch_in:
      - cmd: supervisor_update

celery_process:
  supervisord:
    - name: {{ vars.project }}:{{ vars.project }}-worker
    - running
    - restart: True
    - require:
      - pkg: supervisor
      - file: celery_conf

extend:
  group_conf:
    file.managed:
      - context:
          programs: "{{ vars.project }}-server,{{ vars.project }}-worker"
