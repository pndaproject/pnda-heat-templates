#!/bin/bash -v

set -e

if [ "x$flavor$" = "xstandard" ]; then
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
cloudera:
  role: MGR02
roles:
  - cloudera_management
  - cloudera_namenode
  - cloudera_zookeeper

pnda_cluster: $pnda_cluster$
EOF
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y install xfsprogs

mkfs.xfs $volume_dev$
mkdir -p /var/log/pnda
cat >> /etc/fstab <<EOF
$volume_dev$  /var/log/pnda xfs defaults  0 0
EOF
mount -a

service salt-minion restart
