PROJECT_NAME = {{ project_name }}
STATIC_LIBS_DIR = ./$(PROJECT_NAME)/static/libs

default: lint test

test:
	# Run all tests and report coverage
	# Requires coverage
	python manage.py makemigrations --dry-run | grep 'No changes detected' || \
		(echo 'There are changes which require migrations.' && exit 1)
	coverage run manage.py test
	coverage report -m --fail-under 80
	npm test

lint-py:
	# Check for Python formatting issues
	# Requires flake8
	$(WORKON_HOME)/{{ project_name }}/bin/flake8 .

lint-js:
	# Check JS for any problems
	# Requires jshint
	./node_modules/.bin/eslint -c .eslintrc "${STATIC_LIBS_DIR}*" --ext js,jsx

lint: lint-py lint-js

$(STATIC_LIBS_DIR):
	mkdir -p $@

update-static-libs: $(LIBS)

# Generate a random string of desired length
generate-secret: length = 32
generate-secret:
	@strings /dev/urandom | grep -o '[[:alnum:]]' | head -n $(length) | tr -d '\n'; echo

conf/keys/%.pub.ssh:
	# Generate SSH deploy key for a given environment
	ssh-keygen -t rsa -b 4096 -f $*.priv -C "$*@${PROJECT_NAME}"
	@mv $*.priv.pub $@

staging-deploy-key: conf/keys/staging.pub.ssh

production-deploy-key: conf/keys/production.pub.ssh

# Translation helpers
makemessages:
	# Extract English messages from our source code
	python manage.py makemessages --ignore 'conf/*' --ignore 'docs/*' --ignore 'requirements/*' \
		--no-location --no-obsolete -l en

compilemessages:
	# Compile PO files into the MO files that Django will use at runtime
	python manage.py compilemessages

pushmessages:
	# Upload the latest English PO file to Transifex
	tx push -s

pullmessages:
	# Pull the latest translated PO files from Transifex
	tx pull -af

setup:
	virtualenv -p `which python3.5` $(WORKON_HOME)/{{ project_name }}
	$(WORKON_HOME)/{{ project_name }}/bin/pip install -U pip wheel
	$(WORKON_HOME)/{{ project_name }}/bin/pip install -Ur requirements/dev.txt
	$(WORKON_HOME)/{{ project_name }}/bin/pip freeze
	npm install
	npm update
	cp {{ project_name }}/settings/local.example.py {{ project_name }}/settings/local.py
	echo "DJANGO_SETTINGS_MODULE={{ project_name }}.settings.local" > .env
	createdb -E UTF-8 {{ project_name }}
	$(WORKON_HOME)/{{ project_name }}/bin/python manage.py migrate
	if [ -e project.travis.yml ] ; then mv project.travis.yml .travis.yml; fi
	@echo
	@echo "The {{ project_name }} project is now setup on your machine."
	@echo "Run the following commands to activate the virtual environment and run the"
	@echo "development server:"
	@echo
	@echo "	workon {{ project_name }}"
	@echo "	npm run dev"

update:
	$(WORKON_HOME)/{{ project_name }}/bin/pip install -U -r requirements/dev.txt
	npm install
	npm update

# Build documentation
docs:
	cd docs && make html

.PHONY: default test lint lint-py lint-js generate-secret makemessages \
		pushmessages pullmessages compilemessages docs

.PRECIOUS: conf/keys/%.pub.ssh
