#!/usr/bin/env bash
# Builds a CTF from a Component Constructor containing all referenced
# resources as local blobs. Run only on the connected station.
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

[[ -f "$constructor" ]] || { echo "Constructor missing: $constructor" >&2; exit 1; }
[[ -d "$working_dir" ]] || { echo "Working directory missing: $working_dir" >&2; exit 1; }
constructor=$(cd "$(dirname "$constructor")" && pwd)/$(basename "$constructor")
working_dir=$(cd "$working_dir" && pwd)
mkdir -p "$(dirname "$target")"
target=$(cd "$(dirname "$target")" && pwd)/$(basename "$target")
source="${target}.descriptor-source"
if [[ -e "$source" || -e "$target" ]]; then
  echo "Target already exists. Please choose a new, empty output path: $target" >&2
  exit 1
fi

(cd "$working_dir" && ocm add component-version \
  --repository "ctf::${source}" --constructor "$constructor")
ocm transfer component-version "ctf::${source}//${component}:${version}" "ctf::${target}" --recursive --copy-resources --upload-as localBlob
ocm get component-version "ctf::${target}//${component}:${version}"

echo "Self-contained CTF created: ${target}"
