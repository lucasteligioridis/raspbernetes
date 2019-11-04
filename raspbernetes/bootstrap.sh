#!/bin/bash
set -euo pipefail

# change to directory where bootstrap lives
cd "${0%/*}"

# source the environment variables for hostname, IP addresses and node type
# shellcheck disable=SC1091
source ./rpi-env

# set default hostname
./conf/hostname.sh

echo "Waiting for system to boot before attempting to install packages..."
sleep 30

# install system dependencies in order
./install/utils.sh
./install/iptables.sh
./install/docker.sh
./install/kubernetes.sh

# only install some components on master nodes
if [ "${KUBE_NODE_TYPE}" == "master" ]; then
  ./install/keepalived.sh
  ./install/haproxy.sh
fi

# configure kubernetes with node type and/or initialising cluster
./conf/kubernetes.sh

# ensure bootstrap scripts don't run again on boot and clean
sed -i "/bootstrap.sh/d" /etc/rc.local
rm -rf /home/pi/bootstrap

echo "Finished booting! Kubernetes successfully running!"
