#!/usr/bin/env bash
# Verhindert versehentliches Bauen mit Tags ohne immutable Digest.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lockfile="${root_dir}/config/images.lock.yaml"

yq -e '.images | length > 0' "$lockfile" >/dev/null
if yq -e '.images[] | select(.digest == "TBD" or (.digest | test("^sha256:[0-9a-f]{64}$") | not))' "$lockfile" >/dev/null; then
  echo "${lockfile} enthält fehlende oder ungültige Digests." >&2
  exit 1
fi
if yq -e '.images[] | select(.tag == "latest")' "$lockfile" >/dev/null; then
  echo 'Das Tag latest ist nicht zulässig.' >&2
  exit 1
fi
echo 'Lockfile ist vollständig und enthält nur sha256-Digests.'
