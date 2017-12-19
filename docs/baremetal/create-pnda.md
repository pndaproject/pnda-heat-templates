# Create PNDA

## Overview

## Walkthrough

```
cd ~/pnda-heat-templates
```
#### Create an ssh keypair and name it deploy
```
ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/home/stack/.ssh/id_rsa): deploy
deploy already exists.
Overwrite (y/n)? y
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in deploy.
Your public key has been saved in deploy.pub.
The key fingerprint is:
e2:17:f3:e6:88:48:26:dd:fb:83:52:47:fd:4b:59:a2 stack@undercloud.cisco.com
The key's randomart image is:
+--[ RSA 4096]----+
|                 |
|                 |
|         .       |
|        . . . .  |
|      ..S  o +   |
|   . o...+E +    |
|  . +.oo. o. .   |
|   +...+.+  .    |
|    ..o.o..      |
+-----------------+
```
The SSH public key needs to be imported into the github account.

#### Creating an environment file for the pnda deployment
```
cat > pnda_env.yaml <<EOF
parameter_defaults:
  public_net: 5982b761-802a-4af3-9c0b-c3b457559179
  private_net_name: 'HOTPndaNetwork'
  private_net_cidr: '192.168.10.0/24'
  private_net_pool_end: '192.168.10.250'
  private_net_pool_start: '192.168.10.10'
  private_net_gateway: '192.168.10.1'
  name_servers: [ "144.254.71.184", "173.38.200.100" ]
  image_id: pnda-image
  keystone_user: '$OS_USERNAME'
  keystone_password: '$OS_PASSWORD'
  keystone_tenant: '$OS_TENANT_NAME'
  keystone_auth_url: '$OS_AUTH_URL'
  keystone_auth_version: '$OS_IDENTITY_API_VERSION'  
  keystone_region_name: 'regionOne'
  JavaMirror: 'http://10.60.17.100/NFS/repos/java/jdk/8u74-b02/jdk-8u74-linux-x64.tar.gz'
  ClouderaParcelsMirror: 'http://10.60.17.100/mirror/archive.cloudera.com/cdh5/parcels/5.5.2/'
  pnda_apps_container:  'pnda_apps'
  pnda_apps_folder:  'releases'
  pnda_archive_container:  'pnda_archive'
  packages_server_uri: 'http://173.39.246.113/'
  platform_git_repo_uri: 'https://github.com/pndaproject/platform-salt.git'
  GitBranch: master
  git_private_key_file: deploy
  NtpServers: 'ntp.esl.cisco.com'
  signal_transport: TEMP_URL_SIGNAL
  software_config_transport: POLL_TEMP_URL
  package_repository_fs_type: 'local'
  package_repository_fs_location_path: '/opt/pnda/packages'
  hadoop_distro: 'CDH'  
EOF
```
#### Creating the necessary files and swift containers
```
touch pr_key
sudo yum -y install python-pip
sudo pip install jinja2 --upgrade
```
#### Create the stack
```
cd cli
./heat_cli.py -e pnda-cluster -f bmstandard -b master -s default -bare true -fstype local create
```
#### Updating the undercloud ```/etc/hosts``` file
```
openstack server list -c Networks -c Name | grep -v Networks|awk {'print $4,$2'}|cut -d\= -f2 - |sudo tee -a /etc/hosts
```

#### Connecting to PNDA

Forward host port 2222 to the undercloud ssh port
```
iptables -t nat -I PREROUTING -p tcp -d 10.60.19.29 --dport 2222 -j DNAT --to-destination 192.168.122.73:22
iptables -I FORWARD -m state -d 192.168.122.0/24 --state NEW,RELATED,ESTABLISHED -j ACCEPT
```

