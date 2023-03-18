#!/usr/bin/env bash

# Cmdline arguments. The first is the key name, the second is the key comment.
key_name=${1:?"Usage: $0 <cluster/key name> <comment>"}
key_comment=${2:?"Usage: $0 <cluster/key name> <comment>"}

### Configuration, edit if you want to change the key parameters
# Defaults are 4096 bit RSA keys that never expire.
# See https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
# for more information on the options.
key_type="1"         # 1 = RSA
key_length="4096"    # 4096 bit key
subkey_type="1"      # 1 = RSA
subkey_length="4096" # 4096 bit key
key_expires="0"      # 0 = never expire

### Execution
# Find the parent directory of this script, thanks StackOverflow
script_dir=$(
    cd -- "$(dirname "$0")" &> /dev/null
    pwd -P
)

# Make sure `gpg` exists. We don't know if it'll actually *work*, but, yolo
echo -n "Checking for GPG availability... "
if [ "$(command -v command)" ]; then
    echo "found: $(gpg --version | head -n 1)"
else
    echo -e "No gpg found on PATH.\nPlease install gnupg2 and try again."
    exit 1
fi

# Set up GPG homedir
gpg_home=${script_dir}/gpg-home
echo "Setting GPG home dir to ${gpg_home}"

# check for existing homedir
if [[ -d ${gpg_home} ]]; then
    echo "GPG home dir already exists, will not delete existing keys!"
    echo "If you want to generate a new key, delete the existing GPG home dir: ${gpg_home}"
    exit 1
fi

echo "Creating GPG home dir and setting GNUPGHOME env var."
mkdir -p ${gpg_home}
chmod 700 ${gpg_home}
export GNUPGHOME=${gpg_home}
echo -e "export GNUPGHOME=${GNUPGHOME}\nto use this key in the future."

# do the actual generation
echo "Generating new SOPS GPG key: $key_name ($key_comment)"
gpg --batch --full-generate-key << EOF
%no-protection
Key-Type: ${key_type}
Key-Length: ${key_length}
Subkey-Type: ${subkey_type}
Subkey-Length: ${subkey_length}
Expire-Date: ${key_expires}
Name-Comment: ${key_comment}
Name-Real: ${key_name}
%commit
%echo done
EOF

# grab the fingerprint of the generated key, export to SOPS_KEY_FP env var
key_fp=$(gpg --list-secret-keys | sed -n '/sec/{n;s/[[:space:]]*//p}')
echo "Generated key with fingerprint: ${key_fp}"
echo "export SOPS_KEY_FP=${key_fp}" >> ${script_dir}/../env.sh
# and save to sops.asc file in script dir
echo "Exporting key to ${script_dir}/sops-key.asc"
gpg --armor --export ${key_fp} > ${script_dir}/sops-key.asc

# and make a kube secret you can apply
echo "Generating kubernetes secret for key..."
kubectl create secret generic sops-gpg \
    --namespace flux-system \
    --from-file=sops.asc=${script_dir}/sops-key.asc \
    --dry-run=client \
    -o yaml > ${script_dir}/sops-gpg-secret.yaml

echo "Exporting public key to ${script_dir}/sops.pub.asc ..."
gpg --export --armor "${key_fp}" -o "${script_dir}/sops.pub.asc"
echo "Copying to cluster common directory at ${script_dir}/../../common/sops.pub.asc ..."
cp "${script_dir}/sops.pub.asc" "${script_dir}/../../common/sops.pub.asc"

echo "Done! You can now apply the generated secret with 'kubectl apply -f ${script_dir}/sops-gpg-secret.yaml' and use the key with SOPS."
echo "Remember to delete the unencrypted key file: ${script_dir}/sops-key.asc and the GPG homedir ${script_dir}/gpg-home/ after applying the secret."
echo "and Import the public key into your keyring with 'gpg --import ${script_dir}/../../common/sops.pub.asc' to use it for SOPS encryption."
