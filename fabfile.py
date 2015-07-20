import os
import re
import tempfile
import time

import yaml

from fabric.api import env, execute, get, hide, local, put, require, run, settings, sudo, task
from fabric.contrib import files, project
from fabric.utils import abort

DEFAULT_SALT_LOGLEVEL = 'info'
SALT_VERSION = '2015.5.3'
PROJECT_ROOT = os.path.dirname(__file__)
CONF_ROOT = os.path.join(PROJECT_ROOT, 'conf')

VALID_ROLES = (
    'salt-master',
    'web',
    'worker',
    'balancer',
    'db-master',
    'queue',
    'cache',
)


@task
def staging():
    env.environment = 'staging'
    env.master = 'CHANGEME'
    initialize_env()


@task
def production():
    env.environment = 'production'
    env.master = 'CHANGEME'
    initialize_env()


@task
def vagrant():
    env.environment = 'local'
    env.user = 'vagrant'
    # convert vagrant's ssh-config output to a dictionary
    ssh_config_output = local('vagrant ssh-config', capture=True)
    ssh_config = dict(line.split() for line in ssh_config_output.splitlines())
    env.master = '{HostName}:{Port}'.format(**ssh_config)
    env.key_filename = ssh_config['IdentityFile']
    initialize_env()


def initialize_env():
    """Build some common variables into the env dictionary."""
    env.gpg_key = os.path.join(CONF_ROOT, '{}.pub.gpg'.format(env.environment))


def get_salt_version(command):
    """Run `command` --version, pick out the part of the output that is digits and dots,
    and return it as a string.
    If the command fails, return None.
    """
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            result = run('%s --version' % command)
            if result.succeeded:
                return re.search(r'([\d\.]+)', result).group(0)


def service_enabled(name):
    """Check if an upstart service is enabled."""
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            return sudo('service %s status' % name).succeeded


@task
def install_salt(version, master=False, minion=False, restart=True):
    """
    Install or upgrade Salt minion and/or master if needed.

    :param version: Version string, just numbers and dots, no leading 'v'.  E.g. "2015.5.0".
      THERE IS NO DEFAULT, you must pick a version.
    :param master: If True, include master in the install.
    :param minion: If True, include minion in the install.
    :param restart: If we don't need to reinstall a salt package, restart its server anyway.
    :returns: True if any changes were made, False if nothing was done.
    """
    master_version = None
    install_master = False
    if master:
        master_version = get_salt_version("salt")
        install_master = master_version != version or not service_enabled('salt-master')
        if install_master and master_version:
            # Already installed - if Ubuntu package, uninstall current version first
            # because we're going to do a git install later
            sudo("apt-get remove salt-master -yq")
        if restart and not install_master:
            sudo("service salt-master restart")

    minion_version = None
    install_minion = False
    if minion:
        minion_version = get_salt_version('salt-minion')
        install_minion = minion_version != version or not service_enabled('salt-minion')
        if install_minion and minion_version:
            # Already installed - if Ubuntu package, uninstall current version first
            # because we're going to do a git install later
            sudo("apt-get remove salt-minion -yq")
        if restart and not install_minion:
            sudo("service salt-minion restart")

    if install_master or install_minion:
        args = []
        if install_master:
            args.append('-M')
        if not install_minion:
            args.append('-N')
        args = ' '.join(args)
        # To update local install_salt.sh: wget -O install_salt.sh https://bootstrap.saltstack.com
        # then inspect it
        put(local_path="install_salt.sh", remote_path="install_salt.sh")
        sudo("sh install_salt.sh -D {args} git v{version}".format(args=args, version=version))
        return True
    return False


@task
def setup_master():
    """Provision master with salt-master."""
    require('environment')
    with settings(host_string=env.master):
        sudo('apt-get update -qq')
        sudo('apt-get install python-pip git-core python-git python-gnupg haveged -qq -y')
        sudo('mkdir -p /etc/salt/')
        put(local_path='conf/master.conf',
            remote_path='/etc/salt/master', use_sudo=True)
        # install salt master if it's not there already, or restart to pick up config changes
        install_salt(master=True, restart=True, version=SALT_VERSION)
    generate_gpg_key()
    fetch_gpg_key()


@task
def sync():
    """Rysnc local states and pillar data to the master.,
    and update our checkout of margarita
    """
    # project.rsync_project fails if host is not set
    with settings(host=env.master, host_string=env.master):
        salt_root = CONF_ROOT if CONF_ROOT.endswith('/') else CONF_ROOT + '/'
        project.rsync_project(
            local_dir=salt_root, remote_dir='/tmp/salt', delete=True)
        sudo('rm -rf /srv/salt /srv/pillar')
        sudo('mv /tmp/salt/* /srv/')
        sudo('rm -rf /tmp/salt/')
        execute(margarita)


