#!/bin/bash
set -euo pipefail

flannel_version="2140ac876ef134e0ed5af15c65e414cf26827915"
flannel_url="https://raw.githubusercontent.com/coreos/flannel/${flannel_version}/Documentation/kube-flannel.yml"
ssh_control_plane="ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/pi/.ssh/id_ed25519 pi@${KUBE_MASTER_VIP}"
kube_finished="/home/pi/kube-finished-booting"

cluster_up() {
  echo "Checking to see if control-plane has been fully initialised..."
  echo "This could take up to 10 minutes..."

  count=0
  while ! ${ssh_control_plane} test -f "${kube_finished}"; do
    echo "[${count}] Cluster still not up, sleeping for 10 seconds"
    sleep 10
    count=$((count+1))
  done

  echo "Kubernetes control-plane has finished initalising!"
  echo "Attempting to join cluster!"
}

get_kube_certs() {
  local join_command=${1}
  token_cert_hash=$(echo "${join_command}" | cut -d ' ' -f3-)

  # keep looping until our certificates have been downloaded
  until test -d /etc/kubernetes/pki/etcd/; do
    # upload certs again with new certificate key
    certificate_key=$(${ssh_control_plane} kubeadm alpha certs certificate-key)
    ${ssh_control_plane} sudo kubeadm init phase upload-certs \
      --upload-certs \
      --certificate-key "${certificate_key}"

    # attempt to download certs, need to retry incase of race condition
    # with other masters clobbering the certificate_key secret
    # shellcheck disable=SC2086
    kubeadm join phase control-plane-prepare download-certs ${token_cert_hash} \
      --certificate-key "${certificate_key}" \
      --control-plane || continue
  done
}

get_kube_config() {
  mkdir -p "/root/.kube"
  mkdir -p "/home/pi/.kube"
  cp -i /etc/kubernetes/admin.conf "/root/.kube/config"
  cp -i /etc/kubernetes/admin.conf "/home/pi/.kube/config"
  chown -R "$(id -u):$(id -g)" "/root/.kube"
  chown -R "$(id -u pi):$(id -g pi)" "/home/pi/"
  kubectl completion bash > /etc/bash_completion.d/kubectl
}

check_kube_master() {
  if curl -sSLk "https://${KUBE_MASTER_VIP}:6443" -o /dev/null; then
    echo "Control-plane has been found! Joining existing cluster as master."
    join_kube_master
  else
    if hostname -I | grep "${KUBE_MASTER_VIP}"; then
      echo "VIP currently resides on local host and no cluster exists."
      echo "Initialising as new Kubernetes cluster"
      init_kube_master
    else
      echo "Did not win VIP election, joining existing cluster."
      join_kube_master
    fi
  fi
}

init_kube_master() {
  # initialise kubernetes cluster
  kubeadm init \
    --apiserver-cert-extra-sans "${KUBE_MASTER_VIP}" \
    --pod-network-cidr "10.244.0.0/16" \
    --control-plane-endpoint "${KUBE_MASTER_VIP}:6443" \
    --skip-token-print \
    --skip-certificate-key-print

  # setup flannel
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f "${flannel_url}"
  get_kube_config

  # let other nodes know that the cluster has successfully booted
  touch "${kube_finished}"
}

join_kube_master() {
  # ensure the cluster is given enough time to initialise
  cluster_up

  # get kubeadm join command and download certs from master
  join_command=$(${ssh_control_plane} kubeadm token create --print-join-command)
  get_kube_certs "${join_command}"

  # join cluster and make master
  ${join_command} --control-plane
  get_kube_config

  # let other nodes know that the cluster has successfully booted
  touch "${kube_finished}"
}

join_kube_worker() {
  # ensure the cluster is given enough time to initialise
  cluster_up

  # get kubeadm join command from master
  join_command=$(${ssh_control_plane} kubeadm token create --print-join-command)
  ${join_command}

  # let other nodes know that the cluster has successfully booted
  touch "${kube_finished}"
}

# determine the node type and run specific function
if [ "${KUBE_NODE_TYPE}" == "master" ]; then
  echo "Detected as master node type, need to either join existing cluster or initialise new one"
  check_kube_master
elif [ "${KUBE_NODE_TYPE}" == "worker" ]; then
  echo "Detected as worker node type, need to join existing cluster!"
  join_kube_worker
fi
