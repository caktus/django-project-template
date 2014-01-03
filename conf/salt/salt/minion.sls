include:
  - salt

salt-minion:
  pkg:
    - installed
    - require:
      - pkgrepo: salt-ppa
  service:
    - running
    - enable: True
