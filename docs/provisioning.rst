Server Provisioning
========================


Overview
------------------------

{{ project_name|title }} is deployed on the following stack.

- OS: Ubuntu 12.04 LTS
- Python: 2.7
- Database: Postgres 9.1
- Application Server: Gunicorn
- Frontend Server: Nginx
- Cache: Memcached

These services can configured to run together on a single machine or on different machines.
`Supervisord <http://supervisord.org/>`_ manages the application server process.


Initial Setup
------------------------

Before your project can be deployed to a server, the code needs to be
accessible in a git repository. Once that is done you should update
``conf/pillar/<environment>/env.sls`` to set the repo and branch for the environment.
E.g., change this::

    # FIXME: Update to the correct project repo
    repo:
      url: git@github.com:CHANGEME/CHANGEME.git
      branch: master

to this::

    repo:
      url: git@github.com:account/reponame.git
      branch: master

The repo will also need a deployment key generated so that the Salt minion can access the repository.
See the Github docs on managing deploy keys: https://help.github.com/articles/managing-deploy-keys
Once generated the private key should be added to `conf/pillar/<environment>/secrets.sls`` under the
label `github_deploy_key`::

    github_deploy_key: |
      -----BEGIN RSA PRIVATE KEY-----
      foobar
      -----END RSA PRIVATE KEY-----

There will be more information on the secrets in a later section. You may choose to include the public
SSH key in the repo as well but this is not strictly required.

You also need to set ``project_name`` and ``python_version`` in ``conf/pillar/project.sls``.
Currently we support using Python 2.7 or Python 3.3. The project template is set up for 2.7 by
default. If you want to use 3.3, you will need to change ``python_version`` and make a few changes
to requirements. In ``requirements/base.txt``, you need to change django-compressor to use a forked
version (``-e git://github.com/vkurup/django_compressor.git@develop#egg=django_compressor``). In
``requirements/production.txt``, change python-memcached to python3-memcached. Finally, in
``requirements/dev.txt``, remove Fabric and all its dependencies. Instead you will need Fabric
installed on your laptop "globally" so that when you run ``fab``, it will not be found in your
virtualenv, but will then be found in your global environment.

For the environment you want to setup you will need to set the ``domain`` in
``conf/pillar/<environment>/env.sls``.

You will also need add the developer's user names and SSH keys to ``conf/pillar/devs.sls``. Each
user record should match the format::

    example-user:
      public_key:
       - ssh-rsa <Full SSH Public Key would go here>

Additional developers can be added later, but you will need to create at least one user for
yourself.

The ip for the master needs to be added to the ``conf/pillar/<environment>/minions.yaml`` file.
This file will need to be edited every time you need to make any changes to any of the minions,
e.g: adding a new minion, adding or removing roles for a minion, etc::

  master-minion:
    #FIXME: enter minion ipv4
    ip: <master_ip>


Make sure to use a unique id for each one of the minions.

Finally, in the fabfile the make sure that set::

  env.master = '<ip-of-master>'


Managing Secrets
------------------------

Secret information such as passwords and API keys should never be committed to the
source repository. Instead, each environment manages its secrets in ``conf/pillar/<environment>/secrets.sls``.
These ``secrets.sls`` files are excluded from the source control and need to be passed
to the developers out of band. There are example files given in ``conf/pillar/<environment>/secrets.ex``.
They have the format::

    secrets:
      DB_PASSWORD: XXXXXX

Each key/value pair given in the ``secrets`` dictionary will be added to the OS environment
and can retrieved in the Python code via::

    import os

    password = os.environ['DB_PASSWORD']

Secrets for other environments will not be available. That is, the staging server
will not have access to the production secrets. As such there is no need to namespace the
secrets by their environment.


Environment Variables
------------------------

Other environment variables which need to be configured but aren't secret can be added
to the ``env`` dictionary in ``conf/pillar/<environment>/env.sls``:

  # Additional public environment variables to set for the project
  env:
    FOO: BAR

For instance the default layout expects the cache server to listen at ``127.0.0.1:11211``
but if there is a dedicated cache server this can be changed via ``CACHE_HOST``. Similarly
the ``DB_HOST/DB_PORT`` defaults to ``''/''``::

  env:
    DB_HOST: 10.10.20.2
    CACHE_HOST: 10.10.20.1:11211


Setup Checklist
------------------------

To summarize the steps above, you can use the following checklist

- ``repo`` is set in ``conf/pillar/<environment>/env.sls``
- Developer user names and SSH keys have been added to ``conf/pillar/devs.sls``
- Project name has been set in ``conf/pillar/project.sls``
- Environment domain name has been set in ``conf/pillar/<environment>/env.sls``
- Environment secrets including the deploy key have been set in ``conf/pillar/<environment>/secrets.sls``
- ``ip`` is set in ``conf/pillar/<environment>/minions.yaml``
- ``env.master`` is set in fabfile


Provisioning
------------------------

Each project needs to have at least one Salt Master. There can be one per environment or
a single Master which manages both staging and production. The master is configured with Fabric.
You will need to be able to connect to the server as a root user.
How this is done will depend on where the server is hosted.
VPS providers such as Linode will give you a username/password combination. Amazon's
EC2 uses a private key. These credentials will be passed as command line arguments.::

    # Template of the command
    fab -H <fresh-server-ip> -u <root-user> setup_master
    # Example of provisioning 33.33.33.10 as the Salt Master
    fab -u root setup_servers

This will install salt-master, update the master configuration file, setup all the minions
and do an initial deploy. The master will use a set of base states from
https://github.com/caktus/margarita using the gitfs root.


Provision a Minion
------------------------

To provision a new minion, add roles, or remove roles edit the corresponding minions.yaml file::

  new_minion:
    ip: <master_ip>
    conf:
      master: localhost
      id: <new_id>
      output: mixed
      mine_functions:
        network.interfaces: []
      grains:
        environment: staging
        roles:
          - <new_role>

This step is not required unless you make changes after your initial provisioning.
Note that a single minion can have multiple roles and more can be added with out
having to provision a new one.

After making the changes needed in the minions.yaml file, run the following command::

  fab <environment> setup_server

Optional Configuration
------------------------

The default template contains setup to help manage common configuration needs which
are not enabled by default.


HTTP Auth
________________________

The ``secrets.sls`` can also contain a section to enable HTTP basic authentication. This
is useful for staging environments where you want to limit who can see the site before it
is ready. This will also prevent bots from crawling and indexing the pages. To enable basic
auth simply add a section called ``http_auth`` in the relevant ``conf/pillar/<environment>/secrets.sls``::

    http_auth:
      admin: 123456

This should be a list of key/value pairs. The keys will serve as the usernames and
the values will be the password. As with all password usage please pick a strong
password.


Celery
________________________

Many Django projects make use of `Celery <http://celery.readthedocs.org/en/latest/>`_
for handling long running task outside of request/response cycle. Enabling a worker
makes use of `Django setup for Celery <http://celery.readthedocs.org/en/latest/django/first-steps-with-django.html>`_.
As documented you should create/import your Celery app in ``{{ project_name }}/__init__.py`` so that you
can run the worker via::

    python celery -A {{ project_name }} worker

