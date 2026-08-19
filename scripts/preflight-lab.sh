#!/usr/bin/env bash
# Checks the prerequisites for the complete bootstrap learning path.
set -euo pipefail

required=(docker git curl openssl k3d kubectl helm ocm yq skopeo)
missing=()
for command in "${required[@]}"; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if ((${#missing[@]})); then
  printf 'Missing tools: %s\n' "${missing[*]}" >&2
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo 'Missing tool: sha256sum or shasum' >&2
  exit 1
fi

docker version >/dev/null
k3d version >/dev/null
ocm version
echo 'Lab prerequisites satisfied.'
