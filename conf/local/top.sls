base:
  '*':
    - base
    - vagrant.user
    - users.devs
    - sshd
    - sshd.github
    - locale.utf8
    - project.user
    - project.app
    - project.web
    - project.db
    - project.python3
    # Uncomment to enable celery worker configuration
    # - project.worker
