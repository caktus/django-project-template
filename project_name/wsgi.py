"""
WSGI config for {{ project_name }} project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/{{ docs_version }}/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

from . import load_env

load_env.load_env()
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "{{ project_name }}.settings")

application = get_wsgi_application()
