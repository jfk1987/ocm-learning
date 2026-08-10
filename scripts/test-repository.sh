#!/usr/bin/env bash
# Schnelle statische Prüfung plus lokaler Generator-Test ohne Registry-Zugriff.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

while IFS= read -r script; do
  bash -n "$script"
  [[ -x "$script" ]] || { echo "Nicht ausführbar: ${script}" >&2; exit 1; }
done < <(find scripts -maxdepth 1 -type f -name '*.sh' | sort)
echo 'Shell-Syntax und Dateimodi sind gültig.'

if command -v ruby >/dev/null 2>&1; then
  ruby tests/check_yaml.rb
  ruby tests/check_markdown_links.rb
else
  echo 'SKIP: YAML-/Markdown-Test (ruby fehlt)'
fi

if command -v helm >/dev/null 2>&1; then
  helm lint demo/target-application
else
  echo 'SKIP: helm lint (helm fehlt)'
fi

if ! command -v yq >/dev/null 2>&1 || ! command -v helm >/dev/null 2>&1; then
  echo 'SKIP: Constructor-Integrationstest (helm oder yq fehlt)'
  exit 0
fi

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/ocm-learning-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/work/source"
cp config/application.lock.yaml "$test_dir/application.lock.yaml"
cp demo/target-application/values.yaml "$test_dir/work/values-airgap.yaml"
cp -R demo/target-application/. "$test_dir/work/source/"
helm package demo/target-application --destination "$test_dir/work" >/dev/null
mv "$test_dir/work/target-application-0.1.0.tgz" \
  "$test_dir/work/target-application-chart.tgz"

if command -v sha256sum >/dev/null 2>&1; then
  chart_hash=$(sha256sum "$test_dir/work/target-application-chart.tgz" | awk '{print $1}')
else
  chart_hash=$(shasum -a 256 "$test_dir/work/target-application-chart.tgz" | awk '{print $1}')
fi
if [[ "${OCM_TEST_REMOTE:-0}" == 1 ]] && command -v skopeo >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64|amd64) test_arch=amd64 ;;
    aarch64|arm64) test_arch=arm64 ;;
    *) echo "Nicht unterstützte Testarchitektur: $(uname -m)" >&2; exit 1 ;;
  esac
  resolve_test_image() {
    local source=$1
    local digest
    digest=$(skopeo inspect --override-os linux --override-arch "$test_arch" \
      --format '{{.Digest}}' "docker://${source}")
    printf '%s@%s' "$source" "$digest"
  }
  web=$(resolve_test_image public.ecr.aws/docker/library/nginx:1.27.4-alpine)
  redis=$(resolve_test_image public.ecr.aws/docker/library/redis:7.4.2-alpine)
  toolbox=$(resolve_test_image public.ecr.aws/docker/library/busybox:1.37.0)
else
  web="public.ecr.aws/docker/library/nginx:1.27.4-alpine@sha256:$(printf '1%.0s' {1..64})"
  redis="public.ecr.aws/docker/library/redis:7.4.2-alpine@sha256:$(printf '2%.0s' {1..64})"
  toolbox="public.ecr.aws/docker/library/busybox:1.37.0@sha256:$(printf '3%.0s' {1..64})"
fi

CHART_DIGEST="sha256:${chart_hash}" WEB="$web" REDIS="$redis" TOOLBOX="$toolbox" \
  yq -i '
    .charts[0].digest = strenv(CHART_DIGEST) |
    .images[0].imageReference = strenv(WEB) |
    .images[1].imageReference = strenv(REDIS) |
    .images[2].imageReference = strenv(TOOLBOX)
  ' "$test_dir/application.lock.yaml"
WEB="$web" REDIS="$redis" TOOLBOX="$toolbox" yq -i '
  .images.web.reference = strenv(WEB) |
  .images.redis.reference = strenv(REDIS) |
  .images.toolbox.reference = strenv(TOOLBOX)
' "$test_dir/work/values-airgap.yaml"

