{% import 'project/_vars.sls' as vars with context %}

include:
  - project.dirs
  - project.repo
  - python

python-pkgs:
  pkg:
    - installed
    - names:
      - python{{ pillar['python_version'] }}
      - python{{ pillar['python_version'] }}-dev
    - require:
      - pkgrepo: deadsnakes

venv:
  virtualenv.managed:
    - name: {{ vars.venv_dir }}
    - python: {{ '/usr/bin/python' ~ pillar['python_version'] }}
    - user: {{ pillar['project_name'] }}
    - require:
      - pip: virtualenv
      - file: root_dir
      {% if grains['environment'] == 'local' %}
      - file: project_repo
      {% else %}
      - cmd: delete_pyc
      {% endif %}
      - pkg: python-pkgs
      - pkg: python-headers

pip_requirements:
  pip.installed:
    - bin_env: {{ vars.venv_dir }}
    - requirements: {{ vars.build_path(vars.source_dir, 'requirements/production.txt') }}
    - upgrade: true
    - require:
      - virtualenv: venv

project_path:
  file.managed:
    - contents: "{{ vars.source_dir }}"
    - name: {{ vars.build_path(vars.venv_dir, 'lib/python' ~ pillar['python_version'] ~ '/site-packages/project.pth') }}
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - require:
      - pip: pip_requirements

ghostscript:
  pkg.installed
