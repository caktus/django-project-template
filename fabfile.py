import os
import tempfile

import yaml

from fabric.api import env, get, hide, lcd, local, put, require, run, settings, sudo, task
from fabric.colors import red
from fabric.contrib import files, project
from fabric.contrib.console import confirm
from fabric.utils import abort

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

# FIXME: Once the master has been setup this should be set to IP of the master
# This assumes a single master for both staging and production
env.master = 'CHANGEME'


@task
def staging():
    env.environment = 'staging'


@task
def production():
    env.environment = 'production'


@task
def vagrant():
    env.environment = 'local'
    env.master = '33.33.33.10'
    env.user = 'vagrant'
    vagrant_version = local('vagrant -v', capture=True).split()[-1]
    env.key_filename = '/opt/vagrant/embedded/gems/gems/vagrant-%s/keys/vagrant' % vagrant_version


@task
def setup_master():
    """Provision master with salt-master."""
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which salt')
    if not installed:
        sudo('apt-get update -qq -y')
        sudo('apt-get install python-software-properties -qq -y')
        sudo('add-apt-repository ppa:saltstack/salt -y')
        sudo('apt-get update -qq')
        sudo('apt-get install salt-master -qq -y')
    # make sure git is installed for gitfs
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which git')
    if not installed:
        sudo('apt-get install python-pip git-core -qq -y')
        sudo('pip install -q -U GitPython')
    put(local_path='conf/master.conf', remote_path="/etc/salt/master", use_sudo=True)
    sudo('service salt-master restart')


@task
def sync():
    """Rysnc local states and pillar data to the master."""
    # Check for missing local secrets so that they don't get deleted
    # project.rsync_project fails if host is not set
    with settings(host=env.master, host_string=env.master):
        if not have_secrets():
            get_secrets()
        else:
            # Check for differences in the secrets files
            for environment in ['staging', 'production']:
                remote_file = os.path.join('/srv/pillar/', environment, 'secrets.sls')
                with lcd(os.path.join(CONF_ROOT, 'pillar', environment)):
                    if files.exists(remote_file):
                        get(remote_file, 'secrets.sls.remote')
                    else:
                        local('touch secrets.sls.remote')
                    with settings(warn_only=True):
                        result = local('diff -u secrets.sls.remote secrets.sls')
                        if result.failed and not confirm(red("Above changes will be made to secrets.sls. Continue?")):
                            abort("Aborted. File have been copied to secrets.sls.remote. " +
                              "Resolve conflicts, then retry.")
                        else:
                            local("rm secrets.sls.remote")
        salt_root = CONF_ROOT if CONF_ROOT.endswith('/') else CONF_ROOT + '/'
        project.rsync_project(local_dir=salt_root, remote_dir='/tmp/salt', delete=True)
        sudo('rm -rf /srv/salt /srv/pillar')
        sudo('mv /tmp/salt/* /srv/')
        sudo('rm -rf /tmp/salt/')


def have_secrets():
    """Check if the local secret files exist for all environments."""
    found = True
    for environment in ['staging', 'production']:
        local_file = os.path.join(CONF_ROOT, 'pillar', environment, 'secrets.sls')
        found = found and os.path.exists(local_file)
    return found


@task
def get_secrets():
    """Grab the latest secrets file from the master."""
    with settings(host=env.master):
        for environment in ['staging', 'production']:
            local_file = os.path.join(CONF_ROOT, 'pillar', environment, 'secrets.sls')
            if os.path.exists(local_file):
                local('cp {0} {0}.bak'.format(local_file))
            remote_file = os.path.join('/srv/pillar/', environment, 'secrets.sls')
            get(remote_file, local_file)


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
            installed = run('which salt-call')
    if not installed:
        # install salt-minion from PPA
        sudo('apt-get update -qq -y')
        sudo('apt-get install python-software-properties -qq -y')
        sudo('add-apt-repository ppa:saltstack/salt -y')
        sudo('apt-get update -qq')
        sudo('apt-get install salt-minion -qq -y')
    config = {
        'master': 'localhost' if env.master == env.host else env.master,
        'environment': env.environment,
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
def salt(cmd, target="'*'"):
    """Run arbitrary salt commands."""
    with settings(warn_only=True, host_string=env.master):
        sudo("salt {0} {1}".format(target, cmd))


@task
def highstate(target="'*'"):
    """Run highstate on master."""
    with settings(host_string=env.master):
        print("This can take a long time without output, be patient")
        salt('state.highstate', target)


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
def deploy():
    """Deploy to a given environment by pushing the latest states and executing the highstate."""
    require('environment')
    with settings(host_string=env.master):
        sync()
        target = "-G 'environment:{0}'".format(env.environment)
        salt('saltutil.sync_all', target)
        highstate(target)
