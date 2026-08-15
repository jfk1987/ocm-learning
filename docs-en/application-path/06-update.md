# OCM 06 – New Component Version and rollback

**Goal:** You deliver a visible application change as a complete new Component
Version and can return to the old version.

## 1. Make a source change

In the Forgejo working directory, change the web server response text:

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

grep -n 'OCM target application is running' \
  "$TARGET_APP_WORKDIR/app/templates/configmap.yaml"
sed -i.bak \
  's/OCM target application is running/OCM target application 0.2.0 is running/' "$TARGET_APP_WORKDIR/app/templates/configmap.yaml"
rm "$TARGET_APP_WORKDIR/app/templates/configmap.yaml.bak"
```

On BSD/macOS and GNU/Linux this form briefly creates a `.bak` file and then
removes exactly that file.

## 2. Prepare reproducible new inputs

```bash
"$TARGET_APP_WORKDIR/scripts/prepare-next-version.sh" \
  "$TARGET_APP_WORKDIR" 0.2.0 0.2.0
yq '.component.version, .charts[0].version, .charts[0].digest' \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml"
```

The image versions intentionally remain unchanged. A real image upgrade again
requires `skopeo inspect`, new digests, and a rendered inventory; it is not
hidden as a side effect of a chart update.

## 3. Build, sign, and import the new version

Repeat OCM 02 and 03 with `COMPONENT_VERSION=0.2.0`. Because the names include
the version, both CTFs remain side by side:

```text
transport-archive-0.1.0/
transport-archive-0.2.0/
```

Then import `0.2.0`, download the chart/values into `deploy-0.2.0/`,
localize the values, and run `helm upgrade` as in OCM 04. Check the new text
with a port-forward while the application is running:

```bash
kubectl --context k3d-ocm-target -n target-application \
  port-forward service/target-application-web 18080:80
```

In a second terminal:

```bash
curl --fail http://localhost:18080/
```

## 4. Roll back as another declarative installation

OCM 0.1.0 remains in the registry and CTF. Reuse the chart and localized values
from `deploy-0.1.0/`:

```bash
helm upgrade target-application \
  "$DELIVERY_DIR/deploy-0.1.0/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-0.1.0/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
```

A plain `helm rollback` would not make the OCM provenance explicit. For
database schema changes, backward compatibility must also be checked.

## Acceptance

0.1.0 and 0.2.0 can be queried separately, the upgrade shows the new text, and
the rollback works without an upstream download.

The core path is complete. Next come the independent
[advanced OCM labs](../advanced/07-credentials.md).
