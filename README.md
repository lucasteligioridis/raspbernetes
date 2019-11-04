# Raspbernetes

Automated and repeatable method of deploying a headless Kubernetes stack
onto a cluster of Raspberry Pis. Completely hands off experience from
power on.

Detailed blog and guide posted onto my medium account:
- <post of medium link blog>

## Prerequisites

The following tools and pre-requisites must be available on the machine being
used to build the SD cards:

- Linux - Because of filesystem requirements
- `bash` - 4.0+
- `make` - 4.1+
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - 1.16.1
- 4 Raspberry Pis (3 Masters and 1 Worker)

## Applications

This stack is an opinionated way to deploy a home cluster with a HA design
using `haproxy` and `keepalived` for cluster management.

See below for a list of the versions and applications used:

- [Raspbian](https://downloads.raspberrypi.org/raspbian_lite/images/) - raspbian_lite-2019-09-30
- [Kubernetes](https://kubernetes.io/) - 1.16.1
- [Docker](https://www.docker.com/) - 18.09.0
- [HA Proxy](http://www.haproxy.org/) - 1.8.19
- [Keepalived](https://www.keepalived.org/) - 2.0.10
- [Flannel](https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml) - As per instructions on kubeadm installation page

## Configuration

A short explanation of each environment variable that can be overridden.

### Environment Settings

#### Mount device configuration:

- `MNT_DEVICE` - Device name of SD slot on your local machine. (default: `/dev/mmcblk0`)

#### Raspberry Pi network and hostname configuration:

- `RPI_NETWORK_TYPE` - Network option of choice. Either `eth0` or `wlan0`. (default: `wlan0`)
- `RPI_HOSTNAME` - Hostname for specific Raspberry Pi. (default: `rpi-kube-master-01`)
- `RPI_IP` - Static IP to set. (default: `192.168.1.101`)
- `RPI_DNS` - DNS or Gateway. Generally your router ip. (default: `192.168.1.1`)
- `RPI_TIMEZONE` - Local timezone. (default: `Australia/Melbourne`)

#### Kubernetes specific configuration:

- `KUBE_NODE_TYPE` - Type of Kubernetes node. Either `master` or `worker`. (default: `master`)
- `KUBE_MASTER_VIP` - Floating virtual IP (VIP) to use in `keepalived`. (default: `192.168.1.100`)
- `KUBE_MASTER_IP_01` - IP of 1st master node to use in `haproxy`. (default: `192.168.1.101`)
- `KUBE_MASTER_IP_02` - IP of 2nd master node to use in `haproxy`. (default: `192.168.1.102`)
- `KUBE_MASTER_IP_03` - IP of 3rd master node to use in `haproxy`. (default: `192.168.1.103`)

#### Network configuration if using Wifi. Accompanied with `RPI_NETWORK_TYPE` of `wlan0`:

- `WIFI_SSID` - Local SSID to connect Wifi to. (default: `n/a`)
- `WIFI_PASSWORD` - Password of above SSID to connect to Wifi using wpa_supplicant. (default: `n/a`)

### Build

Once appropriate above environment variables have been exported to suit your
specific local environment, the below command will build an SD card with
all automation scripts:

```bash
make build
```

### Help

The help target is set as the default target, so display the above brief
descriptions. Use the below command as is to print to the terminal:

```bash
make
```
