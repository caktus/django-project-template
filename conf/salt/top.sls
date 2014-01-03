base:
  '*':
    - base
    - sudo
    - sshd
    - sshd.github
    - locale.utf8
    - users.devs
    - users.project
    - salt.minion
  'precise32':
    - vagrant.user
  'roles:salt-master':
    - match: grain
    - salt.master
  'roles:(web|worker)':
    - match: grain_pcre
    - project.dirs
    - project.repo
    - project.venv
  'roles:web':
    - match: grain
    - project.web.app
  'roles:worker':
    - match: grain
    - project.worker.default
    - project.worker.beat
  'roles:balancer':
    - match: grain
    - project.web.balancer
  'roles:db-master':
    - match: grain
    - postgresql
    - project.db
  'roles:queue':
    - match: grain
    - rabbitmq
    - project.queue
  'roles:cache':
    - match: grain
    - memcached
    - project.cache
