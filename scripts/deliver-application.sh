#!/usr/bin/env bash
# Automatischer Release-Schritt für CI: Constructor, selbstständiges CTF und
# Registry-Transfer. Ein frisches Arbeitsverzeichnis pro Version ist Pflicht.
set -euo pipefail

if (($# != 3)); then
  echo "Usage: $0 <application.lock.yaml> <working-directory> <oci-repository>" >&2
  exit 64
fi

lockfile=$1
workdir=$2
repository=$3
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
component=$(yq -r '.component.name' "$lockfile")
version=$(yq -r '.component.version' "$lockfile")
constructor="${workdir}/component-constructor-${version}.yaml"
archive="${workdir}/transport-archive-${version}"

"${root_dir}/scripts/generate-component-constructor.sh" "$lockfile" "$workdir" "$constructor"
"${root_dir}/scripts/build-self-contained-ctf.sh" "$constructor" "$workdir" "$component" "$version" "$archive"
"${root_dir}/scripts/import-self-contained-ctf.sh" "$archive" "$component" "$version" "$repository"
echo "Lieferung abgeschlossen: ${component}:${version} in ${repository}"
