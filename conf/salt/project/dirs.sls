{% import 'project/_vars.sls' as vars with context %}

include:
  - project.user

root_dir:
  file.directory:
    - name: {{ vars.root_dir }}
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
