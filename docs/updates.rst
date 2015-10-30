Project Template Updates
========================

These are notes related to recent changes to our Django project template. Please read to be aware of
these changes and how it may impact your project either now or in the future.

Motivation for the Changes
--------------------------

A new Salt version 2015.5 was recently released with some deprecations as well as backwards
incompatible changes. The project template has also been slow to adapt to changes needed for Ubuntu
14.04.  Recent deployment failures on Copic and Service Info also pointed to a need for more control
and stability around the versions of Salt and the related states used to provision our servers.

What Changed
------------

A few things have changed.

Related to Ubuntu updates, we’ve made Postgres 9.3 the default version. This is the version which
comes with Ubuntu 9.3. It is configurable with the ‘postgres_version’ pillar. If you are using an
older version of Ubuntu/Postgres you should set this to the version you are currently using.
Changing this version will install new packages but it won’t magically migrate data for you.

Prior to 14.04 and Postgres 9.3, there was an issue with the default server encoding being ASCII
rather than UTF-8. As part of the initial database provisioning, we were dropping the cluster and
rebuilding as UTF-8. This is a potentially dangerous operation if there is existing data in the
cluster. As such we’ve removed that state and references to it should be removed going forward.

We’ve also updated how NodeJS/NPM is installed. These were previously using the chris-lea PPA which
has now been deprecated. Ubuntu’s versions are relatively up to date and we are now using the NPM
and node packages provided by them.

The Nginx states for margarita now install Nginx from the stable PPA meaning that we can use a more
recent Nginx version. There are security as well as logging improvements which we need/want from
more recent versions and this is the first step in getting access to them.

Related to the stability and repeatability of our deployment process, we’ve changed both how we
install Salt and how we install/update margarita, the base set of states for our deployment. The
commands for setting up a master/minion are the same but behind the scenes they install Salt from a
particular git tag rather than the latest from the PPA. This give us more control on the version
used so that we can get faster access to bug fixes or work around bad versions as well as ensures
that we can have the same versions running in production and staging and test upgrades prior to
hitting production. The version of Salt installed is controlled by SALT_VERSION string in the
fabfile.

https://github.com/caktus/margarita is our set of common Salt states. Prior to our recent changes,
all projects were set to use the latest master on every deploy. This made changing/updating states
difficult since project may use different Salt or Ubuntu versions. This was also using Salt’s
built-in GitFS which as proving unreliable on a number of projects. We are now checking out a
particular tag of margarita on the master allowing projects to stick with a known good version of
margarita for the lifetime of the project and upgrade as needed. Going forward this will allow us to
clean up and improve margarita without fear of breaking projects.

How To Update a Project
-----------------------
The changes needed to update a project can be broken down into a few categories: States which need
to be updated, new states to add, states to remove, and updates to the fabfile.

States to Remove
~~~~~~~~~~~~~~~~
conf/salt/salt/init.sls and conf/salt/salt/minion.sls should be removed

States to Update
~~~~~~~~~~~~~~~~

If you should update the conf/salt/project/db/init.sls if you are using 9.3 or higher to remove any
references to configure_utf-8.sh.

conf/salt/salt/master should be updated to remove the salt include and references to any package
installs. This should only configure the firewall using the ufw state after the change.

conf/salt/project/web/app.sls should be updated to install npm and nodejs-legacy packages without
the PPA. The PPA state should be removed.

conf/salt/top.sls should remove any references to the salt.minion states which should be removed.

States to Add
~~~~~~~~~~~~~

conf/salt/margarita.sls should be added using the version in the current template. This state is
used as a replacement of GitFS. It also includes the version of margarita which will be used for the
project.


Fabfile Updates (TODO)
~~~~~~~~~~~~~~~~~~~~~~

We’ve generated a patch/diff for these changes: https://gist.github.com/mlavin/328f58dc0e65e0964001
It might cleanly apply to your project if you recently cloned the project template and haven’t made
major customizations. Even with that you should review this checklist to be sure that the changes
make sense for your project. If there are questions about the changes and whether they are need
please pin us on Hipchat.

Potential Errors (TODO)
-----------------------
