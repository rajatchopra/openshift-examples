#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

function ensure-master-config() {
  local config_path="/data/cluster"
  local master_path="${config_path}/master"
  local config_file="${master_path}/master-config.yaml"

  if [[ -f "${config_file}" ]]; then
    # Config has already been generated
    return
  fi

  local name
  name="$(hostname)"
  local serving_ip_addr="$(/usr/local/bin/openshift start master --print-ip)"

  mkdir -p "${config_path}"
  (flock 200;
   /usr/local/bin/oc adm ca create-master-certs \
     --overwrite=false \
     --cert-dir="${master_path}" \
     --master="https://${serving_ip_addr}:8443" \
     --hostnames="${serving_ip_addr},${name}"

   /usr/local/bin/openshift start master --write-config="${master_path}" \
     --master="https://${serving_ip_addr}:8443" \
     --network-plugin=cni
  ) 200>"${config_path}"/.openshift-ca.lock

  # ensure the configuration can be used outside of the container
  chmod -R ga+rX "${master_path}"
  chmod ga+w "${master_path}/admin.kubeconfig"
}

ensure-master-config
