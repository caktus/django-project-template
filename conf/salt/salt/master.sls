include:
  - salt
  - ufw

salt-master:
  pkg:
    - installed
    - require:
      - pkgrepo: salt-ppa
  service:
    - running
    - enable: True

ports:
  ufw.allow:
    - enabled: true
    - proto: tcp
    - names:
       - '4505'
       - '4506'
