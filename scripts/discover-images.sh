#!/usr/bin/env bash
# Writes all image references from one or more rendered YAML files.
set -euo pipefail

if (($# < 2)); then
  echo "Usage: $0 <output.txt> <rendered-manifest.yaml> [...]" >&2
  exit 64
fi

output=$1
shift
for manifest in "$@"; do
  [[ -f "$manifest" ]] || { echo "Manifest missing: $manifest" >&2; exit 1; }
done

yq -r '.. | select(type == "!!map" and has("image")) | .image | select(type == "!!str")' "$@" |
  grep -v '^---$' | sort -u > "$output"
test -s "$output" || { echo 'No image references found.' >&2; exit 1; }
echo "Image inventory written: $output"
