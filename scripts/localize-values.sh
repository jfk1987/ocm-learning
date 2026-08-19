#!/usr/bin/env bash
# Creates local Helm values from an imported Component Descriptor.
set -euo pipefail

if (($# != 3)); then
  echo "Usage: $0 <imported-component.yaml> <base-values.yaml> <output-values.yaml>" >&2
  exit 64
fi

descriptor=$1
base_values=$2
output=$3
[[ -f "$descriptor" ]] || { echo "Descriptor missing: $descriptor" >&2; exit 1; }
[[ -f "$base_values" ]] || { echo "Values missing: $base_values" >&2; exit 1; }
[[ "$base_values" != "$output" ]] || { echo 'Input and output files must be different.' >&2; exit 1; }

resource_reference() {
  local name=$1
  local reference
  reference=$(yq -r "
    .. | select(type == \"!!map\" and has(\"component\")) |
    .component.resources[] |
    select(.name == \"${name}\") |
    .access.imageReference // .access.globalAccess.imageReference // \"\"
  " "$descriptor")
  [[ -n "$reference" ]] || {
    echo "Localized image reference missing: ${name}" >&2
    exit 1
  }
  printf '%s' "$reference"
}

web_reference=$(resource_reference web-image)
redis_reference=$(resource_reference redis-image)
toolbox_reference=$(resource_reference toolbox-image)
cp "$base_values" "$output"
WEB_REFERENCE="$web_reference" \
REDIS_REFERENCE="$redis_reference" \
TOOLBOX_REFERENCE="$toolbox_reference" \
  yq -i '
    .images.web.reference = strenv(WEB_REFERENCE) |
    .images.redis.reference = strenv(REDIS_REFERENCE) |
    .images.toolbox.reference = strenv(TOOLBOX_REFERENCE)
  ' "$output"

echo "Localized values created: ${output}"
