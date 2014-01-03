{% import 'project/_vars.sls' as vars with context %}

include:
  - rabbitmq
  - ufw

broker-user:
  rabbitmq_user.present:
    - name: {{ pillar['project_name'] }}_{{ pillar['environment'] }}
    - password: {{ pillar.get('secrets', {}).get('BROKER_PASSWORD') }}
    - force: True
    - require:
      - service: rabbitmq-server

broker-vhost:
  rabbitmq_vhost.present:
    - name: {{ pillar['project_name'] }}_{{ pillar['environment'] }}
    - user: {{ pillar['project_name'] }}
    - require:
      - rabbitmq_user: broker-user

queue_firewall:
{% for host, ifaces in vars.servers.iteritems() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
  ufw.allow:
    - name: '5672'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}