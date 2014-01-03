{% import 'project/_vars.sls' as vars with context %}

include:
  - memcached
  - ufw

cache_firewall:
{% for host, ifaces in vars.servers.iteritems() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
  ufw.allow:
    - name: '11211'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}