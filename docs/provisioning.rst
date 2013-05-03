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

These services are configured to run together on a single machine. Each environment
(``staging`` or ``production``) should run on a separate machine. `Supervisord <http://supervisord.org/>`_
manages the application server process.


Initial Setup
------------------------

Before your project can be deployed to a server, the code needs to be
accessible in a git repository. Once that is done you should update the ``env.repo`` in
the ``fabfile.py``. E.g., change this::

    env.repo = u'' # FIXME: Add repo URL

to this::

    env.repo = u'git@github.com:account/reponame.git'

You also need to set the project name in `conf/pillar/project.sls``. This should
match the ``env.project`` in ``fabfile.py``. For the environment you want to setup
you will need to set the ``domain`` in ``conf/pillar/<environment>/env.sls``.

You will also need add the developer's user names and SSH keys to ``conf/pillar/devs.sls``. Each
user record should match the format::

    example-user:
      groups: [admin, login]
      public_key:
       - ssh-rsa <Full SSH Key would go here>

Additional developers can be added later but you will need to create at least on user for
yourself.


Managing Secrets
------------------------

Secret information such as passwords and API keys should never be committed to the
source repository. Instead aach environment manages is secrets in ``conf/pillar/<environment>/secrets.sls``.
These ``secrets.sls`` files are excluded from the source control and need to be passed
to the developers out of band. There are example files given in ``conf/pillar/<environment>/secrets.ex``.
They have the format::

    secrets:
      DB_PASSWORD: 'XXXXXX'

Each key/value pair given in the ``secrets`` dictionary will be added to the OS environment
and can retrieved in the Python code via::

    import os

    password = os.environ['DB_PASSWORD']

Secrets for other environments will not be available. That is the staging server
will not have access to the production secrets. As such there is no need to namespace the
secrets by their environment.


Setup Checklist
------------------------

To summarize the steps above you can use the following checklist

- ``env.repo`` is set in ``fabfile.py``
- Developer user names and SSH keys have been added to ``conf/pillar/devs.sls``
- Project name has been in ``conf/pillar/project.sls``
- Environment domain name has been set in ``conf/pillar/<environment>/env.sls``
- Environment secrets have been set in ``conf/pillar/<environment>/secrets.sls``


Provision
------------------------

Once you have completed the above steps you are ready to provision a new server
for a given environment. You will need to be able to connect to the server
as a root user. How this is done will depend on where the server is hosted.
VPS providers such as Linode will give you a username/password combination. Amazon's
EC2 uses a private key. These credentials will be passed as command line arguments.::

    # Template of the command
    fab -H <fresh-server-ip> -u <root-user> <environment> provision
    # Example of provisioning 33.33.33.10 as a staging machine
    fab -H 33.33.33.10 -u root staging provision

Behind the scenes this will rsync the states/pillars in ``conf`` over to the
server as well as check out the base states from the `margarita <https://github.com/caktus/margarita>`_
repo. It will then use the `masterless salt-minion <http://docs.saltstack.com/topics/tutorials/quickstart.html>`_
to ensure the states are up to date.

Note that because of the use of rsync it is possible to execute configuration changes which
have not yet been committed to the repo. This can be handy for testing configuration
changes and allows for the secrets to be excluded from the repo but it's a double-edged sword.
You should be sure to commit any configuration changes to the repo when they are ready.

Once a server has been created for its environment it should be added to the ``env.hosts``
for the given environment. In our example we would add::

    def staging():
        env.environment = 'staging'
        env.hosts = ['33.33.33.10', ]

At this point we can run the first deploy::

    fab staging deploy

This will do the initial checkout of the repo source, install the Python requirements,
run syncdb/migrate and collect the static resources.


Updates
------------------------

During the life of the project you will likely need to make updates to the server
configuration. This might include new secrets add to the pillar, new developers
added to the project or new services which need to be installed. Configuration updates
can be made by calling the ``provision`` command again.::

    # Template of the command
    fab <environment> provision
    # Reprovision the staging server
    fab staging provision

In this case we do not need to connect as the root user. We connect as our developer
user. We also do not need to specify the host. It will use the ``env.hosts`` previously
set for this environment.

For more information testing the provisioning see the doc:`vagrant guide </vagrant>`.