#!/usr/bin/env bash
# Validiert Struktur und Dateien des Freigabevertrags einer Zielanwendung.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <application.lock.yaml> <delivery-directory>" >&2
  exit 64
fi

lockfile=$1
workdir=$2
[[ -f "$lockfile" ]] || { echo "Lockfile fehlt: $lockfile" >&2; exit 1; }
[[ -d "$workdir" ]] || { echo "Lieferverzeichnis fehlt: $workdir" >&2; exit 1; }

require_yq() {
  local expression=$1
  local message=$2
  yq -e "$expression" "$lockfile" >/dev/null || {
    echo "$message" >&2
    exit 1
  }
}

require_yq '.schemaVersion == 1' 'schemaVersion muss 1 sein.'
require_yq '.component.name | test("^[a-z0-9][a-z0-9.-]+/[a-z0-9][a-z0-9._/-]*$")' \
  'Ungültiger Component-Name.'
require_yq '.component.version | test("^v?[0-9]+\\.[0-9]+(\\.[0-9]+)?([+-][0-9A-Za-z.-]+)?$")' \
  'Component Version ist kein unterstütztes SemVer.'
require_yq '.component.provider | type == "!!str" and length > 0' 'Provider fehlt.'
require_yq '.charts | length == 1' 'Genau ein Root-Helm-Chart wird erwartet.'
require_yq '.charts[0].resourceName == "helm-chart"' \
  'Die stabile OCM Resource-Identity des Charts muss helm-chart sein.'
require_yq '.values.resourceName == "deployment-values"' \
  'Die stabile OCM Resource-Identity der Values muss deployment-values sein.'
require_yq '.images | length > 0' 'Mindestens ein Image wird erwartet.'

chart_path=$(yq -r '.charts[0].path' "$lockfile")
values_path=$(yq -r '.values.path' "$lockfile")
[[ -f "${workdir}/${chart_path}" ]] || { echo "Chart fehlt: ${workdir}/${chart_path}" >&2; exit 1; }
[[ -f "${workdir}/${values_path}" ]] || { echo "Values fehlen: ${workdir}/${values_path}" >&2; exit 1; }
require_yq '.source.repository | test("^(https?|ssh)://")' 'Source-Repository ist keine unterstützte URL.'
require_yq '.source.ref | test("^refs/(tags|heads)/[^[:space:]]+$")' 'Source-Ref muss ein Tag oder Branch sein.'
require_yq '.source.ref == ("refs/tags/" + .component.version)' \
  'Source-Ref muss dem Release-Tag der Component Version entsprechen.'
if yq -r '.source.repository' "$lockfile" | grep -Eq '://[^/]+@'; then
  echo 'Source-Repository darf keine eingebetteten Zugangsdaten enthalten.' >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_chart_digest="sha256:$(sha256sum "${workdir}/${chart_path}" | awk '{print $1}')"
else
  actual_chart_digest="sha256:$(shasum -a 256 "${workdir}/${chart_path}" | awk '{print $1}')"
fi
expected_chart_digest=$(yq -r '.charts[0].digest' "$lockfile")
[[ "$expected_chart_digest" == "$actual_chart_digest" ]] || {
  echo "Chart-Digest stimmt nicht: erwartet ${expected_chart_digest}, tatsächlich ${actual_chart_digest}" >&2
  exit 1
}

duplicate_names=$(yq -r '.images[].name, .charts[].resourceName, .values.resourceName, .additionalResources[]?.name' "$lockfile" |
  sort | uniq -d)
[[ -z "$duplicate_names" ]] || {
  echo "Doppelte Resource-Identity: ${duplicate_names}" >&2
  exit 1
}

while IFS=$'\t' read -r name version reference os architecture; do
  [[ -n "$name" && "$name" != null ]] || { echo 'Image-Name fehlt.' >&2; exit 1; }
  [[ -n "$version" && "$version" != null && "$version" != latest ]] || {
    echo "Ungültige Image-Version für ${name}: ${version}" >&2
    exit 1
  }
  [[ "$reference" =~ ^[^[:space:]@]+(:[^[:space:]@]+)?@sha256:[0-9a-f]{64}$ ]] || {
    echo "Image ${name} ist nicht als tag@sha256:<64-hex> gelockt: ${reference}" >&2
    exit 1
  }
  [[ "$os" == linux ]] || { echo "Nicht unterstütztes OS für ${name}: ${os}" >&2; exit 1; }
  [[ "$architecture" == amd64 || "$architecture" == arm64 ]] || {
    echo "Nicht unterstützte Architektur für ${name}: ${architecture}" >&2
    exit 1
  }
done < <(yq -r '.images[] | [.name, .version, .imageReference, .platform.os, .platform.architecture] | @tsv' "$lockfile")

lock_images=$(yq -r '.images[].imageReference' "$lockfile" | sort -u)
values_images=$(yq -r '.images[]?.reference' "${workdir}/${values_path}" | sort -u)
[[ "$lock_images" == "$values_images" ]] || {
  echo 'Images in Lockfile und Values unterscheiden sich.' >&2
  diff -u <(printf '%s\n' "$lock_images") <(printf '%s\n' "$values_images") || true
  exit 1
}

if [[ -f "${workdir}/images.discovered.txt" ]]; then
  discovered_images=$(sort -u "${workdir}/images.discovered.txt")
  [[ "$lock_images" == "$discovered_images" ]] || {
    echo 'Gerendertes Image-Inventar und Lockfile unterscheiden sich.' >&2
    diff -u <(printf '%s\n' "$lock_images") <(printf '%s\n' "$discovered_images") || true
    exit 1
  }
fi

additional_count=$(yq -r '.additionalResources // [] | length' "$lockfile")
if ((additional_count > 0)); then
  while IFS=$'\t' read -r name input_type path; do
    [[ -n "$name" && "$name" != null ]] || { echo 'Name einer Zusatzresource fehlt.' >&2; exit 1; }
    [[ "$input_type" == File/v1 || "$input_type" == Dir/v1 ]] || {
      echo "Nicht unterstützter Input-Typ für ${name}: ${input_type}" >&2
      exit 1
    }
    [[ -e "${workdir}/${path}" ]] || { echo "Zusatzresource fehlt: ${workdir}/${path}" >&2; exit 1; }
  done < <(yq -r '.additionalResources[] | [.name, .inputType, .path] | @tsv' "$lockfile")
fi

if yq -r '.. | select(tag == "!!str")' "$lockfile" | grep -E '^(TBD|REPLACE_WITH_.*)$' >/dev/null; then
  echo 'Lockfile enthält noch Platzhalter.' >&2
  exit 1
fi

echo "Application-Lockfile gültig: ${lockfile}"
