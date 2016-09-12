#!/bin/bash -v

set -e

if [ "x$flavor$" = "xstandard" ]; then
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
cloudera:
  role: EDGE
roles:
  - cloudera_edge_jupyter
  - jupyter
pnda_cluster: $pnda_cluster$
EOF
fi

service salt-minion restart
