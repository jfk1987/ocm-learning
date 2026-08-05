#!/usr/bin/env bash
# Schreibt sämtliche Image-Referenzen aus einem oder mehreren gerenderten YAMLs.
set -euo pipefail

if (($# < 2)); then
  echo "Usage: $0 <output.txt> <rendered-manifest.yaml> [...]" >&2
  exit 64
fi

output=$1
shift
for manifest in "$@"; do
  [[ -f "$manifest" ]] || { echo "Manifest fehlt: $manifest" >&2; exit 1; }
done

yq -r '.. | select(type == "!!map" and has("image")) | .image | select(type == "!!str")' "$@" | sort -u > "$output"
test -s "$output" || { echo 'Keine Image-Referenzen gefunden.' >&2; exit 1; }
echo "Image-Inventar geschrieben: $output"
