# Shell script to setup necessary environment variables and run a management command
export DJANGO_SETTINGS_MODULE='{{ settings }}'
export DOMAIN='{{ pillar["domain"] }}'
export ENVIRONMENT='{{ pillar["environment"] }}'
{% for key, value in pillar.get('secrets', {}).items() + pillar.get('env', {}).items() %}
export {{ key }}='{{ value }}'
{% endfor %}
cd {{ directory }}
{{ virtualenv_root }}/bin/python {{ directory }}/manage.py $@
