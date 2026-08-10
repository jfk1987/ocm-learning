#!/usr/bin/env bash
# Prüft ein transportiertes CTF-Paket und entpackt es erst nach erfolgreichem Hash.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <ctf.tgz> <destination-directory>" >&2
  exit 64
fi

package=$1
destination=$2
checksum="${package}.sha256"
[[ -f "$package" ]] || { echo "Paket fehlt: $package" >&2; exit 1; }
[[ -f "$checksum" ]] || { echo "Prüfsumme fehlt: $checksum" >&2; exit 1; }
mkdir -p "$destination"

package_parent=$(cd "$(dirname "$package")" && pwd)
package_name=$(basename "$package")
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$package_parent" && sha256sum -c "${package_name}.sha256")
else
  expected=$(awk '{print $1}' "$checksum")
  actual=$(shasum -a 256 "$package" | awk '{print $1}')
  [[ "$expected" == "$actual" ]] || { echo 'SHA-256-Prüfung fehlgeschlagen.' >&2; exit 1; }
  echo "${package_name}: OK"
fi
tar -C "$destination" -xzf "$package"
echo "CTF geprüft und entpackt: ${destination}"
