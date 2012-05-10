import ConfigParser
import os

from argyle import rabbitmq, postgres, nginx, system
from argyle.base import sshagent_run, upload_template
from argyle.postgres import create_db_user, create_db
from argyle.supervisor import supervisor_command, upload_supervisor_app_conf
from argyle.system import service_command, start_service, stop_service, restart_service

from fabric.api import cd, env, get, hide, local, put, require, run, settings, sudo, task
from fabric.contrib import files, console

# Directory structure
PROJECT_ROOT = os.path.dirname(__file__)
CONF_ROOT = os.path.join(PROJECT_ROOT, 'conf')
env.project = '{{ project_name }}'
env.project_user = '{{ project_name }}'
env.repo = u'' # FIXME: Add repo URL
env.shell = '/bin/bash -c'
env.disable_known_hosts = True
env.ssh_port = 2222

# Additional settings for argyle
env.ARGYLE_TEMPLATE_DIRS = (
    os.path.join(CONF_ROOT, 'templates')
)


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
    env.root = os.path.join(env.home, 'www', env.environment)
    env.code_root = os.path.join(env.root, env.project)
    env.project_root = os.path.join(env.code_root, env.project)
    env.virtualenv_root = os.path.join(env.root, 'env')
    env.log_dir = os.path.join(env.root, 'log')
    env.db = '%s_%s' % (env.project, env.environment)
    env.vhost = '%s_%s' % (env.project, env.environment)
    env.settings = '%(project)s.settings.%(environment)s' % env


@task
def create_users():
    """Create project user and developer users."""
    ssh_dir = u"/home/%s/.ssh" % env.project_user
    system.create_user(env.project_user, groups=['www-data', 'login', ])
    sudo('mkdir -p %s' % ssh_dir)
    user_dir = os.path.join(CONF_ROOT, "users")
    for username in os.listdir(user_dir):
        key_file = os.path.normpath(os.path.join(user_dir, username))
        system.create_user(username, groups=['dev', 'login', ], key_file=key_file)
        with open(key_file, 'rt') as f:
            ssh_key = f.read()
        # Add ssh key for project user
        files.append('%s/authorized_keys' % ssh_dir, ssh_key, use_sudo=True)
    files.append(u'/etc/sudoers', r'%dev ALL=(ALL) NOPASSWD:ALL', use_sudo=True)
    sudo('chown -R %s:%s %s' % (env.project_user, env.project_user, ssh_dir))


@task
def configure_ssh():
    """
    Change sshd_config defaults:
    Change default port
    Disable root login
    Disable password login
    Restrict to only login group
    """
    ssh_config = u'/etc/ssh/sshd_config'
    files.sed(ssh_config, u"Port 22$", u"Port %s" % env.ssh_port, use_sudo=True)
    files.sed(ssh_config, u"PermitRootLogin yes", u"PermitRootLogin no", use_sudo=True)
    files.append(ssh_config, u"AllowGroups login", use_sudo=True)
    files.append(ssh_config, u"PasswordAuthentication no", use_sudo=True)
    service_command(u'ssh', u'reload')


@task
def install_packages(*roles):
    """Install packages for the given roles."""
    roles = list(roles)
    if roles == ['all', ]:
        roles = SERVER_ROLES
    if 'base' not in roles:
        roles.insert(0, 'base')
    config_file = os.path.join(CONF_ROOT, u'packages.conf')
    config = ConfigParser.SafeConfigParser()
    config.read(config_file)
    for role in roles:
        if config.has_section(role):
            # Get ppas
            if config.has_option(role, 'ppas'):
                for ppa in config.get(role, 'ppas').split(' '):
                    system.add_ppa(ppa, update=False)
            # Get sources
            if config.has_option(role, 'sources'):
                for section in config.get(role, 'sources').split(' '):
                    source = config.get(section, 'source')
                    key = config.get(section, 'key')
                    system.add_apt_source(source=source, key=key, update=False)
            sudo(u"apt-get update")
            sudo(u"apt-get install -y %s" % config.get(role, 'packages'))
            sudo(u"apt-get upgrade -y")


@task
def setup_server(*roles):
    """Install packages and add configurations for server given roles."""
    require('environment')
    # Set server locale    
    sudo('/usr/sbin/update-locale LANG=en_US.UTF-8')
    install_packages(*roles)
    if 'db' in roles:
        if console.confirm(u"Do you want to reset the Postgres cluster?.", default=False):
            # Ensure the cluster is using UTF-8
            sudo('pg_dropcluster --stop 9.1 main', user='postgres')
            sudo('pg_createcluster --start -e UTF-8 9.1 main', user='postgres') 
        postgres.create_db_user(username=env.project_user)
        postgres.create_db(name=env.db, owner=env.project_user)
    if 'app' in roles:
        # Create project directories and install Python requirements
        project_run('mkdir -p %(root)s' % env)
        project_run('mkdir -p %(log_dir)s' % env)
        with settings(user=env.project_user):
            # TODO: Add known hosts prior to clone.
            # i.e. ssh -o StrictHostKeyChecking=no git@github.com
            sshagent_run('git clone %(repo)s %(code_root)s' % env)
        project_run('git checkout %(branch)s' % env)
        # Install and create virtualenv
        with settings(hide('everything'), warn_only=True):
            test_for_pip = run('which pip')
        if not test_for_pip:
            sudo("easy_install -U pip")
        with settings(hide('everything'), warn_only=True):
            test_for_virtualenv = run('which virtualenv')
        if not test_for_virtualenv:
            sudo("pip install -U virtualenv")
        project_run('virtualenv -p python2.6 --clear --distribute %s' % env.virtualenv_root)
        path_file = os.path.join(env.virtualenv_root, 'lib', 'python2.6', 'site-packages', 'project.pth')
        files.append(path_file, env.code_root, use_sudo=True)
        sudo('chown %s:%s %s' % (env.project_user, env.project_user, path_file))
        sudo('npm install less -g')
        update_requirements()
        upload_supervisor_app_conf(app_name=u'gunicorn')
        upload_supervisor_app_conf(app_name=u'group')
        # Restart services to pickup changes
        supervisor_command('reload')
        supervisor_command('restart %(environment)s:*' % env)
    if 'lb' in roles:
        nginx.remove_default_site()
        nginx.upload_nginx_site_conf(site_name=u'%(project)s-%(environment)s.conf' % env)


def project_run(cmd):
    """ Uses sudo to allow developer to run commands as project user."""
    sudo(cmd, user=env.project_user)


@task
def update_requirements():
    """Update required Python libraries."""
    require('environment')
    project_run(u'%(virtualenv)s/bin/pip install --use-mirrors -q -r %(requirements)s' % {
        'virtualenv': env.virtualenv_root,
        'requirements': os.path.join(env.code_root, 'requirements', 'production.txt')
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


def match_changes(branch, match):
    changes = run("git diff {0} origin/{0} --stat | grep {1}".format(branch, match))
    return any(changes)


@task
def deploy(branch=None):
    """Deploy to a given environment."""
    require('environment')
    if branch is not None:
        env.branch = branch
    requirements = False
    migrations = False
    # Fetch latest changes
    with cd(env.code_root):
        with settings(user=env.project_user):
            sshagent_run('git fetch origin')
        # Look for new requirements or migrations
        requirements = match_changes(env.branch, "'requirements\/'")
        migrations = match_changes(env.branch, "'\/migration\/'")
        if requirements or migrations:
            supervisor_command('stop %(environment)s:*' % env)
        run("git reset --hard origin/%(branch)s" % env)
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
