#!/bin/bash -v

set -e

ROLES=$roles$

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF

export DEBIAN_FRONTEND=noninteractive
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U stable 2015.8.10
hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
echo "log_level: debug" >> /etc/salt/minion
echo "log_level_logfile: debug" >> /etc/salt/minion

cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
pnda_cluster: $pnda_cluster$
EOF

if [ "$cloudera_role$" != "$" ]; then
  cat >> /etc/salt/grains <<EOF
cloudera:
  role: $cloudera_role$
EOF
fi

if [ "$brokerid$" != "$" ]; then
  cat >> /etc/salt/grains <<EOF
broker_id: $brokerid$
EOF
fi

if [ "x${ROLES}" != "x" ]; then
cat >> /etc/salt/grains <<EOF
roles: [${ROLES}]
EOF
fi

service salt-minion restart

apt-get -y install xfsprogs

if [ -b $volume_dev$ ]; then
  umount $volume_dev$ || echo 'not mounted'
  mkfs.xfs $volume_dev$
  mkdir -p /var/log/pnda
  cat >> /etc/fstab <<EOF
  $volume_dev$  /var/log/pnda xfs defaults  0 0
EOF
fi

PRDISK="$volume_pr$"
if [[ ",${ROLES}," = *",package_repository,"* ]]; then
  if [ -b /dev/$volume_pr$ ]; then
    umount /dev/$volume_pr$ || echo 'not mounted'
    PRDISK=""
    mkfs.xfs /dev/$volume_pr$
    mkdir -p $package_repository_fs_location_path$
    cat >> /etc/fstab <<EOF
    /dev/$volume_pr$  $package_repository_fs_location_path$ xfs defaults  0 0
EOF
  fi
else
  PRDISK=${PRDISK/\/dev\//}
fi


DISKS="vdd vde $PRDISK"
DISK_IDX=0
for DISK in $DISKS; do
   echo $DISK
   if [ -b /dev/$DISK ];
   then
      echo "Mounting $DISK"
      umount /dev/$DISK || echo 'not mounted'
      mkfs.xfs -f /dev/$DISK
      mkdir -p /data$DISK_IDX
      sed -i "/$DISK/d" /etc/fstab
      echo "/dev/$DISK /data$DISK_IDX auto defaults,nobootwait,comment=cloudconfig 0 2" >> /etc/fstab
      DISK_IDX=$((DISK_IDX+1))
   fi
done
cat /etc/fstab
mount -a

