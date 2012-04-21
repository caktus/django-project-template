from {{ project_name }}.settings.staging import *

# There should be only minor differences from staging

DATABASES['default']['NAME'] = '{{ project_name }}_production'

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Prod] '