Additionally you will need to configure the project settings for Celery::

    # {{ project_name }}.settings.staging.py
    import os
    from {{ project_name }}.settings.base import *

    # Other settings would be here
    BROKER_URL = 'amqp://{{ project_name }}_staging:%(BROKER_PASSWORD)s@%(BROKER_HOST)s/{{ project_name }}_staging' % os.environ

You will also need to add the ``BROKER_URL`` to the ``{{ project_name }}.settings.production`` so
that the vhost is set correctly. These are the minimal settings to make Celery work. Refer to the
`Celery documentation <http://docs.celeryproject.org/en/latest/configuration.html>`_ for additional
configuration options.

``BROKER_HOST`` defaults to ``127.0.0.1:5672``. If the queue server is configured on a separate host
that will need to be reflected in the ``BROKER_URL`` setting. This is done by setting the ``BROKER_HOST``
environment variable in the ``env`` dictionary of ``conf/pillar/<environment>/env.sls``.

To add the states you should add the ``worker`` role when provisioning the minion.
At least one server in the stack should be provisioned with the ``queue`` role as well.
This will use RabbitMQ as the broker by default. The
RabbitMQ user will be named {{ project_name }}_<environment> and the vhost will be named {{ project_name }}_<environment>
for each environment. It requires that you add a password for the RabbitMQ user to each of
the ``conf/pillar/<environment>/secrets.sls``::

    secrets:
      BROKER_PASSWORD: thisisapasswordforrabbitmq

The worker will run also run the ``beat`` process which allows for running periodic tasks.
