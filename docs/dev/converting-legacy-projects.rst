Converting legacy projects to the project template
=================================

The project template represents our standard setup for new projects, as well as
our standard suite of build tools for local development. When we
are taking over maintenance of a project or otherwise handling infrastructure
upgrades for an existing project, we often want to port that project's
deployment setup over to our project template's setup in order to make
it consistent with our other projects.

This document gives an overview of the components that need to be pulled
over from the project template in order to make that happen.

Getting started
---------------

Porting over to the project template involves copying a lot of files.

The easiest way to prepare these files for copying is to start a new
project using the project template with the same name as the target
project. This will be called the **DPT base** in these docs.

Provisioning and deployment
---------------------------

The main reason the project template is useful is arguably its tools for
provisioning and deploying to servers. This section identifies the files
that need to be copied and configuration that needs to be done to take
advantage of these.

Files and requirements
~~~~~~~~~~~~~~~~~~~~~~

Copy over the following files from the DPT base:

-  ``fabfile.py``: the Fabric script used to automate provisioning and
   deployment.
-  ``install_salt.sh``: used by Fabric when setting up the Salt master
   during provisioning. If this file is not located in the same dir
   as ``fabfile.py``, provisioning will fail with a cryptic error message.
-  ``Makefile``: used for generating certain secrets (among other things not
   related to provisioning and deployment). This includes running
   ``make generate-secret`` to create a ``SECRET_KEY`` and running
   ``make <env>-deploy-key`` to produce a keypair for the environment you
   are provisioning.
-  ``conf/`` (entire directory): the Salt states and Pillar variables
   used to provision and deploy. See below for details.

Requirements files must also be adjusted to accommodate this deployment
setup. Look through ``requirements/deploy.txt`` in your DPT base and
ensure that its contents are all included in a requirement file in your
target project.

With these files in place and requirements installed, assuming that your
project is 100% compliant with the baseline dependencies found in the
DPT base, you should be able to follow the instructions in the
django-project-template provisioning documentation to set up a server.

Be sure to also add ``.priv`` to your ``.gitignore`` so that private
keys generated during the provisioning process are not accidentally
tracked.

Salt states and Margarita
~~~~~~~~~~~~~~~~~~~~~~~~~

Assuming your project is not 100% compliant with the baseline
dependencies found in the DPT base, most of the modifications you will
want to make will happen in the ``conf/salt/`` directory of your
project.

By default, projects will pull in Salt states from
`Margarita <https://github.com/caktus/margarita>`__. This includes the
core app state ``project/web/app.sls``, which handles critical tasks
like setting up Gunicorn, preparing static assets, and running
migrations.

If you want to override any Margarita states, you will need to create a
Salt state in your project whose location matches up with the Margarita
state's location in the tree. For example, to replace Margarita's
``project/web/app.sls``, create a file
``conf/salt/project/web/app.sls``. You will need to copy over all the
content of the Margarita state that you *do* want to keep, alongside
your own additions.

Examples of deviations from Margarita that you might want to implement:

-  Your project uses Compass instead of Less. The ``less`` command in
   ``app.sls`` is therefore not needed, and instead you will need to add a
   Compass command and its dependencies.
-  Your project uses MySQL instead of Postgres. The ``db/init.sls`` will
   need to be replaced with something MySQL-appropriate, and a
   configuration file will have to be included as well.

Working with roles
~~~~~~~~~~~~~~~~~~

When provisioning a server, you will need to set it up for various roles.
These roles, and the Salt states associated with them, are specified in
``conf/salt/top.sls``. This is the file that you must modify to prune away
unneeded states or to add new roles.

For example, if your project uses Solr, you will want to add a Solr-related
role to ``top.sls``, something like this:

::

   'roles:solr':
     - match: grain
     - solr.project

Once you add a role, you will need to update ``fabfile.py`` by adding a new
entry to the ``VALID_ROLES`` variable:

::
   VALID_ROLES = (
       #  ...
       'solr',
   )

If you want to add optional states to existing roles, ``top.sls`` is also
where you would do that. For example, if adding Paper Trail to a project, you
will want to add ``forward_logs`` to some role (most likely ``'*'``).

