#!/usr/bin/env bash
# Generiert einen OCM Component Constructor nur aus dem freigegebenen Lockfile.
set -euo pipefail

if (($# != 3)); then
  echo "Usage: $0 <application.lock.yaml> <working-directory> <output-constructor.yaml>" >&2
  exit 64
fi

lockfile=$1
workdir=$2
output=$3
[[ -f "$lockfile" ]] || { echo "Lockfile fehlt: $lockfile" >&2; exit 1; }
[[ -d "$workdir" ]] || { echo "Arbeitsverzeichnis fehlt: $workdir" >&2; exit 1; }
[[ ! -e "$output" ]] || { echo "Ausgabe existiert bereits: $output" >&2; exit 1; }

invalid=$(yq -r '.. | select(tag == "!!str") | select(. == "TBD" or . == "REPLACE_WITH_UPSTREAM_CHART_REFERENCE")' "$lockfile" | head -n 1)
[[ -z "$invalid" ]] || { echo "Lockfile enthält noch Platzhalter: $invalid" >&2; exit 1; }

component_name=$(yq -r '.component.name' "$lockfile")
component_version=$(yq -r '.component.version' "$lockfile")
chart_count=$(yq -r '.charts | length' "$lockfile")
[[ "$chart_count" = 1 ]] || { echo 'Für den Lernpfad wird genau ein Root-Helm-Chart erwartet.' >&2; exit 1; }
chart_name=$(yq -r '.charts[0].name' "$lockfile")
chart_version=$(yq -r '.charts[0].version' "$lockfile")
chart_path=$(yq -r '.charts[0].path' "$lockfile")
values_path=$(yq -r '.values.path' "$lockfile")
[[ -f "${workdir}/${chart_path}" ]] || { echo "Chart fehlt: ${workdir}/${chart_path}" >&2; exit 1; }
[[ -f "${workdir}/${values_path}" ]] || { echo "Values fehlen: ${workdir}/${values_path}" >&2; exit 1; }

{
  printf '%s\n' '# Generiert aus application.lock.yaml – nicht manuell ändern.'
  printf '%s\n' 'components:' "  - name: ${component_name}" "    version: ${component_version}" '    provider:' '      name: example.org' '    resources:'
  printf '%s\n' "      - name: ${chart_name}" '        type: helmChart' "        version: ${chart_version}" '        input:' '          type: File/v1' "          path: ./${chart_path}"
  printf '%s\n' '      - name: deployment-values' '        type: blob' '        input:' '          type: File/v1' "          path: ./${values_path}"
} > "$output"

yq -r '.additionalResources[]? | [.name, (.type // "blob"), .inputType, .path] | @tsv' "$lockfile" |
  while IFS=$'\t' read -r name type input_type path; do
    [[ "$name" != "null" && "$input_type" != "null" && "$path" != "null" ]] || {
      echo 'Eine additionalResource benötigt name, inputType und path.' >&2
      exit 1
    }
    [[ -e "${workdir}/${path}" ]] || { echo "Zusatzresource fehlt: ${workdir}/${path}" >&2; exit 1; }
    {
      printf '%s\n' "      - name: ${name}" "        type: ${type}" '        input:' "          type: ${input_type}" "          path: ./${path}"
    } >> "$output"
  done

yq -r '.images[]? | [.name, .version, .imageReference] | @tsv' "$lockfile" |
  while IFS=$'\t' read -r name version reference; do
    [[ "$reference" == *@sha256:* ]] || { echo "Image ${name} ist nicht mit Digest gelockt." >&2; exit 1; }
    {
      printf '%s\n' "      - name: ${name}" '        type: ociImage' "        version: ${version}" '        access:' '          type: OCIImage/v1' "          imageReference: ${reference}"
    } >> "$output"
  done

image_count=$(yq -r '.images | length' "$lockfile")
((image_count > 0)) || { echo 'Lockfile enthält keine Images.' >&2; exit 1; }
echo "Component Constructor erstellt: ${output}"
