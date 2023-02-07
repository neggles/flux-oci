#!/usr/bin/env bash

# This script is used to seal a secret for use in the cluster.
# It requires kubeseal to be installed and configured.

secret_name=${1:?'Secret name is required'}
secret_namespace=${2:?'Secret namespace is required'}
secret_data=${3:?'Secret data is required'}

# Get the directory of this script
script_dir=$(
    cd -- "$(dirname "$0")" &> /dev/null
    pwd -P
)
# path to pubkey file
pubkey_file="${script_dir}/flux-oci.pem"

# work out where we should put this thing
service_namespace_dir="${script_dir}/../services/${secret_namespace}"
cluster_namespace_dir="${script_dir}/../cluster/${secret_namespace}"

if [[ -d ${service_namespace_dir} ]]; then
    namespace_dir="${service_namespace_dir}"
elif [[ -d ${cluster_namespace_dir} ]]; then
    namespace_dir="${cluster_namespace_dir}"
else
    echo "No directory found for namespace ${secret_namespace}"
    exit 1
fi

# actually seal the secret lol
kubectl create secret generic ${secret_name} \
    --namespace ${secret_namespace} \
    --from-literal=${secret_data} -o json |
    kubeseal --cert ${pubkey_file} -o yaml \
        > "${namespace_dir}/sealedsecret-${secret_name}.yaml"
