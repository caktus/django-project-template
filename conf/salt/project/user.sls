project_user:
  user.present:
    - name: {{ pillar['project_name'] }}
    - home: /home/{{ pillar['project_name'] }}
    - shell: /bin/bash
    - remove_groups: False
    - groups: [www-data]
