#!/bin/sh
set -ex

flake8 .

coverage erase
python manage.py makemigrations --dry-run --check
coverage run manage.py test --keepdb --noinput "$@"
coverage report -m --skip-covered --fail-under 90
