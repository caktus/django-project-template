include:
  - project.app
  - rabbitmq.project
  - supervisor

celery_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-celery.conf
    - source: salt://project/supervisor/celery.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "/var/www/{{ pillar['project_name']}}/log"
        virtualenv_root: "/var/www/{{ pillar['project_name']}}/env"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        flags: "-B --loglevel=INFO"
    - require:
      - pkg: supervisor
      - file: log_dir

celery_process:
  supervisord:
    - name: {{ pillar['project_name'] }}:{{ pillar['project_name'] }}-worker
    - running
    - restart: True
    - require:
      - pkg: supervisor
      - file: celery_conf

extend:
  group_conf:
    file.managed:
      - context:
          programs: "{{ pillar['project_name'] }}-server,{{ pillar['project_name'] }}-worker"
