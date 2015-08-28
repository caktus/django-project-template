"""
WSGI config for {{ project_name }} project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/{{ docs_version }}/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

import dotenv
dotenv.read_dotenv(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, '.env')))

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "{{ project_name }}.settings")

application = get_wsgi_application()
