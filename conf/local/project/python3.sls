deadsnakes-repo:
  pkgrepo.managed:
    - humanname: Deadsnakes PPA
    - ppa: fkrull/deadsnakes
    - require_in:
      - pkg: python3.3
      - pkg: python3.3-dev

python3.3:
  pkg.installed

python3.3-dev:
  pkg.installed
