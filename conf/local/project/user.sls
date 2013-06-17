{% import 'project/_vars.sls' as vars with context %}
{% set bin_dir = vars.path_from_root('env/bin') %}
{% set source_dir = vars.path_from_root('source') %}

include:
  - sudo

project_user:
  user.present:
    - name: {{ pillar['project_name'] }}
    - remove_groups: False
    - groups: [www-data]

project_sudo:
  file.managed:
    - name: /etc/sudoers.d/{{ vars.project }}
    - source: salt://project/sudoers
    - user: root
    - mode: 440
    - template: jinja
    - context:
        bin_dir: "{{ bin_dir }}"
        source_dir: "{{ source_dir }}"
    - require:
      - group: admin