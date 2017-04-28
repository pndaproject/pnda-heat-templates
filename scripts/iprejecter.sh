#!/bin/bash -v

# This script runs on all instances 

set -e

declare -A conf=( )
declare -A specific=( $$SPECIFIC_CONF$$ )

# Override default configuration
for key in "${!specific[@]}"; do conf[$key]="${specific[${key}]}"; done

# built the white list ip address
## mirror ntp and dns servers are white listed
MIRRORSERVER=$(echo '$pnda_mirror$' | awk -F/ '{print $3}' | awk -F: '{print $1}')
NTPSERVER=$(echo '$ntp_servers$' | awk '{print $1}')
KEYSTONE=$(echo '$keystone_auth_url$' | awk -F/ '{print $3}' | awk -F: '{print $1}')
DNSLIST=$(cat /etc/resolv.conf  | grep -E -o  "([0-9]{1,3}[\.]){3}[0-9]{1,3}")

if [ "x$platform_git_repo_uri$" != "x" ]; then
  PLATFORMSERVER=$(echo '$platform_git_repo_uri$'| awk -F/ '{print $3}' | awk -F: '{print $1}')
elif [ "x$platform_uri$" != "x" ] ; then
  PLATFORMSERVER=$(echo '$platform_uri$'| awk -F/ '{print $3}' | awk -F: '{print $1}')
else 
  exit 2
fi
LIST=( "${MIRRORSERVER[@]}" "${NTPSERVER[@]}" "${KEYSTONE[@]}" "${PLATFORMSERVER[@]}" )

## resolve FQN's
WHITELIST=()
for name in ${LIST[@]}
do
  if [[ $name =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    WHITELIST+=($name)
  else
    WHITELIST+=($(dig +short $name))
  fi
done
WHITELIST+=(${DNSLIST[@]})

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[ipreject] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## Accept whitelisted IP connections.
  for line in ${WHITELIST[@]}; do
iptables -A LOGGING -d  $line -j ACCEPT
  done 
## Log and reject all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[ipreject] " --log-level 7 -m state --state NEW
iptables -A LOGGING -j REJECT
