# flake8: noqa
import os
import sys

from {{ project_name }}.settings.base import *  # noqa

DEBUG = True

INSTALLED_APPS += (
    'debug_toolbar',
)
MIDDLEWARE += (
    'debug_toolbar.middleware.DebugToolbarMiddleware',
)

INTERNAL_IPS = ('127.0.0.1', )

#: Don't send emails, just print them on stdout
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

#: Run celery tasks synchronously
CELERY_ALWAYS_EAGER = True

#: Tell us when a synchronous celery task fails
CELERY_EAGER_PROPAGATES_EXCEPTIONS = True

SECRET_KEY = os.environ.get('SECRET_KEY', '{{ secret_key }}')

# Special test settings
if 'test' in sys.argv:
    PASSWORD_HASHERS = (
        'django.contrib.auth.hashers.SHA1PasswordHasher',
        'django.contrib.auth.hashers.MD5PasswordHasher',
    )

    LOGGING['root']['handlers'] = []

# CircleCI settings
if "CI" in os.environ:
    # Use CircleCI's default database
    DATABASES["default"]["NAME"] = "circle_test"
    DATABASES["default"]["USER"] = "ubuntu"
    DATABASES["default"]["HOST"] = "127.0.0.1"
    DATABASES["default"]["PORT"] = "5432"
