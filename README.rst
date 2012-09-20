{% if False %}
Installation
------------

To start a new project with this template::

    django-admin.py startproject --template=https://github.com/caktus/django-project-template/zipball/master --extension=py,rst <project_name>

{% endif %}

{{ project_name|title }}
========================


Getting Started
------------------------

To setup your local environment you should create a virtualenv and install the
necessary requirements::

    mkvirtualenv --distribute {{ project_name }}
    $VIRTUAL_ENV/bin/pip install -r $PWD/requirements/dev.txt

Then create a local settings file and set your ``DJANGO_SETTINGS_MODULE`` to use it::

    cp {{ project_name }}/settings/local.example.py {{ project_name }}/settings/local.py
    echo "export DJANGO_SETTINGS_MODULE={{ project_name }}.settings.local" >> $VIRTUAL_ENV/bin/postactivate
    echo "unset DJANGO_SETTINGS_MODULE" >> $VIRTUAL_ENV/bin/postdeactivate

Exit the virtualenv and reactivate it to activate the settings just changed::

    deactivate
    workon {{ project_name }}

Create the Postgres database and run the initial syncdb/migrate::

    createdb -E UTF-8 {{ project_name }}
    python manage.py syncdb
    python manage.py migrate

You should now be able to run the development server::

    python manage.py runserver


Server Provisioning
------------------------

The first step in creating a new server is to create users on the remote server. You
will need root user access with passwordless sudo. How you specify this user will vary
based on the hosting provider. EC2 and Vagrant use a private key file. Rackspace and
Linode use a user/password combination. 

1. For each developer, put a file in the ``conf/users`` directory
containing their public ssh key, and named exactly the same as the
user to create on the server. (E.g. for user "dickens", the filename
must be "dickens", not "dickens.pub" or "user_dickens".)

1. Run this command to create users on the server::

    fab -H <fresh-server-ip> -u <root-user> create_users

This will create a project user and users for all the developers. 

1. Lock down SSH connections: disable password login and move
the default port from 22 to ``env.ssh_port``::

    fab -H <fresh-server-ip> configure_ssh

1. Add the IP to the appropriate environment
function and provision it for its role. You can provision a new server with the
``setup_server`` fab command. It takes a list of roles for this server
('app', 'db', 'lb') or you can say 'all'::

    fab staging setup_server:all


Vagrant Testing
------------------------

You can test the provisioning/deployment using `Vagrant <http://vagrantup.com/>`_.
Using the Vagrantfile you can start up the VM. This requires the ``lucid32`` box::

    vagrant up

With the VM up and running, you can create the necessary users.
Put the developers' keys in ``conf/users`` as before, then
use these commands to create the users. The location of the key file
(/usr/lib/ruby/gems/1.8/gems/vagrant-1.0.2/keys/vagrant)
may vary on your system.  Running ``locate keys/vagrant`` might
help find it::

    fab -H 33.33.33.10 -u vagrant -i /usr/lib/ruby/gems/1.8/gems/vagrant-1.0.2/keys/vagrant create_users
    fab vagrant setup_server:all
    fab vagrant deploy

It is not necessary to reconfigure the SSH settings on the vagrant box.

The vagrant box forwards
port 80 in the VM to port 8080 on the host box. You can view the site
by visiting localhost:8080 in your browser.

You may also want to add::

    33.33.33.10 dev.example.com

to your hosts (/etc/hosts) file.

You can stop the VM with ``vagrant halt`` and
destroy the box completely to retest the provisioning with ``vagrant destroy``.

For more information please review the Vagrant documentation.


Deployment
------------------------

For future deployments, you can deploy changes to a particular environment with
the ``deploy`` command. This takes an optional branch name to deploy. If the branch
is not given, it will use the default branch defined for this environment in
``env.branch``::

    fab staging deploy
    fab staging deploy:new-feature

New requirements or South migrations are detected by parsing the VCS changes and
will be installed/run automatically.
