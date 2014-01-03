import sys

from {{ project_name }}.settings.base import *

DEBUG = True
TEMPLATE_DEBUG = DEBUG

INSTALLED_APPS += (
    'debug_toolbar',
)

INTERNAL_IPS = ('127.0.0.1', )

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

SOUTH_TESTS_MIGRATE = True

CELERY_ALWAYS_EAGER = True

COMPRESS_ENABLED = False

# Special test settings
if 'test' in sys.argv:
    CELERY_ALWAYS_EAGER = True

    COMPRESS_ENABLED = False

    COMPRESS_PRECOMPILERS = ()

    PASSWORD_HASHERS = (
        'django.contrib.auth.hashers.SHA1PasswordHasher',
        'django.contrib.auth.hashers.MD5PasswordHasher',
    )
