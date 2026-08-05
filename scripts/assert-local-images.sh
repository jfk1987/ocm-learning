#!/usr/bin/env bash
# Prüft gerenderte Manifeste. Kein Pod darf eine externe Registry referenzieren.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <manifest.yaml> <local-registry-host[:port]>" >&2
  exit 64
fi

manifest=$1
registry=$2
images=$(yq -r '.. | select(has("image")) | .image | select(type == "!!str")' "$manifest" | sort -u)
[[ -n "$images" ]] || { echo 'Keine Image-Felder gefunden.' >&2; exit 1; }

invalid=0
while IFS= read -r image; do
  if [[ "$image" != "${registry}/"* ]]; then
    printf 'Externe Image-Referenz gefunden: %s\n' "$image" >&2
    invalid=1
  fi
done <<< "$images"
((invalid == 0)) || exit 1
echo 'Alle Images zeigen auf die lokale Registry.'
