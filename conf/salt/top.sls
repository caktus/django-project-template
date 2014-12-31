base:
  '*':
    - base
    - sudo
    - sshd
    - sshd.github
    - locale.utf8
    - project.devs
    - salt.minion
{% if 'newrelic_license_key' in pillar['secrets'] %}
    - newrelic_sysmon
{% endif %}
  'environment:local':
    - match: grain
    - vagrant.user
  'roles:salt-master':
    - match: grain
    - salt.master
  'roles:web':
    - match: grain
    - project.web.app
{% if 'newrelic_license_key' in pillar['secrets'] %}
    - project.newrelic_webmon
{% endif %}
  'roles:worker':
    - match: grain
    - project.worker.default
    - project.worker.beat
  'roles:balancer':
    - match: grain
    - project.web.balancer
  'roles:db-master':
    - match: grain
    - project.db
  'roles:queue':
    - match: grain
    - project.queue
  'roles:cache':
    - match: grain
    - project.cache
