How to Release
==============

This is a checklist for releasing a new version of {{ project_name }}.

Git branches
------------

We use the `Git Flow process
<http://nvie.com/posts/a-successful-git-branching-model/>`_ for development. The
two branches of concern at release time are:

* **master** - always has the most recently released code.
* **develop** - contains the code under development for the next release

What makes a new release is merging ``develop`` to ``master`` and tagging it.


Version numbers
---------------

FIXME: Each project should include their own version numbering guidance. One
example is provided in the following paragraph:

Each version will be labeled "M.N"", where M represents the sprint number and N
is zero for the first release of a sprint, and incremented if additional
releases are required before the next sprint is complete.


Servers
-------

The **master** branch of code is deployed to the Production server. The
**develop** branch of code is deployed to the Staging server.

Staging can be redeployed at anytime and probably should be updated anytime a
nontrivial pull-request is merged. Production will be updated whenever there is
a new release.


Initial (or new developer) Setup
--------------------------------

We use the `git flow tool <https://github.com/nvie/gitflow>`_ to help with the
Git Flow branching model, especially for releases. Set up the git flow tool:

* Make a fresh clone of the repo (to make sure we're working off the same code
  that's on github):

  .. code-block:: bash

     git clone git@github.com:ORGNAME/{{ project_name }}.git
     cd {{ project_name }}

* Set up git flow in this new repo:

  .. code-block:: bash

     git checkout master
     git flow init -d


Release steps
-------------

Take these steps to release the new version:

* Deploy **develop** branch to staging and be sure it is functioning as
  expected.

* Start release branch using git flow:

  .. code-block:: bash

     git flow release start <VERSION>

  e.g.

  .. code-block:: bash

     git flow release start '3.1'

  Do **not** include ``v`` on the front of the version number - there's nothing
  wrong with it, we're just not using it for our version numbers here and want
  to be consistent.

* Run the tests locally. The tests must pass before proceeding. Fix any problems
  and commit the changes.

* Set ``VERSION`` in ``{{ project_name }}/__init__.py`` to the same version,
  e.g. ``VERSION = '3.1'``.

* Start a new section in ``docs/release_notes.rst`` for the new release. Always
  put the new release section above the previous ones.

* Review ``git log`` and add major new features and incompatibilities to the
  release notes.

* Commit changes. Be sure to include the new version number in the commit
  message first line, e.g. "Bump version for 3.1".

* Use **git flow commands** to make the release:

  .. code-block:: bash

     git flow release finish '3.1'

  You'll be prompted for commit and tag messages. The defaults are fine (``Merge
  branch 'release/3.1'``).

* Push the merged master and develop branch and tag to github:

  .. code-block:: bash

     git push origin master --tags
     git push origin develop --tags

* Deploy to production.

* Email the release announcement.
