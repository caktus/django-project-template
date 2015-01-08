Vagrant Testing
========================


Starting the VM
------------------------

You can test the provisioning/deployment using `Vagrant <http://vagrantup.com/>`_. This requires
Vagrant 1.7+. The Vagrantfile is configured to install the Salt Master and Minion inside the VM once
you've run ``vagrant up``. The box will be installed if you don't have it already.::

    vagrant up

The general provision workflow is the same as in the previous :doc:`provisioning guide </provisioning>`
so here are notes of the Vagrant specifics.


Provisioning the VM
------------------------

Set your environment variables and secrets in ``conf/pillar/local.sls``. It is OK for this to
be checked into version control because it can only be used on the developer's local machine. To
finalize the provisioning you simply need to run::

    fab vagrant deploy

The Vagrant box will use the current working copy of the project and the local.py settings. If you
want to use this for development/testing it is helpful to change your local settings to extend from
staging instead of dev::

    # Example local.py
    from {{ project_name }}.settings.staging import *

    # Override settings here
    DATABASES['default']['NAME'] = '{{ project_name }}_local'
    DATABASES['default']['USER'] = '{{ project_name }}_local'

    DEBUG = True

This won't have the same nice features of the development server such as auto-reloading but it will
run with a stack which is much closer to the production environment. Also beware that while
``conf/pillar/local.sls`` is checked into version control, ``local.py`` generally isn't, so it will
be up to you to keep them in sync.


Testing on the VM
------------------------

With the VM fully provisioned and deployed, you can access the VM at the IP address specified in the
``Vagrantfile``, which is 33.33.33.10 by default. Since the Nginx configuration will only listen for the domain name in
``conf/pillar/local.sls``, you will need to modify your ``/etc/hosts`` configuration to view it
at one of those IP addresses. I recommend 33.33.33.10, otherwise the ports in the localhost URL cause
the CSRF middleware to complain ``REASON_BAD_REFERER`` when testing over SSL. You will need to add::

    33.33.33.10 <domain>

where ``<domain>`` matches the domain in ``conf/pillar/local.sls``. For example, let's use
dev.example.com::

    33.33.33.10 dev.example.com

In your browser you can now view https://dev.example.com and see the VM running the full web stack.

Note that this ``/etc/hosts`` entry will prevent you from accessing the true dev.example.com.
When your testing is complete, you should remove or comment out this entry.
