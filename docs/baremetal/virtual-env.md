# Setting up a virtual environment

It is possible to replace bare-metal nodes with virtual machines. In
this case, except for the ironic driver used to interact with the
machines, the process remains identical to what it is with physical
machines.

## Virtual network

We create a default network xml file

	cat > default-net.xml <<EOF
	<network>
	<name>default</name>
	<bridge name="virbr0" stp='on' delay='0'/>
	<forward mode='nat'>
	<nat>
	<port start='1024' end='65535'/>
	</nat>
	</forward>
	<mac address='52:54:00:13:4f:ae'/>
	<ip address='192.168.122.1' netmask='255.255.255.0'>
	<dhcp>
	<range start='192.168.122.2' end='192.168.122.254'/>
	</dhcp>
	</ip>
	</network>
	EOF

Define and start the network

	virsh net-define default-net.xml
	virsh net-autostart default
	virsh net-start default

Verify the running network

	virsh net-dumpxml default
	<network>
	<name>default</name>
	<uuid>22bb630f-65d0-45c9-9b6e-1a2d24da48d1</uuid>
	<forward mode='nat'>
	<nat>
	<port start='1024' end='65535'/>
	</nat>
	</forward>
	<bridge name='virbr100' stp='on' delay='0'/>
	<mac address='52:54:00:13:4f:ae'/>
	<ip address='192.168.122.1' netmask='255.255.255.0'>
	<dhcp>
	<range start='192.168.122.2' end='192.168.122.254'/>
	</dhcp>
	</ip>
	</network>

Creating the virtual machines

	mkdir /home/stack/vms && cd /home/stack/vms
	/home/stack/ngena-heat-templates/helpers/create_vms.sh

Listing the previously create virtual machines

	virsh list --all

	Id Name State
	----------------------------------------------------
	- pnda-hadoop-cm shut off
	- pnda-hadoop-dn1 shut off
	- pnda-hadoop-dn2 shut off
	- pnda-hadoop-dn3 shut off
	- pnda-hadoop-mgr1 shut off
	- pnda-hadoop-mgr2 shut off
	- pnda-gateway shut off
	- pnda-kafka-1 shut off
	- pnda-kafka-2 shut off
	- pnda-master shut off
	- pnda-zookeeper-1 shut off
	- pnda-zookeeper-2 shut off
	- pnda-zookeeper-3 shut off

Check that a storage pool has been created

	semanage fcontext -a -t virt_image_t '/home/stack/vms(/.\*)?'
	restorecon -R /home/stack/vms
	virsh pool-list –all
	virsh pool-info vms

Hypervisor connectivity

	cat << EOF >
	/etc/polkit-1/localauthority/50-local.d/50-libvirt-user-stack.pkla
	[libvirt Management Access]
	Identity=unix-user:stack
	Action=org.libvirt.unix.manage
	ResultAny=yes
	ResultInactive=yes
	ResultActive=yes
	EOF
	
	ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.122.1
	ssh-copy-id -i ~/.ssh/id_rsa.pub stack@192.168.122.1
	
	virsh --connect qemu+ssh://root@192.168.122.1/system list --all

Looking for the instances mac addresses

	rm -f /tmp/nodes.txt && for i in $(virsh list --all | awk ' /pnda/
	{print $2} ');do mac=$(virsh domiflist $i | awk ' /br-ctlplane/
	{print $5} '); echo -e "$mac" >>/tmp/nodes.txt;done && cat
	/tmp/nodes.txt
	
	rm -f /tmp/names.txt && for i in $(virsh list --all | awk ' /pnda/
	{print $2} ');do echo -e "$i" >>/tmp/names.txt;done && cat
	/tmp/names.txt

Creating the instance list json file from the previously created
instance list files.

	/home/stack/ngena-heat-templates/helpers/create_json.sh

Importing the nodes into the baremetal service database

	openstack baremetal import --json ~/instackenv.json

Reviewing the imported nodes.txt

	openstack baremetal list

	+--------------------------------------+------------------+---------------+-------------+--------------------+-------------+
	| UUID | Name | Instance UUID | Power State | Provisioning State |
	Maintenance |
	+--------------------------------------+------------------+---------------+-------------+--------------------+-------------+
	| 4cbe3b0d-8fbc-48e8-ba85-933f5e39a158 | pnda-hadoop-cm | None | power off	| available | False |
	| 82e88847-88ed-4558-8ec1-0b4523d70401 | pnda-hadoop-dn1 | None | power off	| available | False |
	| 813f77ea-4982-40ec-8b09-2c2b431583b8 | pnda-hadoop-dn2 | None | power off	| available | False |
	| 13824fb4-1a31-48ad-b065-82ebaa71eac4 | pnda-hadoop-dn3 | None | power off	| available | False |
	| d2292b5e-e2e8-46cb-b644-b101a691661f | pnda-hadoop-mgr1 | None | power	off | available | False |
	| a6d9e7ba-f893-416b-ab2d-83ec03272dec | pnda-hadoop-mgr2 | None | power	off | available | False |
	| 67fea56b-3baf-4694-b175-c5b67970481a | pnda-gateway | None | power off	| available | False |
	| 770ba417-1e29-47dc-b86a-598c8889768c | pnda-kafka-1 | None | power off	| available | False |
	| b8b26264-3c29-4e44-8fb0-9b90dbb04156 | pnda-kafka-2 | None | power off	| available | False |
	| e86c8ca7-7c9e-4378-adee-7317d495b6a8 | pnda-master | None | power off	| available | False |
	| a69611b8-1a1a-40d2-a4bd-4c492e576256 | pnda-zookeeper-1 | None | power	off | available | False |
	| 3cecd513-5327-4805-a6ec-be38c5b1f430 | pnda-zookeeper-2 | None | power	off | available | False |
	| 98da9359-23df-4000-b18d-4c652a2ef59c | pnda-zookeeper-3 | None | power	off | available | False |
	+--------------------------------------+------------------+---------------+-------------+--------------------+-------------+

At this point, the power state of the nodes should be different from
‘None’ meaning that the baremetal service successfully retrieved the
actual instances power states.

Creating the instances flavors

	/home/stack/ngena-heat-templates/helpers/create_flavors.sh

Tagging the baremetal nodes with a profile

	/home/stack/ngena-heat-templates/helpers/tag_nodes.sh