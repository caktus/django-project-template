import os
import re

from fabric.api import cd, env, get, hide, local, put, require, run, settings, sudo, task
from fabric.contrib import files, project

# Directory structure
PROJECT_ROOT = os.path.dirname(__file__)
CONF_ROOT = os.path.join(PROJECT_ROOT, 'conf')
SERVER_ROLES = ['app', 'lb', 'db']
env.project = '{{ project_name }}'
env.project_user = '{{ project_name }}'
env.repo = u'' # FIXME: Add repo URL
env.shell = '/bin/bash -c'
env.disable_known_hosts = True
env.forward_agent = True


@task
def vagrant():
    env.environment = 'staging'
    env.hosts = ['33.33.33.10', ]
    env.branch = 'master'
    env.server_name = 'dev.example.com'
    setup_path()


@task
def staging():
    env.environment = 'staging'
    env.hosts = [] # FIXME: Add staging server hosts
    env.branch = 'master'
    env.server_name = '' # FIXME: Add staging server name
    setup_path()


@task
def production():
    env.environment = 'production'
    env.hosts = [] # FIXME: Add production hosts
    env.branch = 'master'
    env.server_name = '' # FIXME: Add production server name
    setup_path()


def setup_path():
    env.home = '/home/%(project_user)s/' % env
    env.root = '/var/www/'
    env.code_root = os.path.join(env.root, env.project)
    env.virtualenv_root = os.path.join(env.root, 'env')
    env.db = '%s_%s' % (env.project, env.environment)
    env.settings = '%(project)s.settings.%(environment)s' % env


@task
def provision(common='master'):
    """Provision server with masterless Salt minion."""
    require('environment')
    # Install salt minion
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which salt-call')
    if not installed:
        bootstrap_file = os.path.join(CONF_ROOT, 'bootstrap-salt.sh')
        put(bootstrap_file, '/tmp/bootstrap-salt.sh')
        sudo('sh /tmp/bootstrap-salt.sh daily')
    # Rsync local states and pillars
    minion_file = os.path.join(CONF_ROOT, 'minion.conf')
    files.upload_template(minion_file, '/etc/salt/minion', use_sudo=True, context=env)
    salt_root = CONF_ROOT if CONF_ROOT.endswith('/') else CONF_ROOT + '/'
    environments = ['staging', 'production']
    # Only include current environment's pillar tree
    exclude = [os.path.join('pillar', e) for e in environments if e != env.environment]
    project.rsync_project(local_dir=salt_root, remote_dir='/tmp/salt', delete=True, exclude=exclude)
    sudo('rm -rf /srv/*')
    sudo('mv /tmp/salt/* /srv/')
    sudo('rm -rf /tmp/salt/')
    # Pull common states
    sudo('rm -rf /tmp/common/')
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which git')
    if not installed:
        sudo('apt-get install git-core -q -y')
    run('git clone git://github.com/caktus/margarita.git /tmp/common/')
    with cd('/tmp/common/'):
        run('git checkout %s' % common)
    sudo('mv /tmp/common/ /srv/common/')
    sudo('rm -rf /tmp/common/')
    sudo('chown root:root -R /srv/')
    # Update to highstate
    sudo('salt-call --local state.highstate -l info', pty=False)


@task
def supervisor_command(command):
    """Run a supervisorctl command."""
    sudo(u'supervisorctl %s' % command)


def project_run(cmd):
    """ Uses sudo to allow developer to run commands as project user."""
    sudo(cmd, user=env.project_user)


@task
def update_requirements():
    """Update required Python libraries."""
    require('environment')
    project_run(u'HOME=%(home)s %(virtualenv)s/bin/pip install --use-mirrors -r %(requirements)s' % {
        'virtualenv': env.virtualenv_root,
        'requirements': os.path.join(env.code_root, 'requirements', 'production.txt'),
        'home': env.home,
    })


@task
def manage_run(command):
    """Run a Django management command on the remote server."""
    require('environment')
    manage_base = u"%(virtualenv_root)s/bin/django-admin.py " % env
    if '--settings' not in command:
        command = u"%s --settings=%s" % (command, env.settings)
    project_run(u'%s %s' % (manage_base, command))


@task
def manage_shell():
    """Drop into the remote Django shell."""
    manage_run("shell")


@task
def syncdb():
    """Run syncdb and South migrations."""
    manage_run('syncdb --noinput')
    manage_run('migrate --noinput')


@task
def collectstatic():
    """Collect static files."""
    manage_run('collectstatic --noinput')


def match_changes(changes, match):
    pattern = re.compile(match)
    return pattern.search(changes) is not None


@task
def deploy(branch=None):
    """Deploy to a given environment."""
    require('environment')
    if branch is not None:
        env.branch = branch
    requirements = False
    migrations = False
    if files.exists(env.code_root):
        # Fetch latest changes
        with cd(env.code_root):
            run('git fetch origin')
            # Look for new requirements or migrations
            changes = run("git diff origin/%(branch)s --stat-name-width=9999" % env)
            requirements = match_changes(changes, r"requirements/")
            migrations = match_changes(changes, r"/migrations/")
            if requirements or migrations:
                supervisor_command('stop %(environment)s:*' % env)
            run("git reset --hard origin/%(branch)s" % env)
    else:
        # Initial clone
        run('git clone %(repo)s %(code_root)s' % env)
        with cd(env.code_root):
            run('git checkout %(branch)s' % env)
        requirements = True
        migrations = True
        # Add code root to the Python path
        path_file = os.path.join(env.virtualenv_root, 'lib', 'python2.7', 'site-packages', 'project.pth')
        files.append(path_file, env.code_root, use_sudo=True)
        sudo('chown %s:%s %s' % (env.project_user, env.project_user, path_file))
    sudo('chown %(project_user)s:%(project_user)s -R %(code_root)s' % env)
    if requirements:
        update_requirements()
        # New requirements might need new tables/migrations
        syncdb()
    elif migrations:
        syncdb()
    collectstatic()
    supervisor_command('restart %(environment)s:*' % env)


@task
def get_db_dump(clean=True):
    """Get db dump of remote enviroment."""
    require('environment')
    dump_file = '%(environment)s.sql' % env
    temp_file = os.path.join(env.home, dump_file)
    flags = '-Ox'
    if clean:
        flags += 'c'
    sudo('pg_dump %s %s > %s' % (flags, env.db, temp_file), user=env.project_user)
    get(temp_file, dump_file)


@task
def load_db_dump(dump_file):
    """Load db dump on a remote environment."""
    require('environment')
    temp_file = os.path.join(env.home, '%(environment)s.sql' % env)
    put(dump_file, temp_file, use_sudo=True)
    sudo('psql -d %s -f %s' % (env.db, temp_file), user=env.project_user)
