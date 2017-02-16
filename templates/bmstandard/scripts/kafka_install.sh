#!/bin/bash -v

set -e

ROLES=$roles$

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
