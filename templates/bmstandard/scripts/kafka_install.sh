#!/bin/bash -v

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

mkdir -p /var/kafka-logs

if [ -b "/dev/sdb" ]; then
umount /dev/sdb || echo "not mounted"
mkfs.xfs -f /dev/sdb
cat >> /etc/fstab <<EOF
/dev/sdb  /var/kafka-logs xfs defaults  0 0
EOF
fi
cat /etc/fstab
mount -a
