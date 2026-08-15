# OCM 04 – Populate the target registry and deploy air-gapped

**Goal:** A dedicated target cluster without a default route starts the
application only from resources previously copied from the CTF into the local
registry.

## 1. Build the isolated target cluster

The target cluster may still download during its k3d/K3s bootstrap. Afterwards,
the script removes the workload node's default route. The directly connected
Docker network to the lab registry remains available.

```bash
. config/lab.env
./scripts/create-airgap-target.sh ocm-target
./scripts/set-target-egress.sh status ocm-target
```

The expected result is `blockiert (keine Default-Route)` (blocked, no default
route). The lab cluster for Forgejo and CI is unaffected.

## 2. Import the verified CTF into the registry

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export OCM_REPOSITORY='http://localhost:5000/ocm'

"$TARGET_APP_WORKDIR/scripts/import-self-contained-ctf.sh" \
  "$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" "$OCM_REPOSITORY"

ocm get component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/imported-component.yaml"

OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig" \
  ocm verify component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`--copy-resources` during import copies the local CTF blobs into the registry
and sets suitable accesses in the target descriptor. It is not enough to push
upstream tags into the same registry manually: the descriptor and resources
must arrive as one associated Component Version.

## 3. Download the chart and values by identity

```bash
mkdir -p "$DELIVERY_DIR/deploy-$COMPONENT_VERSION"
ocm download resource \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=helm-chart \
  --output "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --extraction-policy disable
ocm download resource \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  --extraction-policy disable
```

The packaged values still contain the approved upstream digests. The
localization script reads the **actual target accesses** of the three image
Resources from `imported-component.yaml`:

```bash
"$TARGET_APP_WORKDIR/scripts/localize-values.sh" \
  "$DELIVERY_DIR/imported-component.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
yq '.images' "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
```

## 4. Preflight and install

```bash
kubectl config use-context k3d-ocm-target
kubectl create namespace target-application \
  --dry-run=client -o yaml | kubectl apply -f -

"$TARGET_APP_WORKDIR/scripts/render-local-chart.sh" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  localhost:5000

helm upgrade --install target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
helm test target-application -n target-application --logs
```

`render-local-chart.sh` already blocks every external `image:` before Helm and
performs a Kubernetes server dry run.

## Acceptance

```bash
kubectl -n target-application get pod,deploy,statefulset,service,job
helm -n target-application status target-application
```

Web and Redis are ready, the migration and Helm test succeeded, and the node
still has no default route.

Next: [OCM 05 – Air-gap evidence](05-nachweis.md).
