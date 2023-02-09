#!/usr/bin/env bash

cf_ip_url='https://www.cloudflare.com/ips-v4'
cf_ip_yaml_name='cloudflare-ips.yaml'

script_dir=$(
    cd -- "$(dirname "$0")" &> /dev/null
    pwd -P
)
cf_ip_file=${script_dir}/../cluster/traefik/${cf_ip_yaml_name}
cf_ip_temp=${script_dir}/cf-temp.yaml

echo "Updating Cloudflare IPs..."

# get IP list
curl -s ${cf_ip_url} | sed 's/^/        - /' >> "${cf_ip_temp}"

# clean file and do web port
tee "${cf_ip_file}" << EOF
ports:
  web:
    forwardedHeaders:
      trustedIPs:
EOF
cat "${cf_ip_temp}" >> "${cf_ip_file}"

tee -a "${cf_ip_file}" << EOF

  websecure:
    forwardedHeaders:
      trustedIPs:
EOF
cat "${cf_ip_temp}" >> "${cf_ip_file}"

# ok done
rm "${cf_ip_temp}"
echo "Done!"
