#!/bin/bash -v

set -e
export ROLES="$roles$"

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF

export DEBIAN_FRONTEND=noninteractive
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U stable 2015.8.11
hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
echo "log_level: debug" >> /etc/salt/minion
echo "log_level_logfile: debug" >> /etc/salt/minion

cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
pnda_cluster: $pnda_cluster$
EOF

if [ "x$cloudera_role$" != "x$" ]; then
  cat >> /etc/salt/grains <<EOF
cloudera:
  role: $cloudera_role$
EOF
fi

if [ "x${ROLES}" != "x" ]; then
cat >> /etc/salt/grains <<EOF
roles: [${ROLES}]
EOF
fi

service salt-minion restart

apt-get -y install xfsprogs
mkdir -p /var/lib/elasticsearch/data
if [ -b "/dev/sdb" ]; then
umount /dev/sdb || echo "not mounted"
mkfs.xfs -f /dev/sdb
cat >> /etc/fstab <<EOF
/dev/sdb  /var/lib/elasticsearch/data xfs defaults  0 0
EOF
fi
cat /etc/fstab
mount -a
