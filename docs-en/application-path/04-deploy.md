# OCM 04 – Populate the target registry and deploy air-gapped

**Goal:** A dedicated target cluster without a default route starts the
application only from Resources previously copied from the CTF into the local
registry.

## What actually happens in this chapter

The verified CTF currently exists only as a transport package in the simulated
target zone. Kubernetes cannot start images directly from a CTF. A deliberate
translation between three storage locations is therefore required:

```text
extracted CTF
   │ OCM imports descriptor and Resources
   ▼
local OCI registry at localhost:5000
   │ Helm gives Kubernetes local image addresses
   ▼
target cluster without Internet egress
```

OCM transports and localizes the approved artifacts. Helm renders the
installation. Kubernetes starts the workloads. None of these tools silently
replaces the responsibilities of the others.

## 1. Build an isolated target cluster

The target cluster may still download images during its k3d/K3s bootstrap.
Afterwards, the script removes the default route from its workload nodes. The
directly connected Docker network to the lab registry remains reachable.

```bash
. config/lab.env
./scripts/create-airgap-target.sh ocm-target
./scripts/set-target-egress.sh status ocm-target
```

The first call creates a separate k3d cluster with a registry mirror. It is
not the lab cluster running Forgejo and Woodpecker. The second call inspects
the node containers and displays their routing state.

The expected result is similar to:

```text
k3d-ocm-target-server-0: blocked (no default route)
```

“No default route” means that Internet destinations are unreachable. Directly
connected Docker networks still have specific routes. The node can therefore
reach the local registry even though a later upstream pull must fail.

Make the separation visible:

```bash
kubectl --context k3d-ocm-target get nodes -o wide
docker exec k3d-ocm-target-server-0 ip route
```

No line in the routing table may begin with `default`.

## 2. Import the verified CTF into the target registry

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export OCM_REPOSITORY='http://localhost:5000/ocm'
```

`OCM_REPOSITORY` is used by the OCM process on your host, so
`localhost:5000` is correct. Unlike an OCI image reference, this OCM repository
argument may include the `http://` protocol.

Now perform the actual import:

```bash
"$TARGET_APP_WORKDIR/scripts/import-self-contained-ctf.sh" \
  "$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" "$OCM_REPOSITORY"
```

At its core, the script performs this transfer:

```text
ctf::.../transport-archive-0.1.0//example.org/team/target-application:0.1.0
                                  │
                                  │ --copy-resources --upload-as ociArtifact
                                  ▼
oci::http://localhost:5000/ocm//example.org/team/target-application:0.1.0
```

This transfers more than metadata. The chart, values, source archive, and
image contents are written from the local CTF blobs into the OCI registry. The
target descriptor receives accesses pointing to the new registry content.
Pushing manually chosen image tags with matching names would not be equivalent:
the Component Version, Resource identities, accesses, and digests must arrive
as one connected model.

## 3. Read the imported descriptor and verify it again

```bash
ocm get component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/imported-component.yaml"

OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig" \
  ocm verify component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`ctf::` has become `oci::`: the same Component Version is now read from the
registry instead of the transport archive. The first command saves its target
descriptor for the following steps. Placing the verifier configuration before
the second command sets `OCM_CONFIG` only for that one process; the global
shell variable does not need to change.

Inspect the new image accesses:

```bash
yq '.[0].component.resources[] |
  select(.type == "ociImage") |
  {name, extraIdentity, access}' "$DELIVERY_DIR/imported-component.yaml"
```

The functional Resource names and digests remain the same, while each
`imageReference` now points to the target registry.

## 4. Download chart and values by Resource Identity

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

Both calls begin at the Component Version and select a Resource with
`--identity name=...`. Users do not need to know its physical registry path;
OCM resolves that path through the descriptor.

`values-base.yaml` deliberately remains the unchanged, signed release input.
It still contains the approved upstream references. A new file will translate
them to the actual target accesses.

## 5. Localize the Helm values for the target registry

```bash
"$TARGET_APP_WORKDIR/scripts/localize-values.sh" \
  "$DELIVERY_DIR/imported-component.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
yq '.images' "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
```

The script reads `access.imageReference` for `web-image`, `redis-image`, and
`toolbox-image` from the imported descriptor. It then copies the base values
and replaces only the three image references in that copy.

This keeps two artifacts independently traceable:

```text
values-base.yaml   = approved, transported input
values-local.yaml  = installation localized for this target registry
```

Display the change:

```bash
diff -u "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" || true
```

`diff` output is expected here. Only image addresses should change, not
application parameters or versions.

## 6. Preflight the deployment

```bash
kubectl config use-context k3d-ocm-target
kubectl create namespace target-application \
  --dry-run=client -o yaml | kubectl apply -f -
```

The first command makes the target cluster the default context for subsequent
`kubectl` and Helm calls. The second command is a pipe:

1. `kubectl create ... --dry-run=client -o yaml` only generates YAML on stdout.
2. `|` passes that YAML to the next process.
3. `kubectl apply -f -` reads stdin and creates the namespace or leaves the
   existing namespace unchanged.

Now validate the chart without installing it:

```bash
"$TARGET_APP_WORKDIR/scripts/render-local-chart.sh" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  localhost:5000
```

The script performs three checks:

1. `helm template` renders the complete Kubernetes manifest.
2. `assert-local-images.sh` rejects every `image:` outside `localhost:5000`.
3. `kubectl apply --dry-run=server` asks the API server to validate the
   manifest without creating the workloads.

The success message `Validated manifest: ...` therefore means: the chart is
renderable, contains only local images, and is accepted by the Kubernetes API
server.

## 7. Actually install the application

```bash
helm upgrade --install target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
helm test target-application -n target-application --logs
```

Only `helm upgrade --install` changes the application objects in the cluster.
`--install` creates the release on its first run; on later runs, `upgrade`
updates the same release. `--wait` waits for ready workloads, and
`--wait-for-jobs` additionally waits for the migration job.

`helm test` starts the test Pod defined in the chart and prints its logs. A
successful test shows not only that objects exist, but that the web service
responds inside the cluster.

## Checkpoint

```bash
kubectl -n target-application get pod,deploy,statefulset,service,job
helm -n target-application status target-application
./scripts/set-target-egress.sh status ocm-target
```

Web and Redis are ready, migration and Helm test succeeded, and the node still
has no default route. The installation is complete; the strict air-gap proof
follows in the next chapter.

Next: [OCM 05 – Air-gap evidence](05-nachweis.md).
