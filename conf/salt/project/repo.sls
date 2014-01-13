{% import 'project/_vars.sls' as vars with context %}
include:
  - project.dirs
  - project.user
  - version-control
  - sshd.github

{% if 'github_deploy_key' in pillar %}
project_repo_identity:
  file.managed:
    - name: "/home/{{ pillar['project_name'] }}/.ssh/github"
    - contents_pillar: github_deploy_key
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 600
    - makedirs: True
    - require:
      - user: project_user
{% endif %}

project_repo:
  {% if grains['environment'] == 'local' %}
  file.symlink:
    - name: {{ vars.source_dir }}
    - target: "/vagrant"
    - makedirs: True
    - force: True
    - require:
      - file: root_dir
  {% else %}
  git.latest:
    - name: "{{ pillar['repo']['url'] }}"
    - rev: "{{ pillar['repo'].get('branch', 'master') }}"
    - target: {{ vars.source_dir }}
    - user: {{ pillar['project_name'] }}
    {% if 'github_deploy_key' in pillar %}
    - identity: "/home/{{ pillar['project_name'] }}/.ssh/github"
    {% endif %}
    - require:
      - file: root_dir
      - pkg: git-core
      {% if 'github_deploy_key' in pillar %}
      - file: project_repo_identity
      {% endif %}
      - ssh_known_hosts: github.com
  {% endif %}
