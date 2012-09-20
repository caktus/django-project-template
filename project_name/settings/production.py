from {{ project_name }}.settings.staging import *

# There should be only minor differences from staging

PRODUCTION_SECRETS = SECRETS.get('PRODUCTION', {})

DATABASES['default']['NAME'] = '{{ project_name }}_production'
DATABASES['default']['PASSWORD'] = PRODUCTION_SECRETS.get('DB_PASSWORD', '')

EMAIL_SUBJECT_PREFIX = '[{{ project_name|title }} Prod] '

