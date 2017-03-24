# Setting up Undercloud VM

## Overview

This VM will contain a single-system OpenStack installation that includes components for provisioning and managing the rest of the cluster.

To set up the Undercloud we need to carry out the following steps -

- Create virtual network for the VM
- Prepare a disk image for the VM
- Create the VM
- Configure the VM networking

## Walkthrough

These instructions are carried out on the Build Node.

##### Setup a user that has sudo privildges

The user performing all of the setup steps needs to have sudo enabled. 

```
sudo useradd stack
sudo sh -c 'echo "cisco" | passwd stack --stdin'
echo "stack ALL=(root) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/stack
sudo chmod 0440 /etc/sudoers.d/stack
su - stack
```

##### Install libvirtd/kvm hypervisor services
```	
sudo yum -y install libvirt qemu-kvm virt-manager virt-install libguestfs-tools qemu-kvm-tools
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

#### Create the provisioning network

We use virsh to create a network called 'provisioning' with a defined address range.

```
cat > /tmp/provisioning.xml <<EOF
<network>
  <name>provisioning</name>
  <ip address="172.16.0.254" netmask="255.255.255.0"/>
</network>
EOF

sudo virsh net-define /tmp/provisioning.xml
sudo virsh net-autostart provisioning
sudo virsh net-start provisioning
```

#### Prepare the undercloud disk image

We use a generic CentOS image and call it ```undercloud.qcow2```. 

```
wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz
xz -d CentOS-7-x86_64-GenericCloud.qcow2.xz
sudo cp CentOS-7-x86_64-GenericCloud.qcow2 /var/lib/libvirt/images/undercloud.qcow2
```

#### Resize the undercloud disk

The generic Centos image does not have sufficient disk space. Resize it now.

```
sudo qemu-img resize /var/lib/libvirt/images/undercloud.qcow2 +120G
```

#### Adjust the Undercloud root partition accordingly

The partition table then needs adjusting to make use of the additional space.

**TODO** For me the first step throws a 'Device or resource busy' error after successfully writing the partition - assume this is safely ignored? 

```
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'echo -e "d\nn\n\n\n\n\nw\n" | fdisk /dev/sda'
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'xfs_growfs /'
sudo virt-filesystems --long -h --all -a /var/lib/libvirt/images/undercloud.qcow2
```

#### Uninstall cloud-init as it is not required by the Undercloud

Cloud-init is installed in images designed to be used in the cloud. It's not needed here and will slow down the boot process as it tries to contact resources which don't exist.

```
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'yum remove cloud-init* -y'
```

#### Set the root password for the Undercloud
```
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --root-password password:cisco
```

#### Enabling the ssh daemon
```
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'systemctl enable sshd'
```

#### Customizing Undercloud interfaces

Add a second interface for the provisioning network 

```
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'cp /etc/sysconfig/network-scripts/ifcfg-eth{0,1} && sed -i s/DEVICE=.*/DEVICE=eth1/g /etc/sysconfig/network-scripts/ifcfg-eth1'
sudo virt-customize -a /var/lib/libvirt/images/undercloud.qcow2 --run-command 'sed -i s/BOOTPROTO=.*/BOOTPROTO=none/g /etc/sysconfig/network-scripts/ifcfg-eth1'
```

#### Creating the Undercloud VM

```
sudo virt-install --ram 32768 --vcpus 4 --os-variant rhel7     --disk path=/var/lib/libvirt/images/undercloud.qcow2,device=disk,bus=virtio,format=qcow2     --import --noautoconsole --graphics vnc,listen=0.0.0.0,password=cisco --network network:default --network network:provisioning  --name undercloud
sudo virsh list --all
```

#### Place the host provisioning interface in the right bridge

**TODO** - why?

Determine the bridge name:

```
sudo virsh net-dumpxml provisioning | grep bridge
  <bridge name='virbr1' stp='on' delay='0'/>
```

Determine the if name. There should be two interfaces named `en*`, one will already have an IP address e.g. `inet 10.60.19.29/24`, and one will not, choose the one that *does not* aleady have an IP address.

```
ip a
2: enp7s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master virbr1 state UP qlen 1000
    link/ether 00:25:b5:42:00:f4 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::225:b5ff:fe42:f4/64 scope link
       valid_lft forever preferred_lft forever
3: enp8s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP qlen 1000
    link/ether 00:25:b5:42:00:f2 brd ff:ff:ff:ff:ff:ff
    inet 10.60.19.29/24 brd 10.60.19.255 scope global dynamic enp8s0
       valid_lft 319202sec preferred_lft 319202sec
    inet6 2001:420:44f1:3:225:b5ff:fe42:f2/64 scope global noprefixroute dynamic
       valid_lft 2591962sec preferred_lft 604762sec
    inet6 fe80::225:b5ff:fe42:f2/64 scope link
       valid_lft forever preferred_lft forever
```

```
sudo brctl addif virbr1 enp7s0
```

## Next

[Deploy Undercloud](deploy-undercloud.md)
