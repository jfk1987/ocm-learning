#!/usr/bin/env bash
# Erzeugt Lab-Schlüssel und getrennte OCM-Konfigurationen für Signierer und
# Prüfer. Das private Material darf die Connected Station nicht verlassen.
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
  [[ ! -e "$file" ]] || { echo "Ausgabe existiert bereits: ${file}" >&2; exit 1; }
done
command -v openssl >/dev/null 2>&1 || { echo 'openssl fehlt.' >&2; exit 1; }

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
echo "Signier-Konfiguration: ${signer_config}"
echo "Prüf-Konfiguration: ${verifier_config}"
echo "Nur public-key.pem und verifier.ocmconfig dürfen in die Zielzone."
