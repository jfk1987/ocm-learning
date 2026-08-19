#!/usr/bin/env bash
# Generates an OCM Component Constructor only from the approved lockfile.
set -euo pipefail

if (($# != 3)); then
  echo "Usage: $0 <application.lock.yaml> <working-directory> <output-constructor.yaml>" >&2
  exit 64
fi

lockfile=$1
workdir=$2
output=$3
[[ -f "$lockfile" ]] || { echo "Lockfile missing: $lockfile" >&2; exit 1; }
[[ -d "$workdir" ]] || { echo "Working directory missing: $workdir" >&2; exit 1; }
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"${root_dir}/scripts/validate-application-lock.sh" "$lockfile" "$workdir"

component_name=$(yq -r '.component.name' "$lockfile")
component_version=$(yq -r '.component.version' "$lockfile")
component_provider=$(yq -r '.component.provider' "$lockfile")
chart_count=$(yq -r '.charts | length' "$lockfile")
[[ "$chart_count" = 1 ]] || { echo 'The learning path expects exactly one root Helm chart.' >&2; exit 1; }
chart_name=$(yq -r '.charts[0].resourceName' "$lockfile")
chart_version=$(yq -r '.charts[0].version' "$lockfile")
chart_path=$(yq -r '.charts[0].path' "$lockfile")
values_name=$(yq -r '.values.resourceName' "$lockfile")
values_path=$(yq -r '.values.path' "$lockfile")
[[ -f "${workdir}/${chart_path}" ]] || { echo "Chart missing: ${workdir}/${chart_path}" >&2; exit 1; }
[[ -f "${workdir}/${values_path}" ]] || { echo "Values missing: ${workdir}/${values_path}" >&2; exit 1; }

{
  printf '%s\n' '# Generated from application.lock.yaml – do not edit manually.'
  printf '%s\n' 'components:' "  - name: ${component_name}" "    version: ${component_version}" '    provider:' "      name: ${component_provider}"
} > "$output"

label_count=$(yq -r '.component.labels // [] | length' "$lockfile")
if ((label_count > 0)); then
  printf '%s\n' '    labels:' >> "$output"
  yq -r '.component.labels[] | [.name, (.value | tostring), (.signing // false)] | @tsv' "$lockfile" |
    while IFS=$'\t' read -r name value signing; do
      {
        printf '%s\n' "      - name: ${name}" "        value: ${value}"
        [[ "$signing" == true ]] && printf '%s\n' '        signing: true'
      } >> "$output"
    done
fi

source_name=$(yq -r '.source.name' "$lockfile")
source_type=$(yq -r '.source.type' "$lockfile")
source_version=$(yq -r '.source.version' "$lockfile")
source_repository=$(yq -r '.source.repository' "$lockfile")
source_ref=$(yq -r '.source.ref' "$lockfile")
{
  printf '%s\n' '    sources:' "      - name: ${source_name}" "        type: ${source_type}" "        version: ${source_version}" '        access:' '          type: git/v1' "          repoUrl: ${source_repository}" "          ref: ${source_ref}"
} >> "$output"

{
  printf '%s\n' '    resources:'
  printf '%s\n' "      - name: ${chart_name}" '        type: helmChart' "        version: ${chart_version}" '        input:' '          type: Helm/v1' "          path: ./${chart_path}"
  printf '%s\n' "      - name: ${values_name}" '        type: blob' '        input:' '          type: File/v1' "          path: ./${values_path}" '          mediaType: application/yaml'
} >> "$output"

additional_count=$(yq -r '.additionalResources // [] | length' "$lockfile")
if ((additional_count > 0)); then
  yq -r '.additionalResources[] | [.name, (.type // "blob"), .inputType, .path] | @tsv' "$lockfile" |
    while IFS=$'\t' read -r name type input_type path; do
      [[ "$name" != "null" && "$input_type" != "null" && "$path" != "null" ]] || {
        echo 'An additionalResource requires name, inputType, and path.' >&2
        exit 1
      }
      [[ -e "${workdir}/${path}" ]] || { echo "Additional resource missing: ${workdir}/${path}" >&2; exit 1; }
      {
        printf '%s\n' "      - name: ${name}" "        type: ${type}" '        input:' "          type: ${input_type}" "          path: ./${path}"
        if [[ "$input_type" == Dir/v1 ]]; then
          printf '%s\n' '          compress: true' '          reproducible: true'
        fi
      } >> "$output"
    done
fi

yq -r '.images[]? | [.name, .version, .imageReference, .platform.os, .platform.architecture] | @tsv' "$lockfile" |
  while IFS=$'\t' read -r name version reference os architecture; do
    {
      printf '%s\n' "      - name: ${name}" '        type: ociImage' "        version: ${version}" '        extraIdentity:' "          os: ${os}" "          architecture: ${architecture}" '        access:' '          type: OCIImage/v1' "          imageReference: ${reference}"
    } >> "$output"
  done

image_count=$(yq -r '.images | length' "$lockfile")
((image_count > 0)) || { echo 'Lockfile contains no images.' >&2; exit 1; }
echo "Component Constructor created: ${output}"
