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

j=0
for i in {a..e}; do
if [ -b "/dev/sdb" ]; then
umount /dev/sdb || echo "not mounted"
mkfs.xfs -f /dev/sd$i
mkdir -p /data$j
cat >> /etc/fstab <<EOF
/dev/sd$i  /data$j xfs defaults  0 0
EOF
j=`expr $j + 1`
fi
done

cat /etc/fstab
mount -a
