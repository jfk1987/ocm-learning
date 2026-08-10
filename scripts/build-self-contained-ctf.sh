#!/usr/bin/env bash
# Erstellt aus einem Component Constructor ein CTF, das alle referenzierten
# Ressourcen als lokale Blobs enthält. Nur auf der Connected Station ausführen.
set -euo pipefail

if (($# != 5)); then
  echo "Usage: $0 <constructor.yaml> <working-directory> <component-name> <component-version> <output-ctf-dir>" >&2
  exit 64
fi

constructor=$1
working_dir=$2
component=$3
version=$4
target=$5

[[ -f "$constructor" ]] || { echo "Constructor fehlt: $constructor" >&2; exit 1; }
[[ -d "$working_dir" ]] || { echo "Arbeitsverzeichnis fehlt: $working_dir" >&2; exit 1; }
constructor=$(cd "$(dirname "$constructor")" && pwd)/$(basename "$constructor")
working_dir=$(cd "$working_dir" && pwd)
mkdir -p "$(dirname "$target")"
target=$(cd "$(dirname "$target")" && pwd)/$(basename "$target")
source="${target}.descriptor-source"
if [[ -e "$source" || -e "$target" ]]; then
  echo "Ziel existiert bereits. Bitte einen neuen, leeren Ausgabepfad wählen: $target" >&2
  exit 1
fi

(cd "$working_dir" && ocm add component-version \
  --repository "ctf::${source}" --constructor "$constructor")
ocm transfer component-version "ctf::${source}//${component}:${version}" "ctf::${target}" --recursive --copy-resources --upload-as localBlob
ocm get component-version "ctf::${target}//${component}:${version}"

echo "Selbstständiges CTF erstellt: ${target}"
