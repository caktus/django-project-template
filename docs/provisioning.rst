Server Provisioning
========================


Overview
------------------------

{{ project_name|title }} is deployed on the following stack.

- OS: Ubuntu 14.04 LTS
- Python: 3.4
- Database: Postgres 9.3
- Application Server: Gunicorn
- Frontend Server: Nginx
- Cache: Memcached

These services can configured to run together on a single machine or on different machines.
`Supervisord <http://supervisord.org/>`_ manages the application server process.


Salt Master
------------------------

Each project needs a Salt Master per environment (staging, production, etc).
The master is configured with Fabric. ``env.master`` should be set to the IP
of this server in the environment where it will be used::

    @task
    def staging():
        ...
        env.master = <ip-of-master>

You will need to be able to connect to the server as a root user.
How this is done will depend on where the server is hosted.
VPS providers such as Linode will give you a username/password combination. Amazon's
EC2 uses a private key. These credentials will be passed as command line arguments.::

    # Template of the command
    fab -u <root-user> <environment> setup_master
    # Example of provisioning a Linode VM for staging
    fab -u root staging setup_master
    # Example of provisioning an AWS VM for production
    fab -u ubuntu production setup_master -i aws-private.pem

This will install salt-master and update the master configuration file. The master will use a
set of base states from https://github.com/caktus/margarita checked out
at ``/srv/margarita``.

As part of the master setup, a new GPG public/private key pair is generated. The private
key remains on the master but the public version is exported and fetched back to the
developer's machine. This will be put in ``conf/<environment>.pub.gpg``. This will
be used by all developers to encrypt secrets for the environment and needs to be
committed into the repo.


Pillar Setup
------------------------

Before your project can be deployed to a server, the code needs to be
accessible in a git repository. Once that is done you should update
``conf/pillar/<environment>.sls`` to set the repo and branch for the environment.
E.g., change this::

    # FIXME: Update to the correct project repo
    repo:
      url: git@github.com:CHANGEME/CHANGEME.git
      branch: master

to this::

    repo:
      url: git@github.com:account/reponame.git
      branch: master

You also need to set ``project_name`` and ``python_version`` in ``conf/pillar/project.sls``.
The project template is set up for 3.4 by default. If you want to use 2.7, you will need to change ``python_version`` and make a few changes to requirements. In ``requirements/production.txt``, change python3-memcached to python-memcached.

For the environment you want to setup you will need to set the ``domain`` in
``conf/pillar/<environment>.sls``.

You will also need add the developer's user names and SSH keys to ``conf/pillar/devs.sls``. Each
user record (under the parent ``users:`` key) should match the format::

    example-user:
      public_key:
       - ssh-rsa <Full SSH Public Key would go here>

Additional developers can be added later, but you will need to create at least one user for
yourself.


Managing Secrets
------------------------

Secret information such as passwords and API keys must be encrypted before being added
to the pillar files. As previously noted, provisioning the master for the environment
generates a public GPG key which is added to repo under ``conf/<environment>.pub.gpg``
To encrypt a new secret using this key, you can use the ``encrypt`` fab command::

    # Example command
    fab <environment> encrypt:<key>=<secret-value>
    # Encrypt the SECRET_KEY for the staging environment
    fab staging encrypt:SECRET_KEY='thisismysecretkey'

The output of this command will look something like::

    "SECRET_KEY": |-
      -----BEGIN PGP MESSAGE-----
      Version: GnuPG v1.4.11 (GNU/Linux)

      hQEMA87BIemwflZuAQf/XDTq6pdZsS07zw88lvGcWbcy5pj5CLueVldE+NLAHilv
      YaFb1qPM1W+yrnxFQgsapcHUM82ULkXbMskYoK5qp5Or2ujwzAVRpbSrFTq19Frz
      sasFTPNNREgThLB8oyQIHN2XfqSvIqi6RkqXGf+eQDXLyl9Guu+7EhFtW5PJRo3i
      BSBVEuMi4Du60uAssQswNuit7lkEqxFprZDb9aHmjVBi+DAipmBuJ+FIyK0ePFAf
      dVfp/Es/y4/hWkM7TXDw5JMFtVfCo6Dm1LE53N339eJX01w19exB/Sek6HVwDsL4
      d45c1dm7qBiXN0zO8Yadhm520J0H9NcIPO47KyRkCtJAARsY5eu8cHxYW4DcYWLu
      PRr2CLuI8At1Q2KqlRgdEm17lV5HOEcMoT1SyvMzaWOnbpul5PoLCAebJ0zcJZT5
      Pw==
      =V1Uh
      -----END PGP MESSAGE-----

