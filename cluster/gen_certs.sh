#!/bin/bash

NODE_IPS="10.19.17.72,10.19.17.115"
MASTER_IP="10.19.17.72"


INSTANCE_PREFIX="openshift"
NODE_IPS=(${NODE_IPS//,/ })
if [[ "${CONFIG_ROOT}" = "/" ]]; then
  CONFIG_ROOT=""
fi

NETWORK_PLUGIN=${NETWORK_PLUGIN:-cni}

MASTER_NAME="${INSTANCE_PREFIX}-master"
NODE_PREFIX="${INSTANCE_PREFIX}-node-"
NODE_COUNT=2
NODE_NAMES=( $(eval echo ${NODE_PREFIX}{1..${NODE_COUNT}}) )

initcerts() {
  local config_root=$1
  local network_plugin=$2
  local master_name=$3
  local master_ip=$4
  local node_ips=(${NODE_IPS[@]})
  local node_names=(${NODE_NAMES[@]})

  echo "${node_ips[@]}"
  echo "${node_names[@]}"
  local server_config_dir=${config_root}/openshift.local.config
  local volumes_dir="/var/lib/openshift.local.volumes"
  local cert_dir="${server_config_dir}/master"

  pushd "${config_root}" > /dev/null

  # Master certs
  oc adm ca create-master-certs \
    --overwrite=false \
    --cert-dir="${cert_dir}" \
    --master="https://${master_ip}:8443" \
    --hostnames="${master_ip},${master_name}"

  # master config file
  openshift start master --write-config=${cert_dir} --network-plugin=${network_plugin}

  # Certs for nodes
  for (( i=0; i < ${#node_names[@]}; i++ )); do
    local name=${node_names[$i]}
    local ip=${node_ips[$i]}
    oc adm create-node-config \
      --node-dir="${server_config_dir}/${name}" \
      --node="${name}" \
      --hostnames="${name},${ip}" \
      --master="https://${master_ip}:8443" \
      --network-plugin="${network_plugin}" \
      --node-client-certificate-authority="${cert_dir}/ca.crt" \
      --certificate-authority="${cert_dir}/ca.crt" \
      --signer-cert="${cert_dir}/ca.crt" \
      --signer-key="${cert_dir}/ca.key" \
      --signer-serial="${cert_dir}/ca.serial.txt" \
      --volume-dir="${volumes_dir}"
  done

  popd > /dev/null

  # Indicate to nodes that it's safe to begin provisioning by removing
  # the stale marker.
  rm -f ${config_root}/openshift.local.config/.stale
}

echo "
initcerts \"${CONFIG_ROOT}\" \"${NETWORK_PLUGIN}\" \
  \"${MASTER_NAME}\" \"${MASTER_IP}\" \"${NODE_IPS[@]}\"
"

initcerts "${CONFIG_ROOT}" "${NETWORK_PLUGIN}" \
  "${MASTER_NAME}" "${MASTER_IP}" "${NODE_IPS[@]}"
