include:
  - memcached
  - ufw

cache_firewall:
{% for host, ifaces in salt['mine.get']('roles:(web|worker)', 'network.interfaces', expr_form='grain_pcre').iteritems() %}
{% set host_addr = ifaces.get(salt['pillar.get']('primary_iface', 'eth0'), {}).get('inet', [{}])[0].get('address') %}
  ufw.allow:
    - name: '11211'
    - enabled: true
    - from: {{ host_addr }}
    - require:
      - pkg: ufw
{% endfor %}