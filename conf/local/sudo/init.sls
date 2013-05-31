sudo:
  pkg:
    - installed

/etc/sudoers:
  file.managed:
    - source: salt://sudo/sudoers
    - user: root
    - mode: 440
    - require:
      - group: admin
