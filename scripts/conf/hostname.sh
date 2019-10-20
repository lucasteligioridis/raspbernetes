#!/bin/bash
set -euo pipefail

echo "Setting hostname to: ${RPI_HOSTNAME}"
hostnamectl --transient set-hostname "${RPI_HOSTNAME}"
hostnamectl --static set-hostname "${RPI_HOSTNAME}"
hostnamectl --pretty set-hostname "${RPI_HOSTNAME}"
sed -i "s/raspberrypi/${RPI_HOSTNAME}/g" /etc/hosts

# restart mDNS daemon for new settings to take effect
systemctl restart avahi-daemon
