{% import 'project/_vars.sls' as vars with context %}

include:
  - memcached
  - ufw

{% for host, ifaces in salt['mine.get']('roles:web|worker', 'network.interfaces', expr_form='grain_pcre').items() %}
{% set host_addr = vars.get_primary_ip(ifaces) %}
cache_allow-{{ host_addr }}:
  ufw.allow:
    - name: '11211'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}