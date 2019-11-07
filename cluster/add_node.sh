#!/bin/bash

if [[ "${CONFIG_ROOT}" = "/" ]]; then
  CONFIG_ROOT=""
fi

DEFAULT_NETWORK_PLUGIN=cni
DEFAULT_SERVER_CONFIG_DIR=${CONFIG_ROOT}/openshift.local.config
DEFAULT_VOLUMES_DIR=/var/lib/openshift.local.volumes

NETWORK_PLUGIN="${NETWORK_PLUGIN:-${DEFAULT_NETWORK_PLUGIN}}"
SERVER_CONFIG_DIR="${SERVER_CONFIG_DIR:-${DEFAULT_SERVER_CONFIG_DIR}}"
VOLUMES_DIR="${VOLUMES_DIR:-${DEFAULT_VOLUMES_DIR}}"

function usage() {
    echo "Usage: $0 [options]
    -m  Master IP (required)
    -n  Node IP (required)
    -i  Node name (required)
    -c  Master certificate directory (required)

 The following environment variables are honored:
  - NETWORK_PLUGIN: Network plugin name. Default: ${DEFAULT_NETWORK_PLUGIN}
  - SERVER_CONFIG_DIR: Configuration directory. Default: ${DEFAULT_SERVER_CONFIG_DIR}
  - VOLUMES_DIR: Volumes directory. Default: ${DEFAULT_VOLUMES_DIR}
  "
}

MASTER_IP=
NODE_IP=
NODE_NAME=
CERT_DIR=
while getopts "m:n:i:c:" opt; do
    case $opt in
        m)
            MASTER_IP="${OPTARG}"
            ;;
        n)
            NODE_IP="${OPTARG}"
            ;;
        i)
            NODE_NAME="${OPTARG}"
            ;;
        c)
            CERT_DIR="${OPTARG}"
            ;;
        *)
            usage
            exit 1
    esac
done

if [ ! "${MASTER_IP}" ] || [ ! "${NODE_IP}" ] || [ ! "${NODE_NAME}" ] || [ ! "${CERT_DIR}" ]; then
    usage
    exit 1
fi

pushd "${CONFIG_ROOT}" > /dev/null

openshift admin create-node-config \
      --node-dir="${SERVER_CONFIG_DIR}/${NODE_NAME}" \
      --node="${NODE_NAME}" \
      --hostnames="${NODE_NAME},${NODE_IP}" \
      --master="https://${MASTER_IP}:8443" \
      --network-plugin="${NETWORK_PLUGIN}" \
      --node-client-certificate-authority="${CERT_DIR}/ca.crt" \
      --certificate-authority="${CERT_DIR}/ca.crt" \
      --signer-cert="${CERT_DIR}/ca.crt" \
      --signer-key="${CERT_DIR}/ca.key" \
      --signer-serial="${CERT_DIR}/ca.serial.txt" \
      --volume-dir="${VOLUMES_DIR}"

popd > /dev/null
