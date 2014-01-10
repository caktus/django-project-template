{% import 'project/_vars.sls' as vars with context %}

include:
  - supervisor.pip
  - project.dirs
  - project.venv

beat_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-celery-beat.conf
    - source: salt://project/worker/celery.conf
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        settings: "{{ pillar['project_name'] }}.settings.{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
        name: "celery-beat"
        command: "beat"
        flags: "--schedule={{ vars.path_from_root('celerybeat-schedule.db') }} --pidfile={{ vars.path_from_root('celerybeat.pid') }} --loglevel=INFO"
    - require:
      - pip: supervisor
      - file: log_dir
      - virtualenv: venv
    - watch_in:
      - cmd: supervisor_update

beat_process:
  supervisord.running:
    - name: {{ pillar['project_name'] }}-celery-beat
    - restart: True
    - require:
      - file: beat_conf
