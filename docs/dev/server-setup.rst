Server Setup
========================


Provisioning
------------------------

The server provisioning is managed using `Salt Stack <http://saltstack.com/>`_. The base
states are managed in a `common repo <https://github.com/caktus/margarita>`_ and additional
states specific to this project are contained within the ``conf`` directory at the root
of the repository.

For more information see the :doc:`provisioning guide <provisioning>`.


Layout
------------------------

Below is the server layout created by this provisioning process::

    /var/www/{{ project_name }}/
        source/
        env/
        log/
        public/
            static/
            media/
        ssl/

``source`` contains the source code of the project. ``env``
is the `virtualenv <http://www.virtualenv.org/>`_ for Python requirements. ``log``
stores the Nginx, Gunicorn and other logs used by the project. ``public``
holds the static resources (css/js) for the project and the uploaded user media.
``public/static/`` and ``public/media/`` map to the ``STATIC_ROOT`` and
``MEDIA_ROOT`` settings. ``ssl`` contains the SSL key and certificate pair.


Deployment
------------------------

For deployment, each developer connects to the Salt master as their own user. Each developer
has SSH access via their public key. These users are created/managed by the Salt
provisioning. The deployment itself is automated with `Fabric <http://docs.fabfile.org/>`_.
To deploy, a developer simply runs::

    # Deploy updates to staging
    fab staging deploy
    # Deploy updates to production
    fab production deploy

This runs the Salt highstate for the given environment. This handles both the configuration
of the server as well as updating the latest source code. This can take a few minutes and
does not produce any output while it is running. Once it has finished the output should be
checked for errors.
