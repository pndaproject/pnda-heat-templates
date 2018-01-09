#!/bin/bash -v

# This script runs on instances with a node_type tag of "saltmaster"
# The base.sh script does not run on this instance type
# It mounts the disks and installs a salt master

set -ex

declare -A conf=( )
declare -A specific=( $$SPECIFIC_CONF$$ )

# Override default configuration
for key in "${!specific[@]}"; do conf[$key]="${specific[${key}]}"; done

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

# VLAN interface on which saltmaster will listen
# By default it's eth0
VLAN=eth0

# Install the saltmaster, plus saltmaster config
if [ "x$DISTRO" == "xubuntu" ]; then
export DEBIAN_FRONTEND=noninteractive
apt-get -y install unzip=6.0-9ubuntu1.5 salt-minion=2015.8.11+ds-1 salt-master=2015.8.11+ds-1
HDP_OS=ubuntu14
elif [ "x$DISTRO" == "xrhel" ]; then
yum -y install unzip-6.0-16.el7 salt-minion-2015.8.11-1.el7 salt-master-2015.8.11-1.el7
HDP_OS=centos7
fi

get_interface_ip () {
    iface=$1

    ip -f inet -o addr show ${iface} | cut -d' ' -f 7 | cut -d'/' -f 1
}

cat << EOF > /etc/salt/master
## specific PNDA saltmaster config
auto_accept: True      # auto accept minion key on new minion provisioning

fileserver_backend:
  - roots
  - minion

file_roots:
  base:
    - /srv/salt/platform-salt/salt

pillar_roots:
  base:
    - /srv/salt/platform-salt/pillar

# Do not merge top.sls files across multiple environments
top_file_merging_strategy: same

# To autoload new created modules, states add and remove salt keys,
# update bastion /etc/hosts file automatically ... add the following reactor configuration
reactor:
  - 'minion_start':
    - salt://reactor/sync_all.sls
  - 'salt/cloud/*/created':
    - salt://reactor/create_bastion_host_entry.sls
  - 'salt/cloud/*/destroying':
    - salt://reactor/delete_bastion_host_entry.sls
## end of specific PNDA saltmaster config
file_recv: True

failhard: True
EOF

if [ -n "${VLAN}" ]; then
    listen_ip=$(get_interface_ip ${VLAN})
    echo "# Only listen on ${listen_ip} which is on VLAN interface: ${VLAN}" >> /etc/salt/master
    echo "interface: ${listen_ip}" >> /etc/salt/master
fi

# Set up ssh access to the platform-salt git repo
# if secure access is required this key will be used automatically.
# This mode is not normally used now the public github is available
mkdir -p /root/.ssh

cat << EOF > /root/.ssh/id_rsa
$git_private_key$
EOF
chmod 400 /root/.ssh/id_rsa
echo "StrictHostKeyChecking no" >> /root/.ssh/config

# Set up platform-salt that contains the scripts the saltmaster runs to install software
mkdir -p /srv/salt
cd /srv/salt

if [ "x$platform_git_repo_uri$" != "x" ]; then
  git clone --branch $git_branch$ $platform_git_repo_uri$
elif [ "x$platform_uri$" != "x" ] ; then
  mkdir -p /srv/salt/platform-salt && cd /srv/salt/platform-salt && \
  wget -q -O - $platform_uri$ | tar -zvxf - --strip=1 && ls -al && \
  cd -
else
  exit 2
fi

# Push pillar config into platform-salt for environment specific config
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
os_user: '$os_user$'
keystone.user: '$keystone_user$'
keystone.password: '$keystone_password$'
keystone.tenant: '$keystone_tenant$'
keystone.auth_url: '$keystone_auth_url$'
keystone.auth_version: '$keystone_auth_version$'
keystone.region_name: '$keystone_region_name$'
pnda.apps_container: '$pnda_apps_container$'
pnda.apps_folder: '$pnda_apps_folder$'
pnda.archive_container: '$pnda_archive_container$'
EOF

MINE_FUNCTIONS_NETWORK_INTERFACE="eth0"
if [ "x$mine_functions_network_ip_addrs_nic$" != "x" ]; then
  MINE_FUNCTIONS_NETWORK_INTERFACE="$mine_functions_network_ip_addrs_nic$"
fi

cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
pnda_mirror:
  base_url: '$pnda_mirror$'
  misc_packages_path: /mirror_misc/

hadoop:
  parcel_repo: '$pnda_mirror$/mirror_cloudera'

anaconda:
  parcel_version: "4.0.0"
  parcel_repo: '$pnda_mirror$/mirror_anaconda'

packages_server:
  base_uri: $pnda_mirror$

pip:
  index_url: '$pnda_mirror$/mirror_python/simple'

hdp:
  hdp_core_stack_repo: '$pnda_mirror$/mirror_hdp/HDP/$HDP_OS/2.6.3.0-235/'
  hdp_utils_stack_repo: '$pnda_mirror$/mirror_hdp/HDP-UTILS-1.1.0.21/repos/$HDP_OS/'
mine_functions:
  network.ip_addrs: [$MINE_FUNCTIONS_NETWORK_INTERFACE]
  grains.items: []
EOF

if [ "x$ntp_servers$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
ntp:
  servers:
    "$ntp_servers$"
EOF
fi

if [ "$package_repository_fs_type$" == "swift" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: 'swift'
EOF
elif [ "$package_repository_fs_type$" == "s3" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
aws.region: '$AWS_REGION'
aws.key: '$S3_ACCESS_KEY_ID'
aws.secret: '$S3_SECRET_ACCESS_KEY'
package_repository:
  fs_type: 's3'
EOF
elif [ "$package_repository_fs_type$" == "sshfs" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: "sshfs"
  fs_location_path: "$package_repository_fs_location_path$"
  sshfs_user: "$package_repository_sshfs_user$"
  sshfs_host: "$package_repository_sshfs_host$"
  sshfs_path: "$package_repository_sshfs_path$"
  sshfs_key: "$package_repository_sshfs_key$"
EOF
mkdir -p /srv/salt/platform-salt/salt/package-repository/files/
cat << EOF > /srv/salt/platform-salt/salt/package-repository/files/$package_repository_sshfs_key$
$package_repository_sshfs_key_file$
EOF
chmod 600 /srv/salt/platform-salt/salt/package-repository/files/$package_repository_sshfs_key$
else
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: "$package_repository_fs_type$"
  fs_location_path: "$package_repository_fs_location_path$"
EOF
fi

# Add all the specific values to the env_parameter file
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
specific_config:
EOF
for i in "${!conf[@]}"; do echo "  $i: ${conf[$i]}" >> /srv/salt/platform-salt/pillar/env_parameters.sls; done

# Set up a salt minion on the saltmaster too
cat >> /etc/hosts <<EOF
127.0.0.1 saltmaster salt
EOF

# Set up the minion grains
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
  is_new_node: True
pnda_cluster: $pnda_cluster$
hadoop.distro: '$hadoop_distro$'
EOF


service salt-minion restart
service salt-master restart
