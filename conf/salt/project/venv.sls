{% import 'project/_vars.sls' as vars with context %}

include:
  - project.dirs
  - project.repo
  {% if pillar['python_version'] > 3 %}
  - python.33
  {% else %}
  - python.27
  {% endif %}

venv:
  virtualenv.managed:
    - name: {{ vars.venv_dir }}
    - requirements: {{ vars.build_path(vars.source_dir, 'requirements/production.txt') }}
    - python: {{ 'python' ~ pillar['python_version'] }}
    - require:
      - pip: virtualenv
      - file: root_dir
      {% if grains['environment'] == 'local' %}
      - file: project_repo
      {% else %}
      - git: project_repo
      {% endif %}
      - pkg: python-pkgs
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
    - name: {{ vars.build_path(vars.venv_dir, 'lib/python' ~ pillar['python_version'] ~ '/site-packages/project.pth') }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - require:
      - virtualenv: venv