from {{ project_name }}.settings.staging import *

# There should be only minor differences from staging

DATABASES['default']['NAME'] = '{{ project_name }}_production'

PUBLIC_ROOT = '/var/www/{{ project_name }}-production/public/'

STATIC_ROOT = os.path.join(PUBLIC_ROOT, 'static')

MEDIA_ROOT = os.path.join(PUBLIC_ROOT, 'media')

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Prod] '