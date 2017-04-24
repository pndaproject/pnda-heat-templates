#!/bin/bash

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
apt-get -y install xfsprogs=3.1.9ubuntu2 salt-minion=2015.8.11+ds-1
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
yum -y install xfsprogs-4.5.0-9.el7_3 wget-1.14-13.el7 salt-minion-2015.8.11-1.el7
fi

export ROLES="$roles$"


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
