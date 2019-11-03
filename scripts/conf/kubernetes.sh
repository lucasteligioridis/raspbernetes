#!/bin/bash
set -euo pipefail

flannel_version="2140ac876ef134e0ed5af15c65e414cf26827915"
flannel_url="https://raw.githubusercontent.com/coreos/flannel/${flannel_version}/Documentation/kube-flannel.yml"
pi_home="/home/pi"
kube_finished="${pi_home}/kube-finished-booting"

etcdctl_cmd() {
  remote_control_plane \
    kubectl exec "etcd-\${HOSTNAME}" -n kube-system -- \
      etcdctl \
        --endpoints https://localhost:2379 \
        --ca-file /etc/kubernetes/pki/etcd/ca.crt \
        --cert-file /etc/kubernetes/pki/etcd/server.crt \
        --key-file /etc/kubernetes/pki/etcd/server.key \
        "${@}"
}

remote_control_plane() {
  ssh \
    -q \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -i "${pi_home}/.ssh/id_ed25519" \
    "pi@${KUBE_MASTER_VIP}" "${@}"
}

clean_node() {
  if remote_control_plane kubectl get nodes | grep -q "${HOSTNAME}" | grep -q "NotReady"; then
    echo "Deleting ${HOSTNAME} node from kubernetes cluster"
    remote_control_plane kubectl delete node "${HOSTNAME}"

    if [ "${KUBE_NODE_TYPE}" == "master" ]; then
      reset_master
    fi
  fi
}

cluster_up() {
  clean_node

  echo "Checking to see if control-plane has been fully initialised..."
  echo "This could take up to 10 minutes..."

  count=0
  until remote_control_plane test -f "${kube_finished}"; do
    echo "[${count}] Cluster still not up, sleeping for 10 seconds"
    sleep 10
    count=$((count+1))
  done

  echo "Kubernetes control-plane has finished initalising!"
  echo "Attempting to join cluster!"
}

reset_master() {
  echo "Removing master ${HOSTNAME} from existing etcd cluster"
  etcdctl_member=$(etcdctl_cmd member list | grep -q "${HOSTNAME}" | cut -d ':' -f1)
  etcdctl_cmd member remove "${etcdctl_member}"

  echo "Updating the existing kubeadm config to clear out stale host"
  remote_control_plane "kubectl get configmaps kubeadm-config -n kube-system -o yaml > /tmp/kubeadm-${HOSTNAME}.yaml"
  remote_control_plane "sed -i '/      ${HOSTNAME}/,+2 d' /tmp/kubeadm-${HOSTNAME}.yaml"
  remote_control_plane "kubectl apply -f /tmp/kubeadm-${HOSTNAME}.yaml -n kube-system"
}

get_certs() {
  local join_command=${1}
  read -ra token_cert_hash <<< "$(echo "${join_command}" | cut -d ' ' -f3-)"

  # keep looping until our certificates have been downloaded
  until test -d /etc/kubernetes/pki/etcd/; do
    # upload certs again with new certificate key
    certificate_key=$(remote_control_plane kubeadm alpha certs certificate-key)
    remote_control_plane sudo kubeadm init phase upload-certs \
      --upload-certs \
      --certificate-key "${certificate_key}"

    # attempt to download certs, need to retry incase of race condition
    # with other masters clobbering the certificate_key secret
    kubeadm join phase control-plane-prepare download-certs "${token_cert_hash[@]}" \
      --certificate-key "${certificate_key}" \
      --control-plane || continue
  done
}

get_config() {
  mkdir -p "/root/.kube"
  mkdir -p "${pi_home}/.kube"
  cp -f /etc/kubernetes/admin.conf "/root/.kube/config"
  cp -f /etc/kubernetes/admin.conf "${pi_home}/.kube/config"
  chown -R "$(id -u):$(id -g)" "/root/.kube"
  chown -R "$(id -u pi):$(id -g pi)" "${pi_home}/"
  echo "source <(kubectl completion bash)" >> "${pi_home}/.bashrc"
}

join_master() {
  if curl -sSLk "https://${KUBE_MASTER_VIP}:6443" -o /dev/null; then
    echo "Control-plane has been found! Joining existing cluster as master."
    existing_master
  elif hostname -I | grep -q "${KUBE_MASTER_VIP}"; then
    echo "VIP currently resides on local host and no cluster exists."
    echo "Initialising as new Kubernetes cluster"
    init_master
  else
    echo "Did not win VIP election, joining existing cluster."
    existing_master
  fi
}

init_master() {
  # initialise kubernetes cluster
  kubeadm init \
    --apiserver-cert-extra-sans "${KUBE_MASTER_VIP}" \
    --pod-network-cidr "10.244.0.0/16" \
    --control-plane-endpoint "${KUBE_MASTER_VIP}:6443" \
    --skip-token-print \
    --skip-certificate-key-print

  # setup flannel
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f "${flannel_url}"
}

existing_master() {
  # ensure the cluster is given enough time to initialise
  cluster_up

  # get kubeadm join command and download certs from master
  join_command=$(remote_control_plane kubeadm token create --print-join-command)
  get_certs "${join_command}"

  # join cluster as master
  ${join_command} --control-plane
}

join_worker() {
  # ensure the cluster is given enough time to initialise
  cluster_up

  # get kubeadm join command from master
  join_command=$(remote_control_plane kubeadm token create --print-join-command)
  ${join_command}
}

# determine the node type and run specific function
if [ "${KUBE_NODE_TYPE}" == "master" ]; then
  echo "Detected as master node type, need to either join existing cluster or initialise new one"
  join_master
elif [ "${KUBE_NODE_TYPE}" == "worker" ]; then
  echo "Detected as worker node type, need to join existing cluster!"
  join_worker
fi

# get kubernetes configuration and indicate finished booting
get_config
touch "${kube_finished}"
