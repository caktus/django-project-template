#!yaml|gpg

environment: staging

branch: master

# FIXME: Change to match staging domain name
domain: staging.example.com

# Addtional public environment variables to set for the project
env:
  FOO: BAR

# Uncomment and update username/password to enable HTTP basic auth
# Password must be GPG encrypted.
# http_auth:
#   username: |-
#    -----BEGIN PGP MESSAGE-----
#    -----END PGP MESSAGE-----

# Private environment variables. Must be GPG encrypted.
# secrets:
#   "DB_PASSWORD": |-
#     -----BEGIN PGP MESSAGE-----
#     -----END PGP MESSAGE-----
#   "SECRET_KEY": |-
#     -----BEGIN PGP MESSAGE-----
#     -----END PGP MESSAGE-----

# Private deploy key. Must be GPG encrypted.
# github_deploy_key: |-
#    -----BEGIN PGP MESSAGE-----
#    -----END PGP MESSAGE-----

# Uncomment and update ssl_key and ssl_cert to enabled signed SSL
# Must be GPG encrypted.
# {% if 'balancer' in grains['roles'] %}
# ssl_key: |
# -----BEGIN PGP MESSAGE-----
# -----END PGP MESSAGE-----
#
# ssl_cert: |
# -----BEGIN PGP MESSAGE-----
# -----END PGP MESSAGE-----
# {% endif %}
