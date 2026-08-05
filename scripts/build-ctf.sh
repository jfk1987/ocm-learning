#!/usr/bin/env bash
# Ausschließlich auf der Connected Build-Station ausführen.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${root_dir}/config/artifactory-lab.env"
mkdir -p "${root_dir}/dist"
cp "${root_dir}/ocm/artifactory/values-local-registry.yaml.tpl" "${root_dir}/dist/values-local-registry.yaml.tpl"
"${root_dir}/scripts/generate-constructor.sh"

source_archive="${root_dir}/dist/descriptor-archive"
archive="${root_dir}/dist/transport-archive"
if [[ -e "$source_archive" || -e "$archive" ]]; then
  echo 'Ein vorheriges CTF existiert. Für einen neuen Build bitte dist/descriptor-archive und dist/transport-archive bewusst entfernen oder COMPONENT_VERSION erhöhen.' >&2
  exit 1
fi

# Der erste CTF enthält zunächst externe Image-Zugriffe. Der zweite Transfer
# lädt sie hier (in der Connected-Zone) herunter und speichert sie als lokale
# Blobs im finalen CTF. Nur dieses finale, selbständige Archiv wird exportiert.
ocm add component-version --repository "ctf::${source_archive}" --constructor "${root_dir}/dist/component-constructor.yaml" --working-directory "${root_dir}/dist"
ocm transfer component-version "ctf::${source_archive}//${COMPONENT_NAME}:${COMPONENT_VERSION}" "ctf::${archive}" --copy-resources --upload-as localBlob
ocm get component-version "ctf::${archive}//${COMPONENT_NAME}:${COMPONENT_VERSION}"
tar -C "${root_dir}/dist" -czf "${root_dir}/dist/${COMPONENT_VERSION}-transport-archive.tgz" transport-archive
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${root_dir}/dist/${COMPONENT_VERSION}-transport-archive.tgz" > "${root_dir}/dist/${COMPONENT_VERSION}-transport-archive.tgz.sha256"
else
  shasum -a 256 "${root_dir}/dist/${COMPONENT_VERSION}-transport-archive.tgz" > "${root_dir}/dist/${COMPONENT_VERSION}-transport-archive.tgz.sha256"
fi
