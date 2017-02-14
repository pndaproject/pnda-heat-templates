#!/bin/bash -v

# This script runs on all instances except the saltmaster
# It installs a salt minion and mounts the disks

set -ex
DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

if [ "x$DISTRO" == "xubuntu" ]; then
rm -rf /etc/apt/sources.list.d/*
rm -rf /etc/apt/sources.list
touch /etc/apt/sources.list
cat > /etc/apt/sources.list.d/local.list <<EOF
  deb $pnda_mirror$/mirror_deb/ ./
EOF
wget -O - $pnda_mirror$/mirror_deb/pnda.gpg.key | apt-key add -
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install xfsprogs salt-minion
elif [ "x$DISTRO" == "xrhel" ]; then
rm -rf /etc/yum.repos.d/*
yum-config-manager --add-repo $pnda_mirror$/mirror_rpm
rpm --import $pnda_mirror$/mirror_rpm/RPM-GPG-KEY-redhat-release
rpm --import $pnda_mirror$/mirror_rpm/RPM-GPG-KEY-mysql
rpm --import $pnda_mirror$/mirror_rpm/RPM-GPG-KEY-cloudera
rpm --import $pnda_mirror$/mirror_rpm/RPM-GPG-KEY-EPEL-7
rpm --import $pnda_mirror$/mirror_rpm/SALTSTACK-GPG-KEY.pub
rpm --import $pnda_mirror$/mirror_rpm/RPM-GPG-KEY-CentOS-7
rpm --import $pnda_mirror$/mirror_rpm/NODESOURCE-GPG-SIGNING-KEY-EL
yum -y install xfsprogs wget salt-minion
fi

ROLES=$roles$

# VLAN interface(s) that needs to be configured
VLAN=bond0

configure_vlan () {
    raw_if=$1
    vlan_if=$2
    vlan_id=$3

    # On Debian Ubuntu the vconfig command is needed
    apt-get install -y vlan
    # grep -q -F '8021q' /etc/modules || echo '8021q' >> /etc/modules

    cat > /etc/network/interfaces.d/${vlan_if}.cfg <<-EOF
	auto ${vlan_if}
	
	iface ${vlan_if} inet dhcp
	    vlan-raw-device ${raw_if}
	    vlan-id ${raw_id}
	EOF

    ifup ${vlan_if}
}

# XXX: How can we guess that we are on a kafka/zk host and not hadoop ?
# XXX: Maybe by matching on the hostname ?
# XXX: Let's do it later by matching on the $ROLES variable

case "$(hostname)" in
*-kafka-*)
  configure_vlan "bond0" "vlan2006" "2006"
  ;;
*-cdh-*)
  configure_vlan "bond0" "vlan2008" "2008"
  ;;
*)
  # Do nothing at the moment
  ;;
esac

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

PIP_INDEX_URL="$pnda_mirror$/mirror_python/simple"
TRUSTED_HOST=$(echo $PIP_INDEX_URL | awk -F'[/:]' '/http:\/\//{print $4}')
cat << EOF > /etc/pip.conf
[global]
index-url=$PIP_INDEX_URL
trusted-host=$TRUSTED_HOST
EOF
cat << EOF > /root/.pydistutils.cfg
[easy_install]
index_url=$PIP_INDEX_URL
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