where ``SECRET_KEY`` would be replace with the key you were trying to encrypt. This
block of text should be added to the environment pillar ``conf/pillar/<environment>.sls``
under the ``secrets`` block::

    secrets:
      "SECRET_KEY": |-
        -----BEGIN PGP MESSAGE-----
        Version: GnuPG v1.4.11 (GNU/Linux)

        hQEMA87BIemwflZuAQf/XDTq6pdZsS07zw88lvGcWbcy5pj5CLueVldE+NLAHilv
        YaFb1qPM1W+yrnxFQgsapcHUM82ULkXbMskYoK5qp5Or2ujwzAVRpbSrFTq19Frz
        sasFTPNNREgThLB8oyQIHN2XfqSvIqi6RkqXGf+eQDXLyl9Guu+7EhFtW5PJRo3i
        BSBVEuMi4Du60uAssQswNuit7lkEqxFprZDb9aHmjVBi+DAipmBuJ+FIyK0ePFAf
        dVfp/Es/y4/hWkM7TXDw5JMFtVfCo6Dm1LE53N339eJX01w19exB/Sek6HVwDsL4
        d45c1dm7qBiXN0zO8Yadhm520J0H9NcIPO47KyRkCtJAARsY5eu8cHxYW4DcYWLu
        PRr2CLuI8At1Q2KqlRgdEm17lV5HOEcMoT1SyvMzaWOnbpul5PoLCAebJ0zcJZT5
        Pw==
        =V1Uh
        -----END PGP MESSAGE-----

The ``Makefile`` has a make command for generating a random secret. By default
this is 32 characters long but can be adjusted using the ``length`` argument.::

    make generate-secret
    make generate-secret length=64

This can be combined with the above encryption command to generate a random
secret and immediately encrypt it.::

    fab staging encrypt:SECRET_KEY=`make generate-secret length=64`

By default the project will use the ``SECRET_KEY`` if it is set. You can also
optionally set a ``DB_PASSWORD``. If not set, you can only connect to the database
server on localhost so this will only work for single server setups.


Github Deploy Keys
------------------------

The repo will also need a deployment key generated so that the Salt minion can
access the repository. You can generate a deployment key locally for the new
server like so::

    # Example command
    make <environment>-deploy-key
    # Generating the staging deploy key
    make staging-deploy-key

This will generate two files named ``<environment>.priv`` and ``conf/<environment>.pub.ssh``.
The first file contains the private key and the second file contains the public
key. The public key needs to be added to the "Deploy keys" in the GitHub repository.
For more information, see the Github docs on managing deploy keys:
https://help.github.com/articles/managing-deploy-keys