Configuration, variables, and secrets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As you add, remove, or change states or roles, you will probably need to change
some associated configuration values.

Many of these are located in ``conf/pillar/*.sls``. In particular, ``project.sls``
defines a number of values that will be used by Salt during provisioning and
deployment.

For example, the base ``project.sls`` set a ``less_version`` variable used
for specifying the version of the Less compiler to use. If you are using Compass
instead, you will want to set a ``compass_version`` variable and use it in
the appropriate Salt state (e.g. ``app.sls``) like so:

::

   compass:
     cmd.run:
       - name: gem install compass --version '{{ pillar["compass_version"] }}'
       - user: root
       - unless: 'which compass & compass --version | grep {{ pillar["compass_version"] }}'
       - require:
         - pkg: ruby-dev

Various interesting Margarita states are activated by the inclusion of settings in
``project.sls``. For example, to enable [Letsencrypt](https://letsencrypt.org/)
on your project, you need to set ``letsencrypt`` to ``true`` and include a
``admin_email`` value:

::

   letsencrypt: true

   admin_email: <project>-team@caktusgroup.com

Front end components & npm build process
----------------------------------------

Especially for projects with nontrivial JS and styling requirements
(e.g. CSS preprocessors), it is also useful to install the project
template's Node-based front-end build and deploy setup.

The easiest way to do this is to simply copy these files from the DPT
base wholesale and tinker with them as necessary:

-  ``package.json``: the NPM package file, which contains front-end
   development dependencies and information about the project. Once this
   is in your project, you can run ``npm install`` to install all
   dependencies.
-  ``gulpfile.js``: the build file for our
   `Gulp <http://gulpjs.com/>`__-based built process. This is set up
   with a number of useful tasks. Once this is in place, you can run
   ``npm run dev`` to start a dev server that will auto-recompile your
   front-end code.
-  ``.babelrc``: the `Babel <https://babeljs.io/>`__ configuration file
   that specifies how your JS will be preprocessed.
-  ``.eslintrc``: the `ESLint <http://eslint.org/>`__ configuration file
   that specifies the style your JS should conform to.

You will want to make adjustments to your ``.gitignore`` file to take into
account the various outputs of the build processes, Node dependencies, and so
on. Add at least these (changing the specific file names as necessary for
your project setup):

::

   node_modules
   */static/js/bundle.js
   */static/js/vendors.js
   */static/libs/modernizr.js
   */static/css

All interesting front-end build configuration will take place in
``gulpfile.js``. This includes changing the ``options`` object's
properties to suit your project's directory structure.

The tasks included in the ``gulpfile.js`` make some assumptions, spelled
out below.

JS task
~~~~~~~

In the ``browserify`` task, your JavaScript code will be preprocessed
and bundled into a single (minified) file. This bundle will be created
from an entry point JS file given by ``options.src`` and that file's
(recursive) dependencies.

The preprocessing that your code is subjected to is specified in
``.babelrc``. By default, this includes the ``es2015`` preset, which
allows you to use ECMAScript 2015, and the ``transform-react-jsx``
plugin, which lets you use
`JSX <https://facebook.github.io/react/docs/jsx-in-depth.html>`__ syntax
with your `React <https://facebook.github.io/react/index.html>`__ code.
The latter is included because we have begun to standardize on React for
front-end development.

The definition of ``browserifyTask`` specifies that the input to the
bundling process is ``index.js`` and the output is ``bundle.js``. Either
of these values can be changed, and the destination dir for the bundle
can be changed in ``options.dest``.

Less task
~~~~~~~~~

Our project template assumes that you are using
`Less <http://lesscss.org/>`__ as your CSS preprocessor. As with JS,
your Less will be compiled and bundled into a single file, starting with
the entry point given by ``options.css.src`` and that file's
dependencies.

One annoying "gotcha" with this setup is that the auto-rebuilding task
does not notice changes to your Less code that happen because you have
switched branches with git. In that situation, you will need to restart
your ``npm run dev`` process to force recompilation of your CSS.
