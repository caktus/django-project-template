import sys

from {{ project_name }}.settings.base import *  # noqa

DEBUG = True

INSTALLED_APPS += (
    'debug_toolbar',
)

INTERNAL_IPS = ('127.0.0.1', )

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

CELERY_ALWAYS_EAGER = True

CELERY_EAGER_PROPAGATES_EXCEPTIONS = True

COMPRESS_ENABLED = False

SECRET_KEY = os.environ.get('SECRET_KEY', '{{ secret_key }}')

# Special test settings
if 'test' in sys.argv:
    COMPRESS_PRECOMPILERS = ()

    PASSWORD_HASHERS = (
        'django.contrib.auth.hashers.SHA1PasswordHasher',
        'django.contrib.auth.hashers.MD5PasswordHasher',
    )

    LOGGING['root']['handlers'] = []
