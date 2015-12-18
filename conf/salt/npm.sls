{% import 'project/_vars.sls' as vars with context %}
include:
  - project.web.app

# Install NodeJS v4.x, to match local frontend dev setup
nodejs_repo:
  pkgrepo.managed:
    - humanname: NodeSource Node.js PPA
    - name: deb https://deb.nodesource.com/node_4.x {{ grains['lsb_distrib_codename'] }} main
    - file: /etc/apt/sources.list.d/nodesource.list
    - key_url: salt://project/web/nodesource.pub
    - require_in:
      - pkg: nodejs

nodejs:
  pkg.latest:
    - name: nodejs

npm_installs:
  cmd.run:
    - name: npm install; npm update
    - cwd: "{{ vars.source_dir }}"
    - user: {{ pillar['project_name'] }}
    - require:
      - pkg: nodejs
    - require_in:
      - cmd: collectstatic

gulp_build:
  cmd.run:
    - name: npm run build
    - cwd: "{{ vars.source_dir }}"
    - user: {{ pillar['project_name'] }}
    - require:
      - cmd: npm_installs
    - require_in:
      - cmd: collectstatic
