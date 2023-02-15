#!/usr/bin/env bash

script_dir=$(
  cd -- "$(dirname "$0")" &> /dev/null
  pwd -P
)

cf_v4_addrs=$(curl -fsSL 'https://www.cloudflare.com/ips-v4')
cf_v6_addrs=$(curl -fsSL 'https://www.cloudflare.com/ips-v6')
trusted_proxy_addrs=(
  '10.0.0.0/8'
  '172.16.0.0/12'
  '192.168.0.0/16'
  ${cf_v4_addrs}
  ${cf_v6_addrs}
)

# generate json array of all cloudflare IPs and rfc1918 addresses
printf '%s\n' "${trusted_proxy_addrs[@]}" |
  jq -nR "[ inputs | select(length>0) ]" \
    > "${script_dir}/cloudflare-ips.json"

# generate patch file for traefik helm chart
patch='[
  { "op": "add", "path": "/spec/values/ports/websecure/forwardedHeaders/trustedIPs", "value": . },
  { "op": "copy", "from": "/spec/values/ports/websecure/forwardedHeaders/trustedIPs", "path": "/spec/values/ports/web/forwardedHeaders/trustedIPs" }
]'

jq "$patch" "${script_dir}/cloudflare-ips.json" |
  yq -y '.' \
    > "${script_dir}/../../cluster/traefik/patch-ports-trusted-ips.yaml"

# and for traefik middleware
patch='[
  { "op": "add", "path": "/spec/ipWhiteList/ipStrategy/excludedIPs", "value": . }
]'

jq "$patch" "${script_dir}/cloudflare-ips.json" |
  yq -y '.' \
    > "${script_dir}/../../cluster/traefik/patch-ipwhitelist-excluded-ips.yaml"
