from {{ project_name }}.settings.base import *

DEBUG = False
TEMPLATE_DEBUG = DEBUG

STAGING_SECRETS = SECRETS.get('STAGING', {})

DATABASES['default']['NAME'] = '{{ project_name }}_staging'
DATABASES['default']['PASSWORD'] = STAGING_SECRETS.get('DB_PASSWORD', '')

INSTALLED_APPS += (
    'gunicorn',
)

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': '127.0.0.1:11211',
    }
}

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Staging] '

COMPRESS_ENABLED = True