The text in the private key file should be added to `conf/pillar/<environment>.sls``
under the label `github_deploy_key` but it must be encrypted first. To encrypt
the file you can use the same ``encrypt`` fab command as before passing the filename
rather than a key/value pair::

    fab staging encrypt:staging.priv

This will create a new file with appends ``.asc`` to the end of the original filename
(i.e. staging.priv.asc). The entire contents of this file should be added to the
``github_deploy_key`` section of the pillar file.::

    github_deploy_key: |
      -----BEGIN PGP MESSAGE-----
      Version: GnuPG v1.4.11 (GNU/Linux)

      hQEMA87BIemwflZuAQf/RW2bXuUpg5QuwuY9dLqLpdpKz+/971FHqM1Kz5NXgJHo
      hir8yh/wxlKlMbSpiyri6QPigj8DZLrGLi+VTwWCXJ
      ...
      -----END PGP MESSAGE-----

Do not commit the original ``*.priv`` files into the repo.


Environment Variables
------------------------

Other environment variables which need to be configured but aren't secret can be added
to the ``env`` dictionary in ``conf/pillar/<environment>.sls`` without encryption.

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

- ``repo`` is set in ``conf/pillar/<environment>.sls``
- Developer user names and SSH keys have been added to ``conf/pillar/devs.sls``
- Project name has been set in ``conf/pillar/project.sls``
- Environment domain name has been set in ``conf/pillar/<environment>.sls``
- Environment secrets including the deploy key have been set in ``conf/pillar/<environment>.sls``


Provision a Minion
------------------------

Once you have completed the above steps, you are ready to provision a new server
for a given environment. Again you will need to be able to connect to the server
as a root user. This is to install the Salt Minion which will connect to the Master
to complete the provisioning. To setup a minion you call the Fabric command::

    fab <environment> setup_minion:<roles> -H <ip-of-new-server> -u <root-user>
    fab staging setup_minion:web,balancer,db-master,cache -H  33.33.33.10 -u root

The available roles are ``salt-master``, ``web``, ``worker``, ``balancer``, ``db-master``,
``queue`` and ``cache``. If you are running everything on a single server you need to enable
the ``salt-master``, ``web``, ``balancer``, ``db-master``, and ``cache`` roles. The ``worker``
and ``queue`` roles are only needed to run Celery which is explained in more detail later.

Additional roles can be added later to a server via ``add_role``. Note that there is no
corresponding ``delete_role`` command because deleting a role does not disable the services or
remove the configuration files of the deleted role::

    fab add_role:web -H  33.33.33.10

After that you can run the deploy/highstate to provision the new server::

    fab <environment> deploy -u <root-user>

The first time you run this command, it may complete before the server is set up.
It is most likely still completing in the background. If the server does not become
accessible or if you encounter errors during the process, review the Salt logs for
any hints in ``/var/log/salt`` on the minion and/or master. For more information about
deployment, see the `server setup </server-setup>` documentation.

The initial deployment will create developer users for the server so you should not
need to connect as root after the first deploy.


Optional Configuration
------------------------

The default template contains setup to help manage common configuration needs which
are not enabled by default.


HTTP Auth
________________________

The ``<environment>.sls`` can also contain a section to enable HTTP basic authentication. This
is useful for staging environments where you want to limit who can see the site before it
is ready. This will also prevent bots from crawling and indexing the pages. To enable basic
auth simply add a section called ``http_auth`` in the relevant ``conf/pillar/<environment>.sls``.
As with other passwords this should be encrypted before it is added::

    # Example encryption
    fab <environment> encrypt:<username>=<password>
    # Encrypt admin/abc123 for the staging environment
    fab staging encrypt:admin=abc123

This would be added in ``conf/pillar/<environment>.sls`` under ``http_auth``:

    http_auth:
      "admin": |-
        -----BEGIN PGP MESSAGE-----
        Version: GnuPG v1.4.11 (GNU/Linux)

        hQEMA87BIemwflZuAQf+J4+G74ZSfrUPRF7z7+DPAmhBlK//A6dvplrsY2RsfEE4
        Tfp7QPrHZc5V/gS3FXvlIGWzJOEFscKslzgzlccCHqsNUKE96qqnTNjsIoGOBZ4z
        tmZV2F3AXzOVv4bOgipKIrjJDQcFJFjZKMAXa4spOAUp4cyIV/AQBu0Gwe9EUkfp
        yXD+C/qTB0pCdAv5C4vyl+TJ5RE4fGnuPsOqzy4Q0mv+EkXf6EHL1HUywm3UhUaa
        wbFdS7zUGrdU1BbJNuVAJTVnxAoM+AhNegLK9yAVDweWK6pApz3jN6YKfVLFWg1R
        +miQe9hxGa2C/9X9+7gxeUagqPeOU3uX7pbUtJldwdJBAY++dkerVIihlbyWOkn4
        0HYlzMI27ezJ9WcOV4ywTWwOE2+8dwMXE1bWlMCC9WAl8VkDDYup2FNzmYX87Kl4
        9EY=
        =PrGi
        -----END PGP MESSAGE-----

This should be a list of key/value pairs. The keys will serve as the usernames and
the values will be the password. As with all password usage please pick a strong
password.


Celery
________________________

Many Django projects make use of `Celery <http://celery.readthedocs.org/en/latest/>`_ for handling
long running tasks outside of the request/response cycle. Enabling a worker makes use of `Django
setup for Celery <http://celery.readthedocs.org/en/latest/django/first-steps-with-django.html>`_. As
documented on that page, you need to create a new file in ``{{ project_name }}/celery.py`` and then
modify ``{{ project_name }}/__init__.py`` to import that file. You'll also need to customize ``{{
project_name}}/celery.py`` to import the environment variables from ``.env``. Add this (before the
``os.environ.setdefault`` call)::

    from . import load_env  # noqa

