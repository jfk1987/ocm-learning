#!/usr/bin/env bash
# Validates the structure and files of a target application's release contract.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <application.lock.yaml> <delivery-directory>" >&2
  exit 64
fi

lockfile=$1
workdir=$2
[[ -f "$lockfile" ]] || { echo "Lockfile missing: $lockfile" >&2; exit 1; }
[[ -d "$workdir" ]] || { echo "Delivery directory missing: $workdir" >&2; exit 1; }

require_yq() {
  local expression=$1
  local message=$2
  yq -e "$expression" "$lockfile" >/dev/null || {
    echo "$message" >&2
    exit 1
  }
}

require_yq '.schemaVersion == 1' 'schemaVersion must be 1.'
require_yq '.component.name | test("^[a-z0-9][a-z0-9.-]+/[a-z0-9][a-z0-9._/-]*$")' \
  'Invalid component name.'
require_yq '.component.version | test("^v?[0-9]+\\.[0-9]+(\\.[0-9]+)?([+-][0-9A-Za-z.-]+)?$")' \
  'Component version is not a supported SemVer.'
require_yq '.component.provider | type == "!!str" and length > 0' 'Provider is missing.'
require_yq '.charts | length == 1' 'Exactly one root Helm chart is expected.'
require_yq '.charts[0].resourceName == "helm-chart"' \
  'The stable OCM resource identity of the chart must be helm-chart.'
require_yq '.values.resourceName == "deployment-values"' \
  'The stable OCM resource identity of the values must be deployment-values.'
require_yq '.images | length > 0' 'At least one image is expected.'

chart_path=$(yq -r '.charts[0].path' "$lockfile")
values_path=$(yq -r '.values.path' "$lockfile")
[[ -f "${workdir}/${chart_path}" ]] || { echo "Chart missing: ${workdir}/${chart_path}" >&2; exit 1; }
[[ -f "${workdir}/${values_path}" ]] || { echo "Values missing: ${workdir}/${values_path}" >&2; exit 1; }
require_yq '.source.repository | test("^(https?|ssh)://")' 'Source repository is not a supported URL.'
require_yq '.source.ref | test("^refs/(tags|heads)/[^[:space:]]+$")' 'Source ref must be a tag or branch.'
require_yq '.source.ref == ("refs/tags/" + .component.version)' \
  'Source ref must match the component version release tag.'
if yq -r '.source.repository' "$lockfile" | grep -Eq '://[^/]+@'; then
  echo 'Source repository must not contain embedded credentials.' >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_chart_digest="sha256:$(sha256sum "${workdir}/${chart_path}" | awk '{print $1}')"
else
  actual_chart_digest="sha256:$(shasum -a 256 "${workdir}/${chart_path}" | awk '{print $1}')"
fi
expected_chart_digest=$(yq -r '.charts[0].digest' "$lockfile")
[[ "$expected_chart_digest" == "$actual_chart_digest" ]] || {
  echo "Chart digest mismatch: expected ${expected_chart_digest}, got ${actual_chart_digest}" >&2
  exit 1
}

duplicate_names=$(yq -r '.images[].name, .charts[].resourceName, .values.resourceName, .additionalResources[]?.name' "$lockfile" |
  sort | uniq -d)
[[ -z "$duplicate_names" ]] || {
  echo "Duplicate resource identity: ${duplicate_names}" >&2
  exit 1
}

while IFS=$'\t' read -r name version reference os architecture; do
  [[ -n "$name" && "$name" != null ]] || { echo 'Image name is missing.' >&2; exit 1; }
  [[ -n "$version" && "$version" != null && "$version" != latest ]] || {
    echo "Invalid image version for ${name}: ${version}" >&2
    exit 1
  }
  [[ "$reference" =~ ^[^[:space:]@]+(:[^[:space:]@]+)?@sha256:[0-9a-f]{64}$ ]] || {
    echo "Image ${name} is not locked as tag@sha256:<64-hex>: ${reference}" >&2
    exit 1
  }
  [[ "$os" == linux ]] || { echo "Unsupported OS for ${name}: ${os}" >&2; exit 1; }
  [[ "$architecture" == amd64 || "$architecture" == arm64 ]] || {
    echo "Unsupported architecture for ${name}: ${architecture}" >&2
    exit 1
  }
done < <(yq -r '.images[] | [.name, .version, .imageReference, .platform.os, .platform.architecture] | @tsv' "$lockfile")

lock_images=$(yq -r '.images[].imageReference' "$lockfile" | sort -u)
values_images=$(yq -r '.images[]?.reference' "${workdir}/${values_path}" | sort -u)
[[ "$lock_images" == "$values_images" ]] || {
  echo 'Images in the lockfile and values differ.' >&2
  diff -u <(printf '%s\n' "$lock_images") <(printf '%s\n' "$values_images") || true
  exit 1
}

if [[ -f "${workdir}/images.discovered.txt" ]]; then
  discovered_images=$(sort -u "${workdir}/images.discovered.txt")
  [[ "$lock_images" == "$discovered_images" ]] || {
    echo 'Rendered image inventory and lockfile differ.' >&2
    diff -u <(printf '%s\n' "$lock_images") <(printf '%s\n' "$discovered_images") || true
    exit 1
  }
fi

additional_count=$(yq -r '.additionalResources // [] | length' "$lockfile")
if ((additional_count > 0)); then
  while IFS=$'\t' read -r name input_type path; do
    [[ -n "$name" && "$name" != null ]] || { echo 'Additional resource name is missing.' >&2; exit 1; }
    [[ "$input_type" == File/v1 || "$input_type" == Dir/v1 ]] || {
      echo "Unsupported input type for ${name}: ${input_type}" >&2
      exit 1
    }
    [[ -e "${workdir}/${path}" ]] || { echo "Additional resource missing: ${workdir}/${path}" >&2; exit 1; }
  done < <(yq -r '.additionalResources[] | [.name, .inputType, .path] | @tsv' "$lockfile")
fi

if yq -r '.. | select(tag == "!!str")' "$lockfile" | grep -E '^(TBD|REPLACE_WITH_.*)$' >/dev/null; then
  echo 'Lockfile still contains placeholders.' >&2
  exit 1
fi

echo "Application lockfile is valid: ${lockfile}"
