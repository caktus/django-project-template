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
local development system::

- Python >= 2.7
- `pip <http://www.pip-installer.org/>`_ >= 1.5
- `virtualenv <http://www.virtualenv.org/>`_ >= 1.10
- `virtualenvwrapper <http://pypi.python.org/pypi/virtualenvwrapper>`_ >= 3.0
- Postgres >= 9.3
- git >= 1.7


Getting Started
------------------------

First clone the repository from Github and switch to the new directory::
    
    git clone git@github.com:[ORGANIZATION]/{{ project_name }}.git
    cd {{ project_name }}

To setup your local environment you should create a virtualenv and install the
necessary requirements::

    mkvirtualenv {{ project_name }}
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


Deployment
------------------------

You can deploy changes to a particular environment with
the ``deploy`` command::

    fab staging deploy

New requirements or South migrations are detected by parsing the VCS changes and
will be installed/run automatically.
