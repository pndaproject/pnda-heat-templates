#!/bin/bash -v

# This script runs on the bastion instance
# It generates the ssh key used to access the rest of
# the instances

set -e

KEY="$private_key$"
KEYNAME=$keyname$

if [ "x$KEYNAME" != "x" ];
then
printf "%b" "$KEY" > /home/cloud-user/$KEYNAME.pem
chown cloud-user:cloud-user /home/cloud-user/$KEYNAME.pem
chmod 600 /home/cloud-user/$KEYNAME.pem
unset KEY KEYNAME
fi
