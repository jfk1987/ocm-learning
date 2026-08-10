#!/usr/bin/env bash
# Verpackt ein CTF portabel und erzeugt eine relative SHA-256-Prüfsumme.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <ctf-directory> <output-tgz>" >&2
  exit 64
fi

ctf=$1
output=$2
[[ -d "$ctf" ]] || { echo "CTF fehlt: $ctf" >&2; exit 1; }
[[ ! -e "$output" && ! -e "${output}.sha256" ]] || {
  echo "Ausgabe existiert bereits: ${output} oder ${output}.sha256" >&2
  exit 1
}

parent=$(cd "$(dirname "$ctf")" && pwd)
name=$(basename "$ctf")
mkdir -p "$(dirname "$output")"
output_parent=$(cd "$(dirname "$output")" && pwd)
output_name=$(basename "$output")
tar -C "$parent" -czf "$output" "$name"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$output_parent" && sha256sum "$output_name" > "${output_name}.sha256")
else
  (cd "$output_parent" && shasum -a 256 "$output_name" > "${output_name}.sha256")
fi

echo "Transportpaket: ${output}"
echo "Prüfsumme: ${output}.sha256"
