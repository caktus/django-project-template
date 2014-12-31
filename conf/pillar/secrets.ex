# This file should be renamed to secrets.sls in the relevant environment directory
secrets:
  DB_PASSWORD: XXXXXX
  SECRET_KEY: XXXXXX
# Uncomment if using celery worker configuration
#   BROKER_PASSWORD: XXXXXX

# Uncomment and update username/password to enable HTTP basic auth
# http_auth:
#   username: password

# Uncomment and update ssl_key and ssl_cert to enabled signed SSL
# {% if 'balancer' in grains['roles'] %}
# ssl_key: |
#   -----BEGIN RSA PRIVATE KEY-----
#   SSL Private Key
#   -----END RSA PRIVATE KEY-----
#
# ssl_cert: |
#   -----BEGIN CERTIFICATE-----
#   Your Primary SSL Certificate
#   -----END CERTIFICATE-----
#   -----BEGIN CERTIFICATE-----
#   Your Intermediate Certificate (if needed)
#   -----END CERTIFICATE-----
#   -----BEGIN CERTIFICATE-----
#   Your Root Certificate (if needed)
#   -----END CERTIFICATE-----
# {% endif %}