You should now be able to run the worker locally via (once you've added ``celery`` to your
``requirements/base.txt`` and installed it)::

    celery -A {{ project_name }} worker

Additionally you will need to uncomment the ``BROKER_URL`` setting in the project settings::

    # {{ project_name }}/settings/deploy.py
    from .base import *

    # ...
    BROKER_URL = 'amqp://{{ project_name }}_%(ENVIRONMENT)s:%(BROKER_PASSWORD)s@%(BROKER_HOST)s/{{ project_name }}_%(ENVIRONMENT)s' % os.environ

These are the minimal settings to make Celery work. Refer to the `Celery documentation
<http://docs.celeryproject.org/en/latest/configuration.html>`_ for additional configuration options.

``BROKER_HOST`` defaults to ``127.0.0.1:5672``. If the queue server is configured on a separate host
that will need to be reflected in the ``BROKER_URL`` setting. This is done by setting the ``BROKER_HOST``
environment variable in the ``env`` dictionary of ``conf/pillar/<environment>.sls``.

To add the states you should add the ``worker`` role when provisioning the minion. At least one
server in the stack should be provisioned with the ``queue`` role as well. This will use RabbitMQ as
the broker by default. The RabbitMQ user will be named ``{{ project_name }}_<environment>`` and the
vhost will be named ``{{ project_name }}_<environment>`` for each environment. It requires that you
add a password for the RabbitMQ user to each of the ``conf/pillar/<environment>.sls`` under the
secrets using the key ``BROKER_PASSWORD``. As with all secrets this must be encrypted.

The worker will run also run the ``beat`` process which allows for running periodic tasks.


SSL
________________________

The default configuration expects the site to run under HTTPS everywhere. However, unless
an SSL certificate is provided, the site will use a self-signed certificate. To include
a certificate signed by a CA you must update the ``ssl_key`` and ``ssl_cert`` pillars
in the environment secrets. The ``ssl_cert`` should contain the intermediate certificates
provided by the CA. It is recommended that this pillar is only pushed to servers
using the ``balancer`` role. See the ``secrets.ex`` file for an example.

You can use the below OpenSSL commands to generate the key and signing request::

  # Generate a new 2048 bit RSA key
  openssl genrsa -out {{ project_name }}.key 2048
  # Make copy of the key with the passphrase
  cp {{ project_name }}.key {{ project_name }}.key.secure
  # Remove any passphrase
  openssl rsa -in {{ project_name }}.secure -out {{ project_name }}.key
  # Generate signing request
  openssl req -nodes -sha256 -new -key {{ project_name }}.key -out {{ project_name }}.csr

The last command will prompt you for information for the signing request including
the organization for which the request is being made, the location (country, city, state),
email, etc. The most important field in this request is the common name which must
match the domain for which the certificate is going to be deployed (i.e example.com).

This signing request (.csr) will be handed off to a trusted Certificate Authority (CA) such as
StartSSL, NameCheap, GoDaddy, etc. to purchase the signed certificate. The contents of
the *.key file will be added to the ``ssl_key`` pillar and the signed certificate
from the CA will be added to the ``ssl_cert`` pillar. These should be encrypted using
the same proceedure as with the private SSH deploy key.
