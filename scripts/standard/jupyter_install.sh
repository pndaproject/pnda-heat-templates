#!/bin/bash -v

set -e

if [ "x$flavor$" = "xstandard" ]; then
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
cloudera:
  role: EDGE
roles:
  - jupyter
pnda_cluster: $pnda_cluster$
EOF
fi

service salt-minion restart
