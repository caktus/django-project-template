{% import 'project/_vars.sls' as vars with context %}
include:
  - project.dirs
  - project.user
  - version-control
  - sshd.github

{% if 'github_deploy_key' in pillar %}
project_repo_identity:
  file.managed:
    - name: "{{ vars.ssh_dir }}github"
    - contents_pillar: github_deploy_key
    - user: {{ pillar['project_name'] }}
    - group: {{ pillar['project_name'] }}
    - mode: 600
    - require:
      - user: project_user
      - file: ssh_dir
{% endif %}

project_repo:
  {% if grains['environment'] == 'local' %}
  # Use rsync from the local dev env rather than forcing a commit and push
  # to github to update your vagrant source.
  cmd.run:
    - name: rsync --recursive --delete "/vagrant/" {{ vars.source_dir }}
    - user: root
  file.directory:
    - name: {{ vars.source_dir }}
    - owner: {{ pillar['project_name'] }}
    - recurse:
      - user
    - require:
       - cmd: project_repo
  {% else %}
  git.latest:
    - name: "{{ pillar['repo']['url'] }}"
    - rev: "{{ pillar['repo'].get('branch', 'master') }}"
    - target: {{ vars.source_dir }}
    - force_checkout: True
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
  # This is just here so we can always 'require' file: project_repo
  file.directory:
    - name: {{ vars.source_dir }}
    - owner: {{ pillar['project_name'] }}
  {% endif %}

delete_pyc:
  cmd.run:
    - name: find {{ vars.source_dir}} -name "*.pyc" -delete
    - user: {{ pillar['project_name'] }}
    - require:
        - file: project_repo
