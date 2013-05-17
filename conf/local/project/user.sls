project_user:
  user.present:
    - name: {{ pillar['project_name'] }}
    - remove_groups: False
    - groups: [www-data]