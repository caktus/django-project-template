{% if False %}
Installation
------------

To start a new project with this template::

    django-admin.py startproject \
      --template=https://github.com/caktus/django-project-template/zipball/master \
      --extension=py,rst,yml \
      --name=Makefile,gulpfile.js,package.json \
      <project_name>

{% endif %}
{{ project_name|title }}
========================

Below you will find basic setup and deployment instructions for the {{ project_name }}
project. To begin you should have the following applications installed on your
local development system:

- Python >= 3.5
- NodeJS >= 4.2
- npm >= 2.14.7
- `pip <http://www.pip-installer.org/>`_ >= 1.5
- `virtualenv <http://www.virtualenv.org/>`_ >= 1.10
- `virtualenvwrapper <http://pypi.python.org/pypi/virtualenvwrapper>`_ >= 3.0
- Postgres >= 9.3
- git >= 1.7

A note on NodeJS 4.2 for Ubuntu users: this LTS release may not be available through the
Ubuntu repository, but you can configure a PPA from which it may be installed::

    curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
    sudo apt-get install -y nodejs

You may also follow the manual instructions if you wish to configure the PPA yourself:

    https://github.com/nodesource/distributions#manual-installation

Getting Started
------------------------

First clone the repository from Github and switch to the new directory::

    $ git clone git@github.com:[ORGANIZATION]/{{ project_name }}.git
    $ cd {{ project_name }}

To setup your local environment you can use the quickstart make target `setup`, which will
install both Python and Javascript dependencies (via pip and npm) into a virtualenv named
"{{ project_name }}", configure a local django settings file, and create a database via
Postgres named "{{ project_name }}" with all migrations run::

    $ make setup
    $ workon {{ project_name }}

If you require a non-standard setup, you can walk through the manual setup steps below making
adjustments as necessary to your needs.

To setup your local environment you should create a virtualenv and install the
necessary requirements::

    # Check that you have python3.5 installed
    $ which python3.5
    $ mkvirtualenv {{ project_name }} -p `which python3.5`
    ({{ project_name }})$ pip install -r requirements/dev.txt
    ({{ project_name }})$ npm install

Next, we'll set up our local environment variables. We use `django-dotenv
<https://github.com/jpadilla/django-dotenv>`_ to help with this. It reads environment variables
located in a file name ``.env`` in the top level directory of the project. The only variable we need
to start is ``DJANGO_SETTINGS_MODULE``::

    ({{ project_name }})$ cp {{ project_name }}/settings/local.example.py {{ project_name }}/settings/local.py
    ({{ project_name }})$ echo "DJANGO_SETTINGS_MODULE={{ project_name }}.settings.local" > .env

Create the Postgres database and run the initial migrate::

    ({{ project_name }})$ createdb -E UTF-8 {{ project_name }}
    ({{ project_name }})$ python manage.py migrate

If you want to use `Travis <http://travis-ci.org>`_ to test your project,
rename ``project.travis.yml`` to ``.travis.yml``, overwriting the ``.travis.yml``
that currently exists.  (That one is for testing the template itself.)::

    ({{ project_name }})$ mv project.travis.yml .travis.yml

Development
-----------

You should be able to run the development server via the configured `dev` script::

    ({{ project_name }})$ npm run dev

Or, on a custom port and address::

    ({{ project_name }})$ npm run dev -- --address=0.0.0.0 --port=8020

Any changes made to Python, Javascript or Less files will be detected and rebuilt transparently as
long as the development server is running.


Deployment
----------

The deployment of requires Fabric but Fabric does not yet support Python 3. You
must either create a new virtualenv for the deployment::

    # Create a new virtualenv for the deployment
    $ mkvirtualenv {{ project_name }}-deploy -p `which python2.7`
    ({{ project_name }}-deploy)$ pip install -r requirements/deploy.txt

or install the deploy requirements
globally::

    $ sudo pip install -r requirements/deploy.txt


You can deploy changes to a particular environment with
the ``deploy`` command::

    $ fab staging deploy

New requirements or migrations are detected by parsing the VCS changes and
will be installed/run automatically.
