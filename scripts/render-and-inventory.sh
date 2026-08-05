#!/usr/bin/env bash
# Ausschließlich auf der Connected Build-Station ausführen.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${root_dir}/config/artifactory-lab.env"
mkdir -p "${root_dir}/dist/chart" "${root_dir}/dist/rendered"

chart="${root_dir}/dist/chart/artifactory-oss-${ARTIFACTORY_CHART_VERSION}.tgz"
if [[ ! -f "$chart" ]]; then
  helm repo add jfrog https://charts.jfrog.io >/dev/null 2>&1 || true
  helm pull jfrog/artifactory-oss --version "$ARTIFACTORY_CHART_VERSION" --destination "${root_dir}/dist/chart"
fi

# Das Rendering ist die maßgebliche Image-Inventur: es erfasst auch Images aus
# Abhängigkeiten und Hooks des gewählten Chart-Releases.
helm template artifactory-oss "$chart" --namespace artifactory-oss --include-crds > "${root_dir}/dist/rendered/all.yaml"
yq -r '.. | select(has("image")) | .image | select(type == "!!str")' "${root_dir}/dist/rendered/all.yaml" | sort -u > "${root_dir}/dist/rendered/images.discovered.txt"

echo 'Gefundene Image-Referenzen:'
cat "${root_dir}/dist/rendered/images.discovered.txt"
echo 'Übernimm jede Referenz mit einem Digest nach config/images.lock.yaml.'
