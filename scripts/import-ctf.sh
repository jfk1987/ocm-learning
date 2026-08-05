#!/usr/bin/env bash
# Ausschließlich in der Offline-Zone ausführen; die lokale Registry muss erreichbar sein.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${root_dir}/config/artifactory-lab.env"
archive="${root_dir}/dist/transport-archive"
[[ -d "$archive" ]] || { echo 'CTF-Archiv wurde nicht entpackt.' >&2; exit 1; }

ocm transfer component-version "ctf::${archive}//${COMPONENT_NAME}:${COMPONENT_VERSION}" "oci::${OCM_REPOSITORY}" --copy-resources --upload-as ociArtifact
ocm get component-version "oci::${OCM_REPOSITORY}//${COMPONENT_NAME}:${COMPONENT_VERSION}"
echo 'Import abgeschlossen. Im nächsten Schritt die lokalisierten Image-Zugriffe aus dem Descriptor übernehmen.'
