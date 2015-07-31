# Settings for live deployed environments: vagrant, staging, production, etc
from .base import *  # noqa

os.environ.setdefault('CACHE_HOST', '127.0.0.1:11211')
os.environ.setdefault('BROKER_HOST', '127.0.0.1:5672')

ENVIRONMENT = os.environ['ENVIRONMENT']

DEBUG = False

DATABASES['default']['NAME'] = '{{ project_name }}_%s' % ENVIRONMENT.lower()
DATABASES['default']['USER'] = '{{ project_name }}_%s' % ENVIRONMENT.lower()
DATABASES['default']['HOST'] = os.environ.get('DB_HOST', '')
DATABASES['default']['PORT'] = os.environ.get('DB_PORT', '')
DATABASES['default']['PASSWORD'] = os.environ.get('DB_PASSWORD', '')

WEBSERVER_ROOT = '/var/www/{{ project_name }}/'

PUBLIC_ROOT = os.path.join(WEBSERVER_ROOT, 'public')

STATIC_ROOT = os.path.join(PUBLIC_ROOT, 'static')

MEDIA_ROOT = os.path.join(PUBLIC_ROOT, 'media')

LOGGING['handlers']['file']['filename'] = os.path.join(
    WEBSERVER_ROOT, 'log', '{{ project_name }}.log')

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': '%(CACHE_HOST)s' % os.environ,
    }
}

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} %s] ' % ENVIRONMENT.title()

COMPRESS_ENABLED = True

SESSION_COOKIE_SECURE = True

SESSION_COOKIE_HTTPONLY = True

ALLOWED_HOSTS = os.environ['ALLOWED_HOSTS'].split(';')

# Uncomment if using celery worker configuration
# CELERY_SEND_TASK_ERROR_EMAILS = True
# BROKER_URL = 'amqp://{{ project_name }}_%(ENVIRONMENT)s:%(BROKER_PASSWORD)s@%(BROKER_HOST)s/{{ project_name }}_%(ENVIRONMENT)s' % os.environ  # noqa

# Environment overrides
# These should be kept to an absolute minimum
if ENVIRONMENT.upper() == 'LOCAL':
    # Don't send emails from the Vagrant boxes
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
