#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

OPENSHIFT_NETWORK_PLUGIN=cni
config_path="/data/cluster"
host="$(hostname)"
node_config_path="${config_path}/${host}"
node_config_file="${node_config_path}/node-config.yaml"

function ensure-node-config() {

  if [[ -f "${node_config_file}" ]]; then
    # Config has already been deployed and they have not removed the node config to indicate a regen is needed
    return
  fi
  # If the node config has not been generated
  if [[ ! -f "${node_config_file}" ]]; then
    local master_config_path="${config_path}/master"
    local master_config_file="${master_config_path}/admin.kubeconfig"

    if [[ ! -f "${master_config_file}" ]]; then
	echo "Master config file not available to generate node config"
	exit 1
    fi

    local master_host
    master_host="$(grep server "${master_config_file}" | grep -v localhost | awk '{print $2}')"

    local ip_addr=$(/usr/local/bin/openshift start master --print-ip)

    # Hold a lock on the shared volume to ensure cert generation is
    # performed serially.  Cert generation is not compatible with
    # concurrent execution since the file passed to --signer-serial
    # needs to be incremented by each invocation.
    (flock 200;
     /usr/local/bin/oc adm create-node-config \
       --node-dir="${node_config_path}" \
       --node="${host}" \
       --master="${master_host}" \
       --dns-ip="172.30.0.1" \
       --hostnames="${host},${ip_addr}" \
       --network-plugin="${OPENSHIFT_NETWORK_PLUGIN}" \
       --node-client-certificate-authority="${master_config_path}/ca.crt" \
       --certificate-authority="${master_config_path}/ca.crt" \
       --signer-cert="${master_config_path}/ca.crt" \
       --signer-key="${master_config_path}/ca.key" \
       --signer-serial="${master_config_path}/ca.serial.txt"
    ) 200>"${config_path}"/.openshift-ca.lock

    cat >> "${node_config_file}" <<EOF
kubeletArguments:
  cgroups-per-qos: ["false"]
  enforce-node-allocatable: [""]
  fail-swap-on: ["false"]
  eviction-soft: [""]
  eviction-hard: [""]
EOF
  fi

  # Ensure the configuration is readable outside of the container
  chmod -R ga+rX "${node_config_path}"
}

function run-hyperkube() {
  local flags=$( /usr/local/bin/openshift-node-config "--config=${node_config_file}" )

  eval "exec /usr/local/bin/hyperkube kubelet --v=${DEBUG_LOGLEVEL:-4} ${flags}"
}

ensure-node-config
run-hyperkube
