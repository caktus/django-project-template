base:
  "*":
    - project
    - devs
  'environment:local':
    - match: grain
    - local
  'environment:staging':
    - match: grain
    - staging
  'environment:production':
    - match: grain
    - production
