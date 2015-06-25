git-install:
  pkg.installed:
    - name: git-core

project_repo:
  git.latest:
    - name: https://github.com/caktus/margarita.git
    - rev: 1.0.1
    - force: true
    - target: /srv/margarita
    - user: root
    - always_fetch: true
    - require:
      - pkg: git-install
