Vagrant Testing
========================


Starting the VM
------------------------

You can test the provisioning/deployment using `Vagrant <http://vagrantup.com/>`_.
Using the included Vagrantfile you can start up the VM. This requires Vagrant 1.2+ and
the ``precise32`` box. The box will be installed if you don't have it already.::

    vagrant up

The general provision workflow is the same as in the previous :doc:`provisioning guide </provisioning>`
so here are notes of the Vagrant specifics.


Provisioning the VM
------------------------

The ``fabfile.py`` contains a ``vagrant`` environment with the VM's IP already added.
The rest of the environment is made to match the ``staging`` environment. If you
have already configured the ``conf/pillar/staging/env.sls`` and ``conf/pillar/staging/secrets.sls``
then you can continue provisioning the VM.

To connect to the VM for the first time, you need to use the private key which ships
with the Vagrant install. The location of the file may vary on your platform depending
on which version you installed and how it was installed. You can use ``locate`` to find it::

    # Example locate with output
    $ locate keys/vagrant
        /opt/vagrant/embedded/gems/gems/vagrant-1.2.2/keys/vagrant
        /opt/vagrant/embedded/gems/gems/vagrant-1.2.2/keys/vagrant.pub

You can then call the initial provision using this key location for the ``-i`` option::

    fab -u vagrant -i /opt/vagrant/embedded/gems/gems/vagrant-1.2.2/keys/vagrant vagrant provision

After that has finished you can run the initial deploy::

    fab vagrant deploy


Testing on the VM
------------------------

With the VM fully provisioned and deployed, you can access the VM at the IP address specified in the
``Vagrantfile``, which is 33.33.33.10 by default. It will also be available on localhost port 8089 via
port forwarding. Since the Nginx configuration will only listen for the domain name in
``conf/pillar/staging/env.sls``, you will need to modify your ``/etc/hosts`` configuration to view it
at one of those IP addresses. I recommend 33.33.33.10, otherwise the ports in the localhost URL cause
the CSRF middleware to complain ``REASON_BAD_REFERER`` when testing over SSL. You will need to add::

    33.33.33.10 <domain>

where ``<domain>`` matches the domain in ``conf/pillar/staging/env.sls``. For example, let's use
staging.example.com::

    33.33.33.10 staging.example.com

In your browser you can now view https://staging.example.com and see the VM running the full web stack.

Note that this ``/etc/hosts`` entry will prevent you from accessing the true staging.example.com.
When your testing is complete, you should remove or comment out this entry.
