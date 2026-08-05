#!/usr/bin/env bash
# Rendert ein bereits aus OCM extrahiertes Chart und verbietet externe Images.
set -euo pipefail

if (($# != 5)); then
  echo "Usage: $0 <release> <chart.tgz> <namespace> <values.yaml> <local-registry-host[:port]>" >&2
  exit 64
fi

release=$1
chart=$2
namespace=$3
values=$4
registry=$5
output="${chart%.tgz}-${release}-rendered.yaml"

helm template "$release" "$chart" --namespace "$namespace" --values "$values" > "$output"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assert-local-images.sh" "$output" "$registry"
kubectl apply --dry-run=server -f "$output"
echo "Geprüftes Manifest: ${output}"