helm template target-application "$test_dir/work/target-application-chart.tgz" \
  --namespace target-application \
  --values "$test_dir/work/values-airgap.yaml" \
  > "$test_dir/work/rendered-connected.yaml"
scripts/discover-images.sh "$test_dir/work/images.discovered.txt" \
  "$test_dir/work/rendered-connected.yaml"
scripts/validate-application-lock.sh "$test_dir/application.lock.yaml" "$test_dir/work"
scripts/generate-component-constructor.sh "$test_dir/application.lock.yaml" \
  "$test_dir/work" "$test_dir/work/component-constructor.yaml"

yq -e '.components[0].sources | length == 1' "$test_dir/work/component-constructor.yaml" >/dev/null
yq -e '.components[0].resources | length == 6' "$test_dir/work/component-constructor.yaml" >/dev/null
yq -e '[.components[0].resources[] | select(.type == "ociImage")] | length == 3' \
  "$test_dir/work/component-constructor.yaml" >/dev/null

yq -n '
  [{"component": {"resources": [
    {"name": "web-image", "access": {"imageReference": "localhost:5000/ocm/web@sha256:111"}},
    {"name": "redis-image", "access": {"imageReference": "localhost:5000/ocm/redis@sha256:222"}},
    {"name": "toolbox-image", "access": {"imageReference": "localhost:5000/ocm/toolbox@sha256:333"}}
  ]}}]
' > "$test_dir/imported-component.yaml"
scripts/localize-values.sh "$test_dir/imported-component.yaml" \
  "$test_dir/work/values-airgap.yaml" "$test_dir/work/values-local-test.yaml"
yq -e '.images.web.reference == "localhost:5000/ocm/web@sha256:111"' \
  "$test_dir/work/values-local-test.yaml" >/dev/null

if command -v ocm >/dev/null 2>&1; then
  constructor_for_ocm="$test_dir/work/component-constructor.yaml"
  if [[ "${OCM_TEST_REMOTE:-0}" != 1 ]]; then
    constructor_for_ocm="$test_dir/work/component-constructor-local-test.yaml"
    yq 'del(.components[0].resources[] | select(.type == "ociImage"))' \
      "$test_dir/work/component-constructor.yaml" > "$constructor_for_ocm"
  fi
  (cd "$test_dir/work" && ocm add component-version \
    --repository "ctf::${test_dir}/descriptor-ctf" \
    --constructor "$constructor_for_ocm")
  ocm get component-version \
    "ctf::${test_dir}/descriptor-ctf//example.org/team/target-application:0.1.0" \
    >/dev/null
  signing_ctf="$test_dir/descriptor-ctf"
  if [[ "${OCM_TEST_REMOTE:-0}" == 1 ]]; then
    ocm transfer component-version \
      "ctf::${test_dir}/descriptor-ctf//example.org/team/target-application:0.1.0" \
      "ctf::${test_dir}/self-contained-ctf" \
      --recursive --copy-resources --upload-as localBlob
    signing_ctf="$test_dir/self-contained-ctf"
  fi
  scripts/pack-ctf.sh "$signing_ctf" "$test_dir/export/component.ctf.tgz" >/dev/null
  scripts/verify-ctf-package.sh "$test_dir/export/component.ctf.tgz" \
    "$test_dir/import" >/dev/null
  if command -v openssl >/dev/null 2>&1; then
    scripts/create-signing-config.sh "$test_dir/signing" >/dev/null
    OCM_CONFIG="$test_dir/signing/signer.ocmconfig" \
      ocm sign component-version \
      "ctf::${signing_ctf}//example.org/team/target-application:0.1.0" \
      >/dev/null
    OCM_CONFIG="$test_dir/signing/verifier.ocmconfig" \
      ocm verify component-version \
      "ctf::${signing_ctf}//example.org/team/target-application:0.1.0" \
      >/dev/null
  else
    echo 'SKIP: OCM-Signaturtest (openssl fehlt)'
  fi
else
  echo 'SKIP: OCM-Constructor-Schematest (ocm fehlt)'
fi
echo 'Lockfile-/Constructor-Integrationstest erfolgreich.'
