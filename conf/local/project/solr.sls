{% import 'project/_vars.sls' as vars with context %}
{% set venv_dir = vars.path_from_root('env') %}

include:
  - project.app
  - solr.project
  - supervisor

solr_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ vars.project }}-solr.conf
    - source: salt://project/supervisor/solr.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        project: "{{ vars.project }}"
    - require:
      - pkg: supervisor
      - file: log_dir
    - watch_in:
      - cmd: supervisor_update

solr_process:
  supervisord:
    - name: {{ vars.project }}:{{ vars.project }}-solr
    - running
    - restart: True
    - require:
      - pkg: supervisor
      - file: group_conf
      - file: solr_conf
