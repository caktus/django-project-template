{% import 'project/_vars.sls' as vars with context %}

include:
  - project.dirs
  - project.repo
  - python

venv:
  virtualenv.managed:
    - name: {{ vars.venv_dir }}
    - requirements: {{ vars.build_path(vars.source_dir, 'requirements/production.txt') }}
    - require:
      - pip: virtualenv
      - file: root_dir
      - git: project_repo
      - pkg: python-headers

venv_dir:
  file.directory:
    - name: {{ vars.venv_dir }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - recurse:
      - user
      - group
    - require:
      - virtualenv: venv

project_path:
  file.managed:
    - contents: "{{ vars.source_dir }}"
    - name: {{ vars.build_path(vars.venv_dir, 'lib/python3.3/site-packages/project.pth') }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - require:
      - virtualenv: venv