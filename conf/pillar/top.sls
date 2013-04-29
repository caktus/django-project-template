base:
  "*":
    - project
    - devs
  "*-staging":
    - staging.env
    - staging.secrets
  "*-production":
    - production.env
    - production.secrets
