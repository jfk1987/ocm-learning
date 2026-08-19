#!/usr/bin/env bash
# Checks rendered manifests. No pod may reference an external registry.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <manifest.yaml> <local-registry-host[:port]>" >&2
  exit 64
fi

manifest=$1
registry=$2
images=$(yq -r '.. | select(has("image")) | .image | select(type == "!!str")' "$manifest" |
  grep -v '^---$' | sort -u)
[[ -n "$images" ]] || { echo 'No image fields found.' >&2; exit 1; }

invalid=0
while IFS= read -r image; do
  if [[ "$image" != "${registry}/"* ]]; then
    printf 'External image reference found: %s\n' "$image" >&2
    invalid=1
  fi
done <<< "$images"
((invalid == 0)) || exit 1
echo 'All images point to the local registry.'
