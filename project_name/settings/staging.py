from {{ project_name }}.settings.base import *

DEBUG = False
TEMPLATE_DEBUG = DEBUG

DATABASES['default']['NAME'] = '{{ project_name }}_staging'
DATABASES['default']['USER'] = '{{ project_name }}_staging'
DATABASES['default']['PASSWORD'] = os.environ['DB_PASSWORD']

PUBLIC_ROOT = '/var/www/{{ project_name }}/public/'

STATIC_ROOT = os.path.join(PUBLIC_ROOT, 'static')

MEDIA_ROOT = os.path.join(PUBLIC_ROOT, 'media')

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': '127.0.0.1:11211',
    }
}

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Staging] '

COMPRESS_ENABLED = True

SESSION_COOKIE_SECURE = True

SESSION_COOKIE_HTTPONLY = True

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '').split(';')

# Uncomment if using celery worker configuration
# BROKER_URL = 'amqp://{{ project_name }}_staging:%s@127.0.0.1:5672/{{ project_name }}_staging' % os.environ['BROKER_PASSWORD']
