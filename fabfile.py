import os
import tempfile
import time

import yaml

from fabric.api import env, execute, get, hide, lcd, local, put, require, run, settings, sudo, task
from fabric.colors import red
from fabric.contrib import files, project
from fabric.contrib.console import confirm
from fabric.utils import abort

DEFAULT_SALT_LOGLEVEL = 'info'
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


@task
def setup_master():
    """Provision master with salt-master."""
    require('environment')
    with settings(host_string=env.master):
        with settings(warn_only=True):
            with hide('running', 'stdout', 'stderr'):
                installed = run('which salt-master')
        if not installed:
            sudo('apt-get update -qq -y')
            sudo('apt-get install python-software-properties -qq -y')
            sudo('add-apt-repository ppa:saltstack/salt -y')
            sudo('apt-get update -qq')
            sudo('apt-get install salt-master -qq -y')
            sudo('apt-get install python-pip git-core python-git python-gnupg haveged -qq -y')
        put(local_path='conf/master.conf',
            remote_path="/etc/salt/master", use_sudo=True)
        sudo('service salt-master restart')
    generate_gpg_key()
    fetch_gpg_key()


@task
def sync():
    """Rysnc local states and pillar data to the master."""
    # project.rsync_project fails if host is not set
    with settings(host=env.master, host_string=env.master):
        salt_root = CONF_ROOT if CONF_ROOT.endswith('/') else CONF_ROOT + '/'
        project.rsync_project(
            local_dir=salt_root, remote_dir='/tmp/salt', delete=True)
        sudo('rm -rf /srv/salt /srv/pillar')
        sudo('mv /tmp/salt/* /srv/')
        sudo('rm -rf /tmp/salt/')


@task
def setup_minion(*roles):
    """Setup a minion server with a set of roles."""
    require('environment')
    for r in roles:
        if r not in VALID_ROLES:
            abort('%s is not a valid server role for this project.' % r)
    # install salt minion if it's not there already
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which salt-minion')
    if not installed:
        # install salt-minion from PPA
        sudo('apt-get update -qq -y')
        sudo('apt-get install python-software-properties -qq -y')
        sudo('add-apt-repository ppa:saltstack/salt -y')
        sudo('apt-get update -qq')
        sudo('apt-get install salt-minion -qq -y')
    config = {
        'master': 'localhost' if env.master == env.host else env.master,
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
    put(local_path=path, remote_path="/etc/salt/minion", use_sudo=True)
    sudo('service salt-minion restart')
    # queries server for its fully qualified domain name to get minion id
    key_name = run('python -c "import socket; print socket.getfqdn()"')
    time.sleep(5)
    execute(accept_key, key_name)


@task
def add_role(name):
    """Add a role to an exising minion configuration."""
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
def highstate(target="'*'", loglevel=DEFAULT_SALT_LOGLEVEL):
    """Run highstate on master."""
    with settings(host_string=env.master):
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
    with settings(host_string=env.master):
        if env.environment != "local":
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
