#!/usr/bin/env bash

export privkey_file="flux-oci.key"
export pubkey_file="flux-oci.crt"

export secret_name="sealed-secrets-key-fluxcd"
export secret_ns="sealed-secrets"

openssl req -x509 -nodes -newkey rsa:4096 -keyout "$privkey_file" -out "$pubkey_file" -subj "/CN=sealed-secret/O=sealed-secret"

kubectl -n "$secret_ns" create secret tls "$secret_name" --cert="$pubkey_file" --key="$privkey_file"
kubectl -n "$secret_ns" label secret "$secret_name" sealedsecrets.bitnami.com/sealed-secrets-key=active

kubectl -n "$secret_ns" delete pod -l name=sealed-secrets-controller
