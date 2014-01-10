{% import 'project/_vars.sls' as vars with context %}

include:
  - project.user
  - project.dirs
  - project.venv

manage:
  file.managed:
    - name: {{ vars.path_from_root('manage.sh') }}
    - source: salt://project/django/manage.sh
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 700
    - template: jinja
    - context:
        settings: "{{ pillar['project_name']}}.settings.{{ pillar['environment'] }}"
        virtualenv_root: "{{ vars.venv_dir }}"
        directory: "{{ vars.source_dir }}"
    - require:
      - virtualenv: venv
      - file: project_path
      - file: log_dir
