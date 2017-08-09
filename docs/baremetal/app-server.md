# Creating PNDA Applications VM

## Overview

This VM will be the HTTP server from which PNDA will install the software it needs during the installation process. The software is built from our GitHub and simply copied to the relevant location.

## Walkthrough

#### Creating the VM

```
sudo qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/appserver.qcow2 40G
sudo virt-install  --name=appserver --file=/var/lib/libvirt/images/appserver.qcow2 --graphics vnc,listen=0.0.0.0 --vcpus=1 --ram=4096 --network network=provisioning,model=virtio --os-type=linux --boot hd --dry-run --print-xml > appserver.xml
sudo virsh define appserver.xml
sudo virsh domiflist appserver
```
#### Retrieve its mac address
```
Interface  Type       Source     Model       MAC
-------------------------------------------------------
-          network    provisioning virtio      52:54:00:67:99:43
```
Create a json file to describe the app server machine (put the mac addess above into it)
```
# cat ~/pnda-apps.json 
{
  "nodes": [
    {
      "arch": "x86_64",
      "disk": "10",
      "name": "pndaapps",
      "pm_addr": "192.168.122.1",
      "pm_password": "-----BEGIN RSA PRIVATE KEY-----\nMIICXQIBAAKBgQCygHMyAqkDzblq8MD9RP5FQbuAzB2GQdlwKxSvCBQEkqe9Y6Kf\n8iSQCfiuKB8uoAAHMQCZ6tu8QRbxmy71OhtvZU8cc8x9w2Nzcn5M+JVyMKhBRGZd\n7YUjCpqDeVasDjAzFf286BeZSeiPE7DEjAAfo957zrEMJJyoKJDSQeoI+QIDAQAB\nAoGBAIS69u2NBNiLNQDMHPU3REuDYUWYgau/c0vw/ORaAWiVFJ3DZL3CdGWWxI/b\nzbQBzYOLcIMDHHmTfNgTKIu4tYSUQaW7lwBTkjZSG80nVapatLT/RwJlmUQSyU8w\ndgAUml+Nq0iF+/FRAHRa6UvUpLY1ZfDrEsoQvqcnX/ghx8uxAkEA69pR8A1fAwY9\nuqyvpx6QTs8DhsIbGHfdk3o7ZFiKxrQ2k6R1MB5fIV5RrdfADuuGT4J0jruSELRD\nUvb6oD0dBwJBAMG/9vit7pjuOxh86lsi8rDJ1x0qi65DifIw+ffB7NwC84lUxZmm\nRaBeACYLPrSCddlD5LMG6V1NUb54adR8Kf8CQD0ag83weOQcstNxN9TRO0vfoCdC\nlKiDLXmu2kJGGjYerGEV43KC+9x2Ri0Gz3BOHq7sumvcNpxzR1nwOMBY9PMCQFDf\nrFuJXrr/VjOWkMyR/fPFjMFj7QJEtuQdhXnhvNjpcna0p/bG7PFPy4gV0YrPmhmi\nuWfxTp/fkmuLH8HOQkkCQQDYFxfYHDNf/I65lN5bocawrCxEJ6h4s/cbs3lzxX/z\nC56t9ikNEWmfQle8BOj5fbRi6r44YFXanZX+qEGe2RZd\n-----END RSA PRIVATE KEY-----",
      "pm_user": "root",
      "pm_type": "pxe_ssh",
      "mac": [
        "52:54:00:67:99:43"
      ],
      "cpu": "1",
      "memory": "1024"
    }
  ]
}
```
#### Add the machine to ironic
```
openstack baremetal import ~/pnda-apps.json
openstack baremetal configure boot
```
#### Check the machine existence
```
[root@undercloud ~]# openstack baremetal list |grep pndaapps
| 0e389292-e8f5-4653-ba04-658b5503ae86 | pndaapps      | None          | power on    | manageable         | True        |
```
#### Introspect the machine
```
ironic node-set-provision-state 0e389292-e8f5-4653-ba04-658b5503ae86 manage
ironic node-set-maintenance 0e389292-e8f5-4653-ba04-658b5503ae86 on
openstack baremetal introspection start 0e389292-e8f5-4653-ba04-658b5503ae86
```
#### Wait for introspection to finish
```
[root@undercloud ~]# openstack baremetal introspection status 0e389292-e8f5-4653-ba04-658b5503ae86
+----------+-------+
| Field    | Value |
+----------+-------+
| error    | None  |
| finished | True  |
+----------+-------+
```
#### Set the machine to a deployable state
```
ironic node-set-provision-state 0e389292-e8f5-4653-ba04-658b5503ae86 provide
ironic node-set-maintenance 0e389292-e8f5-4653-ba04-658b5503ae86 off
```
#### Create a flavor and tag everyone as appserver
```
openstack flavor create --id auto --ram 2048 --disk 10 --vcpus 1 appserver
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="appserver" appserver
ironic node-update 0e389292-e8f5-4653-ba04-658b5503ae86 add properties/capabilities=profile:appserver,boot_option:local
```
#### Create an app server instance
```
openstack server create --flavor appserver --image pnda-image --key-name default appserver
openstack server list | grep appserver
| 02ac07fa-4816-4636-85b1-e8123412fd19 | appserver | BUILD  | ctlplane=192.0.3.6 |
```
#### Once the status is ACTIVE connect to the created server
```
ssh cloud-user@192.0.3.6
```
#### Clone the main PNDA repository
```
git clone https://github.com/pndaproject/pnda.git
cd pnda/build
git checkout release/3.4
```
#### As root install the required build tools
```
sudo -i
./install-build-tools.sh
exit
```
#### Build the PNDA apps for release 3.4
```
. set-pnda-env.sh
./build.sh RELEASE release/3.4
```
#### Once completed the apps stand in the directory
```
ls pnda-dist

console-backend-data-logger-0.3.0.tar.gz              deployment-manager-0.3.0.tar.gz               package-repository-0.3.0.tar.gz
console-backend-data-logger-0.3.0.tar.gz.sha512.txt   deployment-manager-0.3.0.tar.gz.sha512.txt    package-repository-0.3.0.tar.gz.sha512.txt
console-backend-data-manager-0.3.0.tar.gz             gobblin-distribution-0.1.3.tar.gz             platformlibs-0.1.2-py2.7.egg
console-backend-data-manager-0.3.0.tar.gz.sha512.txt  gobblin-distribution-0.1.3.tar.gz.sha512.txt  platformlibs-0.1.2-py2.7.egg.sha512.txt
console-frontend-0.1.4.tar.gz                         hdfs-cleaner-0.2.0.tar.gz                     platform-testing-cdh-0.3.0.tar.gz
console-frontend-0.1.4.tar.gz.sha512.txt              hdfs-cleaner-0.2.0.tar.gz.sha512.txt          platform-testing-cdh-0.3.0.tar.gz.sha512.txt
data-service-0.2.0.tar.gz                             kafka-manager-1.3.1.6.zip                     platform-testing-general-0.3.0.tar.gz
data-service-0.2.0.tar.gz.sha512.txt                  kafka-manager-1.3.1.6.zip.sha512.txt          platform-testing-general-0.3.0.tar.gz.sha512.txt
```
#### Install an http server
```
sudo apt -y install apache2
```
#### copy the apps to the http server root directory
```
sudo cp -v pnda-dist/* /var/www/html
sudo chmod -v a+r /var/www/html/*
```

## Next

[Create PNDA](create-pnda.md)
