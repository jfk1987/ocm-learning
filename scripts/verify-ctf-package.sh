#!/usr/bin/env bash
# Verifies a transported CTF package and extracts it only after a successful hash check.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <ctf.tgz> <destination-directory>" >&2
  exit 64
fi

package=$1
destination=$2
checksum="${package}.sha256"
[[ -f "$package" ]] || { echo "Package missing: $package" >&2; exit 1; }
[[ -f "$checksum" ]] || { echo "Package checksum missing: $checksum" >&2; exit 1; }
mkdir -p "$destination"

package_parent=$(cd "$(dirname "$package")" && pwd)
package_name=$(basename "$package")
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$package_parent" && sha256sum -c "${package_name}.sha256")
else
  expected=$(awk '{print $1}' "$checksum")
  actual=$(shasum -a 256 "$package" | awk '{print $1}')
  [[ "$expected" == "$actual" ]] || { echo 'SHA-256 verification failed.' >&2; exit 1; }
  echo "${package_name}: OK"
fi
tar -C "$destination" -xzf "$package"
echo "CTF verified and extracted: ${destination}"
