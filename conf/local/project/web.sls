include:
  - memcached
  - postfix
  - version-control
  - nginx
  - python
  - supervisor

project_user:
  user.present:
    - name: {{ pillar['project_name'] }}
    - groups: [www-data]

/var/www/:
  file.directory:
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - makedirs: True

/var/www/log/:
  file.directory:
    - user: {{ pillar['project_name'] }}
    - group: www-data
    - makedirs: True

/home/www/env/:
  virtualenv.managed:
    - no_site_packages: True
    - distribute: True