{% import 'project/_vars.sls' as vars with context %}
include:
  - project.dirs
  - version-control
  - sshd.github

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

project_repo:
  git.latest:
    - name: "{{ salt['pillar.get']('repo:url') }}"
    - rev: "{{ salt['pillar.get']('repo:branch', 'master') }}"
    - target: {{ vars.source_dir }}
    - runas: {{ pillar['project_name'] }}
    - identity: "/home/{{ pillar['project_name'] }}/.ssh/github"
    - require:
      - file: root_dir
      - pkg: git-core
      - file: project_repo_identity
      - ssh_known_hosts: github.com
