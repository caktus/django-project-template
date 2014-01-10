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
    # Uncomment to enable solr and add solr to supervisor/group.conf
    # - project.solr
