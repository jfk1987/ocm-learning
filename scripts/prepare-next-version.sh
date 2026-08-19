#!/usr/bin/env bash
# Packages the current chart source state as a new component/chart version.
# Image upgrades remain a deliberate, separate lockfile change.
set -euo pipefail

if (($# != 3)); then
  echo "Usage: $0 <target-repository> <component-version> <chart-version>" >&2
  exit 64
fi

target=$1
component_version=$2
chart_version=$3
app_dir="${target}/app"
delivery_dir="${target}/delivery/target-application"
lockfile="${target}/config/application.lock.yaml"

for command_name in helm yq; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "${command_name} is missing." >&2; exit 1; }
done
[[ -d "$app_dir" && -f "$lockfile" ]] || { echo 'Target application is not prepared.' >&2; exit 1; }
[[ "$component_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid component version: ${component_version}" >&2; exit 1;
}
[[ "$chart_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid chart version: ${chart_version}" >&2; exit 1;
}

CHART_VERSION="$chart_version" COMPONENT_VERSION="$component_version" \
  yq -i '
    .version = strenv(CHART_VERSION) |
    .appVersion = strenv(COMPONENT_VERSION)
  ' "${app_dir}/Chart.yaml"
rm -f "${delivery_dir}/target-application-chart.tgz"
package_output=$(helm package "$app_dir" --destination "$delivery_dir")
packaged_chart=${package_output##*: }
mv "$packaged_chart" "${delivery_dir}/target-application-chart.tgz"

rm -rf "${delivery_dir}/source"
mkdir -p "${delivery_dir}/source"
cp -R "${app_dir}/." "${delivery_dir}/source/"

if command -v sha256sum >/dev/null 2>&1; then
  digest="sha256:$(sha256sum "${delivery_dir}/target-application-chart.tgz" | awk '{print $1}')"
else
  digest="sha256:$(shasum -a 256 "${delivery_dir}/target-application-chart.tgz" | awk '{print $1}')"
fi

COMPONENT_VERSION="$component_version" CHART_VERSION="$chart_version" CHART_DIGEST="$digest" \
  yq -i '
    .component.version = strenv(COMPONENT_VERSION) |
    .source.version = strenv(COMPONENT_VERSION) |
    .source.ref = ("refs/tags/" + strenv(COMPONENT_VERSION)) |
    .charts[0].version = strenv(CHART_VERSION) |
    .charts[0].digest = strenv(CHART_DIGEST)
  ' "$lockfile"

helm template target-application "${delivery_dir}/target-application-chart.tgz" \
  --namespace target-application \
  --values "${delivery_dir}/values-airgap.yaml" \
  > "${delivery_dir}/rendered-connected.yaml"
"${target}/scripts/discover-images.sh" \
  "${delivery_dir}/images.discovered.txt" "${delivery_dir}/rendered-connected.yaml"
"${target}/scripts/validate-application-lock.sh" "$lockfile" "$delivery_dir"
echo "New inputs prepared: component ${component_version}, chart ${chart_version}"
