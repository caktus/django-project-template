# TODO: Replace with project name
PROJECT_NAME = project_name
STATIC_LIBS_DIR = ./$(PROJECT_NAME)/static/libs

LESS_VERSION = 2.1.0
MODERNIZR_VERSION = 2.8.3
JQUERY_VERSION = 1.11.2
BOOTSTRAP_VERSION = 3.3.1

default: lint test

test:
	# Run all tests and report coverage
	# Requires coverage
	coverage run manage.py test
	coverage report -m --fail-under 80

lint-py:
	# Check for Python formatting issues
	# Requires flake8
	flake8 .

lint-js:
	# Check JS for any problems
	# Requires jshint
	find -name "*.js" -not -path "${STATIC_LIBS_DIR}*" -print0 | xargs -0 jshint

lint: lint-py lint-js

$(STATIC_LIBS_DIR):
	mkdir -p $@

$(STATIC_LIBS_DIR)/less.js: $(STATIC_LIBS_DIR)
	wget https://cdnjs.cloudflare.com/ajax/libs/less.js/$(LESS_VERSION)/less.js -O $@

LIBS := $(STATIC_LIBS_DIR)/less.js

$(STATIC_LIBS_DIR)/modernizr.js: $(STATIC_LIBS_DIR)
	wget https://cdnjs.cloudflare.com/ajax/libs/modernizr/$(MODERNIZR_VERSION)/modernizr.js -O $@

LIBS += $(STATIC_LIBS_DIR)/modernizr.js

$(STATIC_LIBS_DIR)/jquery.js: $(STATIC_LIBS_DIR)
	wget https://cdnjs.cloudflare.com/ajax/libs/jquery/$(JQUERY_VERSION)/jquery.js -O $@

LIBS += $(STATIC_LIBS_DIR)/jquery.js

$(STATIC_LIBS_DIR)/bootstrap: $(STATIC_LIBS_DIR)
	wget https://github.com/twbs/bootstrap/releases/download/v${BOOTSTRAP_VERSION}/bootstrap-${BOOTSTRAP_VERSION}-dist.zip -O bootstrap.zip
	unzip bootstrap.zip
	mv dist $@
	rm bootstrap.zip

LIBS += $(STATIC_LIBS_DIR)/bootstrap

update-static-libs: $(LIBS)

generate-secret: length = 32
generate-secret:
	# Generate a random string of desired length
	@strings /dev/urandom | grep -o '[[:alnum:]]' | head -n $(length) | tr -d '\n'; echo

conf/pillar/%/deploy.pub:
	# Generate SSH deploy key for a given environment
	ssh-keygen -t rsa -b 4096 -f $(basename $@ .pub) -C "$*@${PROJECT_NAME}"

conf/pillar/%/secrets.sls: conf/pillar/%/deploy.pub
	# Creates new secrets file for a given environment
	cp ./conf/pillar/secrets.ex $@

bootstrap-pillars: conf/pillar/staging/secrets.sls conf/pillar/production/secrets.sls

.PHONY: default test lint lint-py lint-js generate-secret

.PRECIOUS: conf/pillar/%/deploy.pub conf/pillar/%/secrets.sls
