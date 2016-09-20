#!/bin/bash -v

set -e

if [ "x$flavor$" = "xstandard" ]; then
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
cloudera:
  role: EDGE
roles:
  - cloudera_edge
  - console_frontend
  - console_backend_data_logger
  - console_backend_data_manager
  - graphite
  - gobblin
  - deployment_manager
  - package_repository
  - data_service
  - impala-shell
  - yarn-gateway
  - hbase_opentsdb_tables
  - hdfs_cleaner
  - master_dataset
pnda_cluster: $pnda_cluster$
EOF
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y install xfsprogs

mkfs.xfs $volume_dev$
mkdir -p /var/log/pnda
cat >> /etc/fstab <<EOF
$volume_dev$  /var/log/pnda xfs defaults  0 0
EOF
mount -a

service salt-minion restart
