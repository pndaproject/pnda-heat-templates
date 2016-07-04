#!/bin/bash -v

set -e

cat > /etc/salt/grains <<EOF
roles:
  - zookeeper
pnda_cluster: $pnda_cluster$
cluster: zk$pnda_cluster$
EOF

export DEBIAN_FRONTEND=noninteractive
apt-get -y install xfsprogs

mkfs.xfs $volume_dev$
mkdir -p /var/log/pnda
cat >> /etc/fstab <<EOF
$volume_dev$  /var/log/pnda xfs defaults  0 0
EOF
mount -a

service salt-minion restart
