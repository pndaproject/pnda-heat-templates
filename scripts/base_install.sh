#!/bin/bash -v

# This script runs on all instances except the saltmaster
# It installs a salt minion and mounts the disks

set -e

ROLES=$roles$

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF

# Install a salt minion
export DEBIAN_FRONTEND=noninteractive
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U stable 2015.8.11
hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
echo "log_level: debug" >> /etc/salt/minion
echo "log_level_logfile: debug" >> /etc/salt/minion

# Set up the grains
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
pnda_cluster: $pnda_cluster$
EOF

# The cloudera:role grain is used by the cm_setup.py (in platform-salt) script to
# place specific cloudera roles on this instance.
# The mapping of cloudera roles to cloudera:role grains is
# defined in the cfg_<flavor>.py.tpl files (in platform-salt)
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

# The roles grains determine what software is installed
# on this instance by platform-salt scripts
if [ "x${ROLES}" != "x" ]; then
cat >> /etc/salt/grains <<EOF
roles: [${ROLES}]
EOF
fi

service salt-minion restart

# Mount the disks
apt-get -y install xfsprogs

if [ -b $volume_dev$ ]; then
  umount $volume_dev$ || echo 'not mounted'
  mkfs.xfs $volume_dev$
  mkdir -p /var/log/pnda
  cat >> /etc/fstab <<EOF
  $volume_dev$  /var/log/pnda xfs defaults  0 0
EOF
fi

# If a sshfs disk for application packages is required
# then mount it for that purpose
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

# Mount the rest of the disks as /dataN
# These can be used for additional HDFS space if HDFS is configured to use them
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

