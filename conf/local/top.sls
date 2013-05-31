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
    # Uncomment to enable celery worker configuration
    # - project.worker