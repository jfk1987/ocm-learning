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
source="${target}.descriptor-source"

[[ -f "$constructor" ]] || { echo "Constructor fehlt: $constructor" >&2; exit 1; }
[[ -d "$working_dir" ]] || { echo "Arbeitsverzeichnis fehlt: $working_dir" >&2; exit 1; }
if [[ -e "$source" || -e "$target" ]]; then
  echo "Ziel existiert bereits. Bitte einen neuen, leeren Ausgabepfad wählen: $target" >&2
  exit 1
fi

ocm add component-version --repository "ctf::${source}" --constructor "$constructor" --working-directory "$working_dir"
ocm transfer component-version "ctf::${source}//${component}:${version}" "ctf::${target}" --copy-resources --upload-as localBlob
ocm get component-version "ctf::${target}//${component}:${version}"

echo "Selbstständiges CTF erstellt: ${target}"
