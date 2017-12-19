#!/bin/bash -v

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
