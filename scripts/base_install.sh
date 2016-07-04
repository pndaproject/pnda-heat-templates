#!/bin/bash -v

set -e

export roles="$formula"

cat >> /etc/hosts <<EOF
$master_ip$ saltmaster salt
EOF


export DEBIAN_FRONTEND=noninteractive
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U stable 2015.8.10
hostname=`hostname` && echo "id: $hostname" > /etc/salt/minion && unset hostname
echo "log_level: debug" >> /etc/salt/minion
echo "log_level_logfile: debug" >> /etc/salt/minion

a="roles:\n";for i in $roles; do a="$a  - $i\n";done;echo $a
cat > /etc/salt/grains <<EOF
pnda_cluster: $pnda_cluster$
EOF
cat >> /etc/salt/grains <<EOF
`printf "%b" "$a"`
EOF

service salt-minion restart
