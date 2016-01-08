Project Template Updates
========================

These are notes related to recent changes to our Django project template. Please read to be aware of
these changes and how it may impact your project either now or in the future.

Motivation for the Changes
--------------------------

A new Salt version 2015.5 was released with some deprecations as well as backwards incompatible
changes. The project template has also been slow to adapt to changes needed for Ubuntu 14.04. Recent
deployment failures also pointed to a need for more control and stability around the versions of
Salt and the related states used to provision our servers.

What Changed
------------

Postgres
~~~~~~~~
Related to Ubuntu updates, we've made Postgres 9.3 the default version. This is the version which
comes with Ubuntu 14.04. It is configurable with the ``postgres_version`` pillar. If you are using an
older version of Ubuntu/Postgres you should set this to the version you are currently using.
Changing this version will install new packages but it won't magically migrate data for you.

Prior to 14.04 and Postgres 9.3, there was an issue with the default server encoding being ASCII
rather than UTF-8. As part of the initial database provisioning, we were dropping the cluster and
rebuilding as UTF-8. This is a potentially dangerous operation if there is existing data in the
cluster. As such we've removed that state and references to it in your project should be removed.

NodeJS
~~~~~~
We've also updated how NodeJS/NPM is installed. These were previously using the Ubuntu packages,
which previously kept up to date but fell behind when NodeJS released multiple major versions in
quick succession, including integration of newer NPM releases.

Nginx
~~~~~
The Nginx states for margarita now install Nginx from the stable PPA meaning that we can use a more
recent Nginx version. There are security as well as logging improvements which we need/want from
more recent versions and this is the first step in getting access to them.

Salt
~~~~
Related to the stability and repeatability of our deployment process, we've changed both how we
install Salt and how we install/update margarita, the base set of states for our deployment. The
commands for setting up a master/minion are the same but behind the scenes they install Salt from a
particular git tag rather than the latest from the PPA. This give us more control on the version
used so that we can get faster access to bug fixes or work around bad versions. It also ensures that
we can have the same versions running in production and staging, and that we can test upgrades prior
to hitting production. The version of Salt installed is controlled by ``SALT_VERSION`` string in the
fabfile.

Margarita
~~~~~~~~~
https://github.com/caktus/margarita is our set of common Salt states. Prior to our recent changes,
all projects were set to use the latest master on every deploy. This made changing/updating states
difficult since a project may use different Salt or Ubuntu versions. This was also using Salt's
built-in GitFS which was proving unreliable on a number of projects. We are now checking out a
particular tag of margarita on the salt-master allowing projects to stick with a known good version
of margarita for the lifetime of the project and upgrade as needed. This will allow us to clean up
and improve margarita without fear of breaking projects, while also providing a versioned upgrade
path for projects.

Going along with that change, we have also moved all the states from the project template to
margarita. The only remaining state in the project template is the state which loads the margarita
states. We still copy any states in the project template to the salt-master and the salt-master will
use those states before looking at margarita states, so projects can still override or augment
margarita states, if desired.

NewRelic
~~~~~~~~
We've added simpler support for NewRelic, documented in the margarita README.

Dotenv
~~~~~~
We started using a project called ``django-dotenv`` which allows environment variables to be set in a
``.env`` file in the project root, and then be loaded by whichever processes need it (manage.py,
wsgi.py, celery.py, etc.).

All of these changes (and any future changes) are documented in ``CHANGES.rst`` in the margarita repo.

How To Update a Project
-----------------------

What needs to be done to update your project to the latest version of margarita? It depends on how
old your project is. Note that there is no reliable automatic way to get upgraded, so test these
procedures on Vagrant and ask for help liberally!

If you are on margarita >= 1.0.4
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You should be able to update ``margarita_version`` to the latest version and follow any
deprecation/upgrade notes in margarita's CHANGES.rst file. At the time of this writing, you'd need
to do the following:

* find any locations in your codebase where you were using ``ALLOWED_HOSTS`` from the environment and
  change it to use ``DOMAIN`` instead.
* Install ``django-dotenv`` and add code to manage.py, wsgi.py and celery.py to load it

After accomplishing those those things, you should be able to deploy and you're all set.

If you are on margarita > 1.0.0 but < 1.0.4
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Your project template contains many states which have now been moved to the margarita repo. Follow
the directions above, but you'll also have to do a couple more steps. At a minimum, you need to:

* Remove ``conf/salt/project/venv.sls``. This contains a state ``python-pkgs`` which conflicts with a
  margarita state. Normally the project template would override margarita, but in this case, the
  statefile also specifically loads the ``python`` state, which resides in margarita and contains
  the conflicting state, so salt sees both states and complains.

At this point, you *should* be able to deploy successfully. I say "should" because it is possible
that you have added states to your repo which happen to conflict with what's in margarita. If so,
salt should complain that data 'failed to compile'. This error occurs before any changes are made to
the server, so shouldn't cause any problems. You'll then need to read the error message, figure out
which states are conflicting and (probably) remove yours so that the margarita ones are used
instead.

If that is all successful, you still have some work to do. You are on the latest margarita, but are
not really using all of it yet, because your states are overriding the margarita ones. If you
haven't made any significant changes, you should be able to delete everything in your ``conf/salt``
directory except for ``top.sls`` and ``margarita.sls``. If you *have* made any changes, then you'll have
to manually ensure that any changes that you made are either already reflected in margarita, or kept
in your own state tree.

If you are not on a versioned margarita
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The master branch of the margarita repo is frozen and we have no plans to change that. This means
that your project can continue to pull from that repo, without worries that it will cause unexpected
changes in your deployment. Read on if you'd like to try upgrading to a versioned margarita.

Remember how we said that upgrading was not an automatic, reliable process? It's even less so for
projects this old, since there's no way to know which features your project has. For example, if
your project is not using GPG secrets, then it will need to set that up first, otherwise the fabfile
changes will not work. The bottom line is that this process is not foolproof.

This diff contains all of the changes to the project template recently:

https://github.com/caktus/django-project-template/compare/cc23c089a57336448f4a87ec3fa7843c85979769...55953e30eef7ebec4ec6f5c4b6fee279a93b8cda.diff

It is unlikely (though possible) that the diff will apply cleanly to your project, so you'll
probably need to pick and choose pieces of it. The important bits include the fabfile (which
contains changes to allow us to pick which Salt version we want to use), requirements changes
(especially django-dotenv), wsgi & manage.py changes for dotenv, and Vagrantfile simplifications.

Changes to the conf directory include the following.

* ``conf/salt/salt/init.sls``, ``conf/salt/salt/master.sls``, and ``conf/salt/salt/minion.sls``
  should be removed
* Any require statements for ``configure_utf-8.sh`` should be removed.
* ``conf/salt/margarita.sls`` should be changed to match the version in the current project template.
* ``conf/salt/top.sls`` should remove any references to the salt.minion states.

Once you've done those things, you'll need to follow the steps outlined above for upgrading from a
version of margarita < 1.0.4.
