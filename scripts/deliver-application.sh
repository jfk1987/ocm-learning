#!/usr/bin/env bash
# Automated release step for CI: constructor, self-contained CTF, and
# registry transfer. A fresh working directory per version is required.
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
echo "Delivery complete: ${component}:${version} in ${repository}"
