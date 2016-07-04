#!/bin/bash -v

set -e

export node_index=$index$

cat > /etc/salt/grains <<EOF
cloudera:
  cluster_flavour: $flavor$
pnda_cluster: $pnda_cluster$
roles:
  - opentsdb
EOF
if [ $node_index = 0 ]; then
cat >> /etc/salt/grains <<EOF
  - grafana
EOF
fi

service salt-minion restart
