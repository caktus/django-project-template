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
{% for host, ifaces in salt['mine.get']('roles:(web|worker)', 'network.interfaces', expr_form='grain_pcre').iteritems() %}
{% set host_addr = ifaces.get(salt['pillar.get']('primary_iface', 'eth0'), {}).get('inet', [{}])[0].get('address') %}
  ufw.allow:
    - name: '5672'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}