#!/usr/bin/env bash
# Erstellt die konkrete Zielanwendung im separaten Forgejo-Arbeitsverzeichnis.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target=${1:-"${repo_root}/.lab/workspaces/target-application"}

for command_name in git helm yq skopeo; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Fehlendes Werkzeug: ${command_name}" >&2
    exit 1
  }
done

[[ -d "${target}/.git" ]] || {
  echo "Forgejo-Arbeitskopie fehlt: ${target}" >&2
  echo 'Schließe zuerst Lab 02 ab.' >&2
  exit 1
}

case "${TARGET_ARCH:-$(uname -m)}" in
  x86_64|amd64) target_arch=amd64 ;;
  aarch64|arm64) target_arch=arm64 ;;
  *) echo "Nicht unterstützte Zielarchitektur: ${TARGET_ARCH:-$(uname -m)}" >&2; exit 1 ;;
esac

component_version=${COMPONENT_VERSION:-0.1.0}
chart_version=0.1.0
web_tag=1.27.4-alpine
redis_tag=7.4.2-alpine
toolbox_tag=1.37.0
web_source="public.ecr.aws/docker/library/nginx:${web_tag}"
redis_source="public.ecr.aws/docker/library/redis:${redis_tag}"
toolbox_source="public.ecr.aws/docker/library/busybox:${toolbox_tag}"
source_repository=${SOURCE_REPOSITORY:-$(git -C "$target" remote get-url origin)}
source_ref=${SOURCE_REF:-"refs/tags/${component_version}"}

resolve_reference() {
  local source=$1
  local digest
  digest=$(skopeo inspect \
    --override-os linux \
    --override-arch "$target_arch" \
    --format '{{.Digest}}' "docker://${source}")
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "Ungültiger Digest für ${source}: ${digest}" >&2
    exit 1
  }
  printf '%s@%s' "$source" "$digest"
}

echo "Löse Image-Digests für linux/${target_arch} auf ..."
web_reference=$(resolve_reference "$web_source")
redis_reference=$(resolve_reference "$redis_source")
toolbox_reference=$(resolve_reference "$toolbox_source")

app_dir="${target}/app"
delivery_dir="${target}/delivery/target-application"
mkdir -p "$app_dir" "$delivery_dir" "${target}/config" \
  "${target}/scripts" "${target}/.woodpecker"
cp -R "${repo_root}/demo/target-application/." "$app_dir/"

rm -f "${delivery_dir}/target-application-chart.tgz"
package_output=$(helm package "$app_dir" --destination "$delivery_dir")
packaged_chart=${package_output##*: }
mv "$packaged_chart" "${delivery_dir}/target-application-chart.tgz"

cp "${app_dir}/values.yaml" "${delivery_dir}/values-airgap.yaml"
WEB_REFERENCE="$web_reference" \
REDIS_REFERENCE="$redis_reference" \
TOOLBOX_REFERENCE="$toolbox_reference" \
  yq -i '
    .images.web.reference = strenv(WEB_REFERENCE) |
    .images.redis.reference = strenv(REDIS_REFERENCE) |
    .images.toolbox.reference = strenv(TOOLBOX_REFERENCE)
  ' "${delivery_dir}/values-airgap.yaml"

rm -rf "${delivery_dir}/source"
mkdir -p "${delivery_dir}/source"
cp -R "${app_dir}/." "${delivery_dir}/source/"

if command -v sha256sum >/dev/null 2>&1; then
  chart_digest="sha256:$(sha256sum "${delivery_dir}/target-application-chart.tgz" | awk '{print $1}')"
else
  chart_digest="sha256:$(shasum -a 256 "${delivery_dir}/target-application-chart.tgz" | awk '{print $1}')"
fi

cat > "${target}/config/application.lock.yaml" <<EOF
# Generiert durch scripts/prepare-target-application.sh.
schemaVersion: 1
component:
  name: example.org/team/target-application
  version: ${component_version}
  provider: example.org
  labels:
    - name: purpose
      value: ocm-learning
      signing: true
source:
  name: application-source
  type: git
  version: ${component_version}
  repository: ${source_repository}
  ref: ${source_ref}
charts:
  - resourceName: helm-chart
    name: target-application
    source: local://app
    version: ${chart_version}
    digest: ${chart_digest}
    path: target-application-chart.tgz
values:
  resourceName: deployment-values
  path: values-airgap.yaml
images:
  - name: web-image
    version: ${web_tag}
    imageReference: ${web_reference}
    platform:
      os: linux
      architecture: ${target_arch}
  - name: redis-image
    version: ${redis_tag}
    imageReference: ${redis_reference}
    platform:
      os: linux
      architecture: ${target_arch}
  - name: toolbox-image
    version: ${toolbox_tag}
    imageReference: ${toolbox_reference}
    platform:
      os: linux
      architecture: ${target_arch}
additionalResources:
  - name: source-archive
    type: sourceArchive
    inputType: Dir/v1
    path: source
EOF

cp "${repo_root}/scripts/validate-application-lock.sh" \
  "${repo_root}/scripts/discover-images.sh" \
  "${repo_root}/scripts/generate-component-constructor.sh" \
  "${repo_root}/scripts/build-self-contained-ctf.sh" \
  "${repo_root}/scripts/import-self-contained-ctf.sh" \
  "${repo_root}/scripts/localize-values.sh" \
  "${repo_root}/scripts/pack-ctf.sh" \
  "${repo_root}/scripts/verify-ctf-package.sh" \
  "${repo_root}/scripts/create-signing-config.sh" \
  "${repo_root}/scripts/prepare-next-version.sh" \
  "${repo_root}/scripts/deliver-application.sh" \
  "${target}/scripts/"
cp "${repo_root}/examples/ci/ocm-delivery.yaml" \
  "${target}/.woodpecker/ocm-delivery.yaml"

cat > "${target}/.gitignore" <<'EOF'
.lab/
delivery/**/component-constructor-*.yaml
delivery/**/transport-archive-*/
delivery/**/transport-archive-*.descriptor-source/
delivery/**/imported-component.yaml
delivery/**/component.yaml
delivery/**/inspect/
delivery/**/export/
delivery/**/deploy-*/
EOF

helm template target-application \
  "${delivery_dir}/target-application-chart.tgz" \
  --namespace target-application \
  --values "${delivery_dir}/values-airgap.yaml" \
  > "${delivery_dir}/rendered-connected.yaml"
"${repo_root}/scripts/discover-images.sh" \
  "${delivery_dir}/images.discovered.txt" \
  "${delivery_dir}/rendered-connected.yaml"
"${repo_root}/scripts/validate-application-lock.sh" \
  "${target}/config/application.lock.yaml" "$delivery_dir"

printf 'Zielanwendung vorbereitet: %s\n' "$target"
printf 'Zielplattform: linux/%s\n' "$target_arch"
printf 'Nächster Schritt: git -C %q status --short\n' "$target"
