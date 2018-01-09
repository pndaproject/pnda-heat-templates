#!/bin/bash -v

# This script runs on all instances except the saltmaster
# It installs a salt minion and mounts the disks

set -ex

declare -A conf=( )
declare -A specific=( $$SPECIFIC_CONF$$ )

# Override default configuration
for key in "${!specific[@]}"; do conf[$key]="${specific[${key}]}"; done

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

if [ "x$DISTRO" == "xubuntu" ]; then
export DEBIAN_FRONTEND=noninteractive
apt-get -y install xfsprogs=3.1.9ubuntu2 salt-minion=2015.8.11+ds-1
elif [ "x$DISTRO" == "xrhel" ]; then
yum -y install xfsprogs-4.5.0-9.el7_3 wget-1.14-13.el7 salt-minion-2015.8.11-1.el7
fi

ROLES=$roles$

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF

if [ "x$DISTRO" == "xubuntu" ]; then
export DEBIAN_FRONTEND=noninteractive
fi

hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
cat >> /etc/salt/minion <<EOF
log_level: debug
log_level_logfile: debug

backend: requests
requests_lib: True
EOF

# Set up the grains
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
  is_new_node: True
hadoop.distro: '$hadoop_distro$'

pnda_cluster: $pnda_cluster$
EOF

# The hadoop:role grain is used by the cm_setup.py (in platform-salt) script to
# place specific hadoop roles on this instance.
# The mapping of hadoop roles to hadoop:role grains is
# defined in the cfg_<flavor>.py.tpl files (in platform-salt)
if [ "$hadoop_role$" != "$" ]; then
  cat >> /etc/salt/grains <<EOF
hadoop:
  role: $hadoop_role$
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

if [ "$pnda_internal_network$" != "$" ] && [ "$pnda_ingest_network$" != "$" ]; then
cat >> /etc/salt/grains <<EOF
vlans:
  pnda: $pnda_internal_network$
  ingest: $pnda_ingest_network$
EOF
fi

PIP_INDEX_URL="$pnda_mirror$/mirror_python/simple"
TRUSTED_HOST=$(echo $PIP_INDEX_URL | awk -F'[/:]' '/http:\/\//{print $4}')
cat << EOF > /etc/pip.conf
[global]
index-url=$PIP_INDEX_URL
extra-index-url=https://pypi.python.org/simple/
trusted-host=$TRUSTED_HOST
EOF
cat << EOF > /root/.pydistutils.cfg
[easy_install]
index_url=$PIP_INDEX_URL
find_links=https://pypi.python.org/simple/
EOF

service salt-minion restart


# Mount the disks
LOG_VOLUME_ID="$log_volume_id$"
LOG_VOLUME_DEVICE="/dev/disk/by-id/virtio-$(echo ${LOG_VOLUME_ID} | cut -c -20)"
echo LOG_VOLUME_DEVICE is $LOG_VOLUME_DEVICE
if [ -b $LOG_VOLUME_DEVICE ]; then
  echo LOG_VOLUME_DEVICE exists
  umount $LOG_VOLUME_DEVICE || echo 'not mounted'
  mkfs.xfs $LOG_VOLUME_DEVICE
  mkdir -p /var/log/pnda
  cat >> /etc/fstab <<EOF
  $LOG_VOLUME_DEVICE  /var/log/pnda xfs defaults  0 0
EOF
fi

HDFS_VOLUME_ID="$hdfs_volume_id$"
HDFS_VOLUME_DEVICE="/dev/disk/by-id/virtio-$(echo ${HDFS_VOLUME_ID} | cut -c -20)"
echo HDFS_VOLUME_DEVICE is $HDFS_VOLUME_DEVICE
if [ -b $HDFS_VOLUME_DEVICE ]; then
  echo HDFS_VOLUME_DEVICE exists
  umount $HDFS_VOLUME_DEVICE || echo 'not mounted'
  mkfs.xfs $HDFS_VOLUME_DEVICE
  mkdir -p /data0
  cat >> /etc/fstab <<EOF
  $HDFS_VOLUME_DEVICE  /data0 xfs defaults  0 0
EOF
fi

if [[ "$package_repository_fs_type$" == "local" ]]; then
  PR_VOLUME_ID="$pr_volume_id$"
  PR_VOLUME_DEVICE="/dev/disk/by-id/virtio-$(echo ${PR_VOLUME_ID} | cut -c -20)"
  echo PR_VOLUME_DEVICE is $PR_VOLUME_DEVICE
  if [ -b $PR_VOLUME_DEVICE ]; then
    echo PR_VOLUME_DEVICE exists
    umount $PR_VOLUME_DEVICE || echo 'not mounted'
    mkfs.xfs $PR_VOLUME_DEVICE
    mkdir -p $package_repository_fs_location_path$
    cat >> /etc/fstab <<EOF
    $HDFS_VOLUME_DEVICE  $package_repository_fs_location_path$ xfs defaults  0 0
EOF
  fi
fi

cat /etc/fstab
mount -a
