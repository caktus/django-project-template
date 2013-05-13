from {{ project_name }}.settings.base import *

DEBUG = False
TEMPLATE_DEBUG = DEBUG

DATABASES['default']['NAME'] = '{{ project_name }}_staging'


PUBLIC_ROOT = '/var/www/{{ project_name }}/public/'

STATIC_ROOT = os.path.join(PUBLIC_ROOT, 'static')

MEDIA_ROOT = os.path.join(PUBLIC_ROOT, 'media')

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

SESSION_COOKIE_SECURE = True

SESSION_COOKIE_HTTPONLY = True