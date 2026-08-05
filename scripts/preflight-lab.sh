#!/usr/bin/env bash
# Prüft die Voraussetzungen für den vollständigen Bootstrap-Lernpfad.
set -euo pipefail

required=(docker k3d kubectl helm ocm yq skopeo)
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

docker version >/dev/null
k3d version >/dev/null
ocm version
echo 'Lab-Voraussetzungen erfüllt.'
