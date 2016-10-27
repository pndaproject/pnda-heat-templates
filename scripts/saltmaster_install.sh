#!/bin/bash -v

# This script runs on instances with a node_type tag of "saltmaster"
# The base.sh script does not run on this instance type
# It mounts the disks and installs a salt master

set -ex

# Install the saltmaster, plus saltmaster config
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get -y install python-pip
apt-get -y install python-git
wget -O install_salt.sh https://bootstrap.saltstack.com
sh install_salt.sh -D -U -M stable 2015.8.11
apt-get -y install unzip

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

if [ "x$java_mirror$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
java:
  source_url: '$java_mirror$'
EOF
fi

if [ "x$cloudera_mirror$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
cloudera:
  parcel_repo: '$cloudera_mirror$'
EOF
fi

if [ "x$anaconda_mirror$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
anaconda:
  parcel_version: '4.0.0'  
  parcel_repo: '$anaconda_mirror$'
EOF
fi

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


if [ "x$packages_server_uri$" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
packages_server:
  base_uri: $packages_server_uri$
EOF
fi

restart salt-master
