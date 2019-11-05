#!/bin/bash
set -euo pipefail

echo "Installing ebtables and arptables..."
apt-get update
apt-get install -y ebtables arptables

echo "Setting to use legacy tables for compatibility issues"
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy

# enable netfilter on bridges
cat << EOF >> /etc/sysctl.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-arptables=1
EOF

# reload sysctl
modprobe br_netfilter
sysctl -p
