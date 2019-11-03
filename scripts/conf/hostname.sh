#!/bin/bash
set -euo pipefail

echo "Setting hostname to: ${RPI_HOSTNAME}"
hostnamectl --transient set-hostname "${RPI_HOSTNAME}"
hostnamectl --static set-hostname "${RPI_HOSTNAME}"
hostnamectl --pretty set-hostname "${RPI_HOSTNAME}"
sed -i "s/raspberrypi/${RPI_HOSTNAME}/g" /etc/hosts

# set timezone
timedatectl set-timezone "${RPI_TIMEZONE}"

# cron and rsyslog require a restart for timezone settings to take affect
systemctl restart cron
systemctl restart rsyslog

# restart mDNS daemon for new settings to take effect
systemctl restart avahi-daemon
