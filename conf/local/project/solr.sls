{% import 'project/_vars.sls' as vars with context %}
{% set version = '3.6.2' %}
{% set solr_root = vars.root_dir + 'apache-solr-' + version + '/' %}

openjdk-7-jre-headless:
  pkg:
    - installed

solr_download:
  file.managed:
    - name: /tmp/apache-solr-{{ version }}.tgz
    - source: http://mirror.mel.bkb.net.au/pub/apache/lucene/solr/{{ version }}/apache-solr-{{ version }}.tgz
    - source_hash: md5=e9c51f51265b070062a9d8ed50b84647

solr_extract:
  cmd.run:
    - user: {{ pillar['project_name'] }}
    - name: tar xvf /tmp/apache-solr-{{ version }}.tgz -C {{ vars.root_dir }}
    - unless: test -d {{ solr_root }}
    - require:
      - file: solr_download

setup_solr_project_dir:
  cmd.run:
    - user: {{ pillar['project_name'] }}
    - name: rsync -av {{ solr_root }}/example/ {{ solr_root }}/{{ pillar['project_name'] }}
    - unless: test -d {{ solr_root }}/{{ pillar['project_name'] }}
    - require:
      - cmd: solr_extract

solr_project_dir:
  file.directory:
    - name: {{ solr_root }}/{{ pillar['project_name'] }}
    - user: {{ pillar['project_name'] }}
    - group: admin
    - dir_mode: 775
    - recurse:
        - user
        - group
        - mode
    - require:
      - group: admin
      - cmd: setup_solr_project_dir

solr_stop_words:
  file.symlink:
    - target: {{ solr_root }}/{{ pillar['project_name'] }}/solr/conf/lang/stopwords_en.txt
    - name: {{ solr_root }}/{{ pillar['project_name'] }}/solr/conf/stopwords_en.txt
    - user: {{ pillar['project_name'] }}
    - group: admin
    - require:
      - group: admin
      - file: solr_project_dir

solr_supervisor_conf:
  file.managed:
    - name: /etc/supervisor/conf.d/{{ vars.project }}-solr.conf
    - source: salt://project/supervisor/solr.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        log_dir: "{{ vars.log_dir }}"
        project: "{{ vars.project }}"
    - require:
      - pkg: supervisor
      - file: log_dir
    - watch_in:
      - cmd: supervisor_update

solr_supervisor_process:
  supervisord:
    - name: {{ vars.project }}:{{ vars.project }}-solr
    - running
    - restart: True
    - require:
      - pkg: supervisor
      - file: group_conf
      - file: solr_supervisor_conf
