#!/usr/bin/env bash
set -euo pipefail

required=(ocm helm kubectl yq skopeo)
missing=()
for command in "${required[@]}"; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done

if ((${#missing[@]})); then
  printf 'Fehlende Werkzeuge: %s\n' "${missing[*]}" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo 'Fehlendes Werkzeug: sha256sum oder shasum' >&2
  exit 1
fi

ocm version
echo 'Werkzeuge vorhanden.'
