#!/bin/bash -v

# This script runs on all instances 

set -e

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[iplog] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## And log all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[iplog] " --log-level 7 -m state --state NEW
