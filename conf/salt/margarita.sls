git-install:
  pkg.installed:
    - name: git-core

clone_repo:
  cmd.run:
     - name: git clone https://github.com/caktus/margarita.git margarita
     - user: root
     - unless: test -e /srv/project/margarita/.git
     - cwd: /srv/project
     - requires:
       - pkg: git-install

fetch_repo:
  cmd.run:
     - name: git fetch origin
     - user: root
     - cwd: /srv/project/margarita
     - requires:
        - cmd: clone_repo
        - pkg: git-install

reset_repo:
  cmd.run:
     - name: git reset --hard {{ pillar['margarita_version'] }}
     - user: root
     - cwd: /srv/project/margarita
     - requires:
        - cmd: fetch_repo
