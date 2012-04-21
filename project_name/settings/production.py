from {{ project_name }}.settings.base import *

DEBUG = False
TEMPLATE_DEBUG = DEBUG

DATABASES['default']['NAME'] = '{{ project_name }}_production'

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Prod] '

COMPRESS_ENABLED = True
