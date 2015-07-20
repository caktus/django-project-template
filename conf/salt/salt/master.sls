include:
  - ufw

ports:
  ufw.allow:
    - enabled: true
    - proto: tcp
    - names:
       - '4505'
       - '4506'
