#!/usr/bin/env bash
# Importiert ein selbstständiges CTF in die lokale OCI Registry.
set -euo pipefail

if (($# != 4)); then
  echo "Usage: $0 <ctf-dir> <component-name> <component-version> <oci-repository>" >&2
  exit 64
fi

archive=$1
component=$2
version=$3
repository=$4
[[ -d "$archive" ]] || { echo "CTF fehlt: $archive" >&2; exit 1; }

ocm transfer component-version "ctf::${archive}//${component}:${version}" "oci::${repository}" --recursive --copy-resources --upload-as ociArtifact
ocm get component-version "oci::${repository}//${component}:${version}"
