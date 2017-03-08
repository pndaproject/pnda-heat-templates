#!/bin/bash -v

# This script runs on instances with a node_type tag of "saltmaster"
# The base.sh script does not run on this instance type
# It mounts the disks and installs a salt master

set -ex

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

# Install the saltmaster, plus saltmaster config
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
apt-get -y install unzip salt-minion salt-master
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
yum -y install unzip salt-minion salt-master
fi

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
keystone.user: '$keystone_user$'
keystone.password: '$keystone_password$'
keystone.tenant: '$keystone_tenant$'
keystone.auth_url: '$keystone_auth_url$'
keystone.region_name: '$keystone_region_name$'
pnda.apps_container: '$pnda_apps_container$'
pnda.apps_folder: '$pnda_apps_folder$'
pnda.archive_container: '$pnda_archive_container$'
EOF

cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
pnda_mirror:
  base_url: '$pnda_mirror$'
  misc_packages_path: /mirror_misc/

cloudera:
  parcel_repo: '$pnda_mirror$/mirror_cloudera'

anaconda:
  parcel_version: "4.0.0"
  parcel_repo: '$pnda_mirror$/mirror_anaconda'

packages_server:
  base_uri: $pnda_mirror$

pip:
  index_url: '$pnda_mirror$/mirror_python/simple'
EOF

if [ "x$ntp_servers$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
ntp:
  servers:
    - "$ntp_servers$"
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

# Set up a salt minion on the saltmaster too
cat >> /etc/hosts <<EOF
127.0.0.1 saltmaster salt
EOF

# Set up the minion grains
cat > /etc/salt/grains <<EOF
pnda:
  flavor: $flavor$
pnda_cluster: $pnda_cluster$
EOF

service salt-minion restart
service salt-master restart
