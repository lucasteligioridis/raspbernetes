#!/bin/bash
set -euo pipefail

keepalived_version="1:2.0.10-1"

echo "Installing keepalived ${keepalived_version}..."
apt-get install -y --no-install-recommends "keepalived=${keepalived_version}"
apt-mark hold keepalived

# figure out a priority level based on IP
if [[ "${RPI_IP}" == "${KUBE_MASTER_IP_01}" ]]; then
  priority=150
elif [[ "${RPI_IP}" == "${KUBE_MASTER_IP_02}" ]]; then
  priority=100
else
  priority=50
fi

# generate configuration file
cat <<EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    interface ${RPI_NETWORK_TYPE}
    virtual_router_id 1
    priority ${priority}
    advert_int 1
    nopreempt
    authentication {
        auth_type AH
        auth_pass kubernetes
    }
    virtual_ipaddress {
        ${KUBE_MASTER_VIP}
    }
}
EOF

# enable and start keepalived
systemctl enable --now keepalived
