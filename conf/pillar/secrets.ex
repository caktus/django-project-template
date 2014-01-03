# This file should be renamed to secrets.sls in the relevant environment directory
secrets:
  DB_PASSWORD: XXXXXX
# Uncomment if using celery worker configuration
#   BROKER_PASSWORD: XXXXXX

# Uncomment and update username/password to enable HTTP basic auth
# http_auth:
#   username: password

github_deploy_key: |
  -----BEGIN RSA PRIVATE KEY-----
  foobar
  -----END RSA PRIVATE KEY-----