@task
def setup_minion(*roles):
    """Setup a minion server with a set of roles."""
    require('environment')
    if not env.host_string:
        abort('When calling "setup_minion", you must pass "-H <hostname|ipaddress> " '
              'to specify which server to setup a minion on.')
    for r in roles:
        if r not in VALID_ROLES:
            abort('%s is not a valid server role for this project.' % r)
    # Master hostname/IP without the SSH port
    master_host = env.master.split(':')[0]
    config = {
        'master': 'localhost' if master_host == env.host.split(':')[0] else master_host,
        'output': 'mixed',
        'grains': {
            'environment': env.environment,
            'roles': list(roles),
        },
        'mine_functions': {
            'network.interfaces': []
        },
    }
    _, path = tempfile.mkstemp()
    with open(path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    sudo('mkdir -p /etc/salt/')
    put(local_path=path, remote_path='/etc/salt/minion', use_sudo=True)
    # install salt minion if it's not there already, or restart to pick up config changes
    install_salt(SALT_VERSION, minion=True, restart=True)
    # queries server for its fully qualified domain name to get minion id
    key_name = run('python -c "import socket; print socket.getfqdn()"')
    time.sleep(5)
    execute(accept_key, key_name)


@task
def add_role(name):
    """Add a role to an exising minion configuration."""
    if not env.host_string:
        abort('When calling "add_role", you must pass "-H <hostname|ipaddress> " '
              'to specify which server to add the new role.')
    if name not in VALID_ROLES:
        abort('%s is not a valid server role for this project.' % name)
    _, path = tempfile.mkstemp()
    get("/etc/salt/minion", path)
    with open(path, 'r') as f:
        config = yaml.safe_load(f)
    grains = config.get('grains', {})
    roles = grains.get('roles', [])
    if name not in roles:
        roles.append(name)
    else:
        abort('Server is already configured with the %s role.' % name)
    grains['roles'] = roles
    config['grains'] = grains
    with open(path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    put(local_path=path, remote_path="/etc/salt/minion", use_sudo=True)
    sudo('service salt-minion restart')


@task
def salt(cmd, target="'*'", loglevel=DEFAULT_SALT_LOGLEVEL):
    """Run arbitrary salt commands."""
    with settings(warn_only=True, host_string=env.master):
        result = sudo("salt {0} -l{1} {2} ".format(target, loglevel, cmd))
    return result


@task
def state(name, target="'*'", loglevel=DEFAULT_SALT_LOGLEVEL):
    salt('state.sls {}'.format(name), target, loglevel)


@task
def margarita():
    require('environment')
    execute(state, 'margarita', target="-G 'roles:salt-master'")
    with settings(host_string=env.master):
        sudo('service salt-master restart')


@task
def highstate(target="'*'", loglevel=DEFAULT_SALT_LOGLEVEL):
    """Run highstate on master."""
    print("This can take a long time without output, be patient")
    salt('state.highstate', target, loglevel)


@task
def accept_key(name):
    """Accept minion key on master."""
    with settings(host_string=env.master):
        sudo('salt-key --accept={0} -y'.format(name))
        sudo('salt-key -L')


@task
def delete_key(name):
    """Delete specific key on master."""
    with settings(host_string=env.master):
        sudo('salt-key -L')
        sudo('salt-key --delete={0} -y'.format(name))
        sudo('salt-key -L')


@task
def deploy(loglevel=DEFAULT_SALT_LOGLEVEL):
    """Deploy to a given environment by pushing the latest states and executing the highstate."""
    require('environment')
    sync()
    target = "-G 'environment:{0}'".format(env.environment)
    salt('saltutil.sync_all', target, loglevel)
    highstate(target)


@task
def generate_gpg_key():
    """Generate a GPG on the master if one does not exist."""
    require('environment')
    gpg_home = '/etc/salt/gpgkeys'
    gpg_file = '/tmp/gpg-batch'
    with settings(host_string=env.master):
        if not files.exists(os.path.join(gpg_home, 'secring.gpg'), use_sudo=True):
            sudo('mkdir -p {}'.format(gpg_home))
            files.upload_template(
                filename='conf/gpg.tmpl', destination=gpg_file,
                context={'environment': env.environment},
                use_jinja=False, use_sudo=False, backup=True)
            sudo('gpg --gen-key --homedir {} --batch {}'.format(gpg_home, gpg_file))


@task
def fetch_gpg_key():
    """Export GPG keys from the master."""
    require('environment')
    gpg_home = '/etc/salt/gpgkeys'
    gpg_public = '/tmp/public.gpg'
    with settings(host_string=env.master):
        with hide('running', 'stdout', 'stderr'):
            sudo('gpg --armor --homedir {} --armor --export > {}'.format(gpg_home, gpg_public))
            get(gpg_public, env.gpg_key)


@task
def encrypt(*args, **kwargs):
    """Encrypt a secret value for a given environment."""
    require('environment')
    # Convert ASCII key to binary
    temp_key = '/tmp/tmp.key'
    with hide('running', 'stdout', 'stderr'):
        local('gpg --dearmor < {} > {}'.format(env.gpg_key, temp_key))
        # Encrypt each file
        for name in args:
            local(
                'gpg --no-default-keyring --keyring {} '
                '--trust-model always -aer {}_salt_key {}'.format(
                    temp_key, env.environment, name))
        # Encrypt each value
        updates = {}
        for name, value in kwargs.items():
            updates[name] = '{}'.format(
                local(
                    'echo -n "{}" | '
                    'gpg --no-default-keyring --keyring {} '
                    '--trust-model always -aer {}_salt_key'.format(
                        value, temp_key, env.environment), capture=True))
        os.remove(temp_key)
    if updates:
        print(yaml.dump(updates, default_flow_style=False, default_style='|', indent=2))


def hostnames_for_role(role):
    with hide('running', 'stdout'):
        result = salt(
            cmd='test.ping --output=yaml',
            target='-G "roles:%s"' % role)
    return yaml.safe_load(result.stdout).keys()


def get_project_name():
    with open(os.path.join(CONF_ROOT, 'pillar', 'project.sls'), 'r') as f:
        return yaml.safe_load(f)['project_name']


@task
def manage_run(command):
    require('environment')
    project_name = get_project_name()
    manage_sh = u'/var/www/%s/manage.sh ' % project_name
    with settings(host_string=hostnames_for_role('web')[0]):
        sudo(manage_sh + command, user=project_name)


@task
def manage_shell():
    manage_run('shell')
