#!/bin/bash -v

set -e

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF

export DEBIAN_FRONTEND=noninteractive
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U stable 2015.8.10
hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
echo "log_level: debug" >> /etc/salt/minion
echo "log_level_logfile: debug" >> /etc/salt/minion

