{% if False %}
Installation
------------

To start a new project with this template::

    django-admin.py startproject --template=https://github.com/caktus/django-project-template/zipball/master --extension=py,rst <project_name>

{% endif %}

{{ project_name|title }}
========================

Below you will find basic setup and deployment instructions for the {{ project_name }}
project. To begin you should have the following applications installed on your
local development system:

- Python >= 3.4
- `pip <http://www.pip-installer.org/>`_ >= 1.5
- `virtualenv <http://www.virtualenv.org/>`_ >= 1.10
- `virtualenvwrapper <http://pypi.python.org/pypi/virtualenvwrapper>`_ >= 3.0
- Postgres >= 9.3
- git >= 1.7


Getting Started
------------------------

First clone the repository from Github and switch to the new directory::

    $ git clone git@github.com:[ORGANIZATION]/{{ project_name }}.git
    $ cd {{ project_name }}

To setup your local environment you should create a virtualenv and install the
necessary requirements::

    # Check that you have python3.4 installed
    $ which python3.4
    $ mkvirtualenv {{ project_name }} -p `which python3.4`
    ({{ project_name }})$ $VIRTUAL_ENV/bin/pip install -r $PWD/requirements/dev.txt

Then create a local settings file and set your ``DJANGO_SETTINGS_MODULE`` to use it::

    ({{ project_name }})$ cp {{ project_name }}/settings/local.example.py {{ project_name }}/settings/local.py
    ({{ project_name }})$ echo "export DJANGO_SETTINGS_MODULE={{ project_name }}.settings.local" >> $VIRTUAL_ENV/bin/postactivate
    ({{ project_name }})$ echo "unset DJANGO_SETTINGS_MODULE" >> $VIRTUAL_ENV/bin/postdeactivate

Exit the virtualenv and reactivate it to activate the settings just changed::

    ({{ project_name }})$ deactivate
    $ workon {{ project_name }}

Create the Postgres database and run the initial migrate::

    ({{ project_name }})$ createdb -E UTF-8 {{ project_name }}
    ({{ project_name }})$ python manage.py migrate

You should now be able to run the development server::

    ({{ project_name }})$ python manage.py runserver


Deployment
------------------------

The deployment of requires Fabric but Fabric does not yet support Python 3. You
must either create a new virtualenv for the deployment::

    # Create a new virtualenv for the deployment
    $ mkvirtualenv {{ project_name }}-deploy -p `which python2.7`
    ({{ project_name }}-deploy)$ pip install -r requirements/deploy.txt

or install the deploy requirements
globally.::

    $ sudo pip install -r requirements/deploy.txt


You can deploy changes to a particular environment with
the ``deploy`` command::

    $ fab staging deploy

New requirements or South migrations are detected by parsing the VCS changes and
will be installed/run automatically.
