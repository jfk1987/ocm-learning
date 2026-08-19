#!/usr/bin/env bash
# Creates lab keys and separate OCM configurations for signer and
# verifier. The private material must not leave the connected station.
set -euo pipefail

if (($# != 1)); then
  echo "Usage: $0 <output-directory>" >&2
  exit 64
fi

output=$1
private_key="${output}/private-key.pem"
public_key="${output}/public-key.pem"
signer_config="${output}/signer.ocmconfig"
verifier_config="${output}/verifier.ocmconfig"

for file in "$private_key" "$public_key" "$signer_config" "$verifier_config"; do
  [[ ! -e "$file" ]] || { echo "Output already exists: ${file}" >&2; exit 1; }
done
command -v openssl >/dev/null 2>&1 || { echo 'openssl is missing.' >&2; exit 1; }

mkdir -p "$output"
output_absolute=$(cd "$output" && pwd)
private_key="${output_absolute}/private-key.pem"
public_key="${output_absolute}/public-key.pem"
signer_config="${output_absolute}/signer.ocmconfig"
verifier_config="${output_absolute}/verifier.ocmconfig"

openssl genpkey -algorithm RSA -out "$private_key" \
  -pkeyopt rsa_keygen_bits:4096
openssl rsa -in "$private_key" -pubout -out "$public_key"
chmod 600 "$private_key"

cat > "$signer_config" <<EOF
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    consumers:
      - identity:
          type: RSA/v1alpha1
          algorithm: RSASSA-PSS
          signature: default
        credentials:
          - type: RSACredentials/v1
            privateKeyPEMFile: ${private_key}
            publicKeyPEMFile: ${public_key}
EOF

cat > "$verifier_config" <<EOF
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    consumers:
      - identity:
          type: RSA/v1alpha1
          algorithm: RSASSA-PSS
          signature: default
        credentials:
          - type: RSACredentials/v1
            publicKeyPEMFile: ${public_key}
EOF

chmod 600 "$signer_config"
echo "Signer configuration: ${signer_config}"
echo "Verifier configuration: ${verifier_config}"
echo "Only public-key.pem and verifier.ocmconfig may be copied into the target zone."
