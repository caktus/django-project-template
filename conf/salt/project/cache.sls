{% import 'project/_vars.sls' as vars with context %}

include:
  - memcached
  - ufw

cache_firewall:
{% for host, ifaces in salt['mine.get']('roles:web|worker', 'network.interfaces', expr_form='grain_pcre').items() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
  ufw.allow:
    - name: '11211'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}