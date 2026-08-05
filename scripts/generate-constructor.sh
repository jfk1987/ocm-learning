#!/usr/bin/env bash
# Baut aus dem freigegebenen Lockfile einen OCM component constructor.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${root_dir}/config/artifactory-lab.env"
"${root_dir}/scripts/validate-lockfile.sh"

chart="${root_dir}/dist/chart/artifactory-oss-${ARTIFACTORY_CHART_VERSION}.tgz"
[[ -f "$chart" ]] || { echo "Chart fehlt: $chart" >&2; exit 1; }
output="${root_dir}/dist/component-constructor.yaml"

{
  printf '%s\n' '# Generiert – nicht manuell ändern.'
  printf '%s\n' 'components:'
  printf '%s\n' "  - name: ${COMPONENT_NAME}"
  printf '%s\n' "    version: ${COMPONENT_VERSION}"
  printf '%s\n' '    provider:' '      name: example.org' '    resources:'
  printf '%s\n' '      - name: helm-chart' '        type: helmChart' "        version: ${ARTIFACTORY_CHART_VERSION}" '        input:' '          type: File/v1' "          path: ./chart/artifactory-oss-${ARTIFACTORY_CHART_VERSION}.tgz"
  printf '%s\n' '      - name: deployment-values' '        type: blob' '        input:' '          type: File/v1' '          path: ./values-local-registry.yaml.tpl'
} > "$output"

# Zugriffe zeigen zunächst auf die Connected-Registry. Der spätere Transfer
# kopiert sie als OCI-Artefakte in die Offline-Registry.
yq -r '.images[] | [ .name, .source, .tag, .digest ] | @tsv' "${root_dir}/config/images.lock.yaml" |
  while IFS=$'\t' read -r name source tag digest; do
    {
      printf '%s\n' "      - name: ${name}" '        type: ociImage' "        version: ${tag}" '        access:' '          type: OCIImage/v1' "          imageReference: ${source}:${tag}@${digest}"
    } >> "$output"
  done

echo "Constructor erstellt: ${output}"
