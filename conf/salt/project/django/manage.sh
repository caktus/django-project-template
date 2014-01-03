# Shell script to setup necessary environment variables and run a management command
export DJANGO_SETTINGS_MODULE={{ settings }}
export ALLOWED_HOST={{ pillar['domain'] }}
{% for key, value in pillar['secrets'].items() + pillar['env'].items() %}
export {{ key }}={{ value }}
{% endfor %}
cd {{ directory }}
{{ virtualenv_root }}/bin/python {{ directory }}/manage.py $@
