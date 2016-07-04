#!/bin/bash -v

set -e

KEY="$private_key$"
KEYNAME=$keyname$
export roles="$formula"
echo $roles

if [ "x$KEYNAME" != "x" ];
then
printf "%b" "$KEY" > /home/cloud-user/$KEYNAME.pem
chown cloud-user:cloud-user /home/cloud-user/$KEYNAME.pem
chmod 600 /home/cloud-user/$KEYNAME.pem
unset KEY KEYNAME
fi

a="roles:\n";for i in $roles; do a="$a  - $i\n";done;echo $a
cat > /etc/salt/grains <<EOF
pnda_cluster: $pnda_cluster$
EOF
cat >> /etc/salt/grains <<EOF
`printf "%b" "$a"`
EOF

service salt-minion restart
