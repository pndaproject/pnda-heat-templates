#!/bin/bash

set -x
openstack flavor create --ram 4096 --disk 250 --vcpus 1 p.pico
openstack flavor create --ram 4096 --disk 500 --vcpus 2 p.nano
openstack flavor create --ram 8192 --disk 50 --vcpus 2 p.micro
openstack flavor create --ram 8192 --disk 50 --vcpus 4 p.tiny
openstack flavor create --ram 16384 --disk 50 --vcpus 4 p.small
openstack flavor create --ram 16384 --disk 250 --vcpus 4 p.medium
openstack flavor create --ram 16384 --disk 250 --vcpus 8 p.large
openstack flavor create --ram 32768 --disk 250 --vcpus 8 p.xlarge
