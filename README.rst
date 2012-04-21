{{ project_name|title }}
========================

Getting Started
------------------------

To setup you local environment you should create a virtualenv and install the
necessary requirements::

    mkvirtualenv {{ project_name }} --distribute
    $VIRTUAL_ENV/bin/pip install -r $PWD/requirements/dev.txt

Then create a local settings file and set your ``DJANGO_SETTINGS_MODULE`` to use it::

    cp {{ project_name }}/settings/local.example.py {{ project_name }}/settings/local.py
    echo "export DJANGO_SETTINGS_MODULE={{ project_name }}.settings.local" >> $VIRTUAL_ENV/bin/postactivate
    echo "unset DJANGO_SETTINGS_MODULE" >> $VIRTUAL_ENV/bin/postdeactivate

Create the Postgres database and run the initial syncdb/migrate::

    createdb {{ project_name }}
    python manage.py syncdb
    python manage.py migrate

You should now be able to run the development server::

    python manage.py runserver
