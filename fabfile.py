import os
import tempfile

import yaml

from fabric.api import env, execute, get, hide, lcd, local, put, require, run, settings, sudo, task
from fabric.colors import red
from fabric.contrib import files, project
from fabric.contrib.console import confirm
from fabric.utils import abort

PROJECT_ROOT = os.path.dirname(__file__)
CONF_ROOT = os.path.join(PROJECT_ROOT, 'conf')


@task
def staging():
    env.environment = 'staging'
    env.master = ''  # FIXME
    env.hosts = [env.master]
    env.minions_file = 'conf/pillar/{0}/minions.yaml'.format(env.environment)


@task
def production():
    env.environment = 'production'
    env.master = ''  # FIXME
    env.hosts = [env.master]
    env.minions_file = 'conf/pillar/{0}/minions.yaml'.format(env.environment)


@task
def vagrant():
    env.environment = 'local'
    env.master = '33.33.33.10'
    env.hosts = [env.master]
    env.user = 'vagrant'
    vagrant_version = local('vagrant -v', capture=True).split()[-1]
    env.key_filename = '/opt/vagrant/embedded/gems/gems/vagrant-%s/keys/vagrant' % vagrant_version
    env.minions_file = 'conf/pillar/minions.yaml'


@task
def setup_servers():
    """Sets up the salt master and all the minions and does an initial deploy."""
    require('environment')
    execute(setup_master)
    execute(setup_minions)
    execute(accept_keys)
    execute(sync)
    execute(deploy)


@task
def deploy():
    """Deploy to a given environment by pushing the latest states and executing the highstate."""
    require('environment')
    with settings(host_string=env.master):
        sync()
        target = "-G 'environment:{0}'".format(env.environment)
        salt('saltutil.sync_all', target)
        highstate(target)


@task
def salt(cmd, target="'*'", loglevel='warning'):
    """Run arbitrary salt commands."""
    with settings(warn_only=True, host_string=env.master):
        sudo("salt {0} {1} -l {2}".format(target, cmd, loglevel))


@task
def highstate(target="'*'", loglevel='warning'):
    """Run highstate on master."""
    with settings(host_string=env.master):
        print("This can take a long time without output, be patient")
        salt('state.highstate', target, loglevel)


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
def setup_master():
    """Provision master with salt-master."""
    require('environment')
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
def setup_minions(*roles):
    """Sets up all the minions"""
    with open(env.minions_file, 'r') as f:
        minions = yaml.safe_load(f)
    for minion_id in minions:
        minion = minions[minion_id]
        with settings(host=minion['ip'], host_string=minion['ip']):
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
            config = minion['conf']
            _, path = tempfile.mkstemp()
            with open(path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False)
            put(local_path=path, remote_path="/etc/salt/minion", use_sudo=True)
            sudo('service salt-minion restart')


@task
def accept_keys():
    """Salt master accepts all the keys from minions defined."""
    require('environment')
    with open(env.minions_file, 'r') as f:
        minions = yaml.safe_load(f)
    for minion_id in minions:
        if not minion_id == 'master':
            # we do not need to accept the key for the master
            sudo('salt-key --accept={0} -y'.format(minion_id))


def have_secrets():
    """Check if the local secret files exist for all environments."""
    found = True
    for environment in ['staging', 'production']:
        local_file = os.path.join(CONF_ROOT, 'pillar', environment, 'secrets.sls')
        found = found and os.path.exists(local_file)
    return found
