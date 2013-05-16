include:
  - project.app
  - rabbitmq.project
  - supervisor

celery_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ pillar['project_name'] }}-{{ pillar['environment'] }}-celery.conf
    - source: salt://project/supervisor/celery.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/log"
        virtualenv_root: "/var/www/{{ pillar['project_name']}}-{{ pillar['environment'] }}/env"
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        flags: "-B --loglevel=INFO"
    - require:
      - pkg: supervisor
      - file: log_dir

celery_process:
  supervisord:
    - name: {{ pillar['project_name'] }}-{{ pillar['environment'] }}:{{ pillar['project_name'] }}-{{ pillar['environment'] }}-worker
    - running
    - restart: True
    - require:
      - pkg: supervisor
      - file: celery_conf

extend:
  group_conf:
    file.managed:
      - context:
          programs: "{{ pillar['project_name'] }}-{{ pillar['environment'] }}-server,{{ pillar['project_name'] }}-{{ pillar['environment'] }}-worker"
