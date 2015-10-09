Server Provisioning
========================

This is documentation for deploying the project using Ansible.

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

Project data
------------

Define project-specific data (like the project name) as variables
in the file ``inventory/group_vars/all``. Any variable defined in that
file will be available to Ansible everywhere.

Define environment-specific data (like the site's domain name)
in the file ``inventory/group_vars/<env_name>``.

FIXME: Document what variables can be/must be set in the different
variables files.

Ansible
-------

Ansible is used to provision and deploy to the remote servers, with help
from the tequila project.

To get set up for deploys::

    $ mkvirtualenv -p /usr/bin/python2.7 {{ project_name }}_deploy
    $ pip install -r requirements/ansible.txt

Note that so far, Ansible doesn't support Python 3, so you'll need a separate
virtualenv for deploying with Ansible than you use for developing the project
and running it locally.

Then you can run a deploy with::

    $ deploy staging
    $ deploy production
    $ deploy vagrant

``staging``, ``production``, etc. are what we're calling `environments`.

To change the servers in an environment or their roles, edit the file
``inventory/<envname>``, which is in
`Ansible inventory file format <http://docs.ansible.com/ansible/intro_inventory.html>`_.

Just don't put any secrets (like passwords) in the inventory files.
See below for how to handle secrets.

The First Deploy
----------------

The first deploy to a new system is typically a little different from subsequent
deploys because you don't have a user account on the new system yet.

For now, manually edit ``inventory/<envname>`` and add a setting ``ansible_ssh_user``
to the host linefor the new system, specifying the user that you can ssh in as and use
sudo from. You might need to also specify the SSH key.

E.g.::

    # For new AWS EC2 Ubuntu systems
    hostname ansible_ssh_user=ubuntu ansible_ssh_private_key_file=xxxxxxxxxxxxxx

    # For misc. systems
    hostname ansible_ssh_user=root

For vagrant, the default vagrant file has some settings that might work as-is,
or you might need to tweak the port.

Managing Secrets
------------------------

Secret information such as passwords and API keys must be encrypted. We use
`Ansible Vault <https://docs.ansible.com/ansible/playbooks_vault.html>`_.

Each environment has a secrets file at
``inventory/secrets/envname`` that is encrypted and checked into git.

When setting up a new project, generate a secure random password, save it securely
somewhere like Lastpass, and share it
among the team. Each team member should create a ``.vaultpassword`` file at
the root of their project checkout and put the password in it.

*NEVER* check the ``.vaultpassword`` file into git.

The deploy script will use that file to pass the password to ansible
during deploys, but when you're working with the secrets file, you'll need
to specify it yourself::

    $ ansible-vault create --vault-password-file .vaultpassword inventory/secrets/<envname>
    $ ansible-vault edit --vault-password-file .vaultpassword inventory/secrets/<envname>

See the `Vault documentation <http://docs.ansible.com/ansible/playbooks_vault.html>`_
for more about working with vault files.

Environment Variables
------------------------

Other environment variables which need to be configured but aren't secret can be added
to the ``env`` dictionary in any of the variable files without encryption.

FIXME: Is that true? or will having ``env`` in multiple files break things?

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

- ``repo`` is set in ``inventory/group_vars/<envname>``
- Developer user names and SSH keys have been added to ``inventory/group_vars/all``
  as ``users``
  if you want the developers to have access in all environments, or else in
  ``inventory/group_vars/<envname>`` for each environment.
- Project name has been set in ``inventory/group_vars/all``
- Environment domain name has been set as ``domain`` in ``inventory/group_vars/<envname>``
- Environment secrets including the deploy key have been set in ``inventory/secrets/<environment>.yml``

Optional Configuration
------------------------

The default template contains setup to help manage common configuration needs which
are not enabled by default.

FIXME: UPDATE THIS PART:


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

    from . import load_env
    load_env.load_env()

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
