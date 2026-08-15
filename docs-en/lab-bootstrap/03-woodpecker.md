# Lab 03 – Woodpecker as CI

**Goal:** Woodpecker authenticates users through Forgejo and runs a first
pipeline step as a Kubernetes pod. This completes the preparation lab with
SCM, CI, and a local registry.

The pinned Woodpecker chart `3.6.5` with Woodpecker `3.16.0` is used. The
server and agent each run once; SQLite is stored on a 2-GiB PVC. Pipeline pods
stay in the `woodpecker` namespace so the namespaced Role created by the chart
matches exactly. The workspace PVC is 8 GiB because the final run materializes
a CTF with all image layers.

## 1. Check shared reachability

Forgejo, the browser, and Woodpecker must use the same public URLs. Otherwise
OAuth fails either during the redirect or the API access.

```bash
. config/lab.env
export FORGEJO_URL="${FORGEJO_URL:-http://forgejo.ocm.test:8080}"
curl --fail --show-error "$FORGEJO_URL/api/healthz"
./scripts/configure-lab-hostnames.sh
```

Also check Forgejo from a pod:

```bash
kubectl run forgejo-from-cluster \
  --image=curlimages/curl:8.12.1 \
  --restart=Never --command -- \
  curl --fail --show-error \
  http://forgejo.ocm.test:8080/api/healthz
kubectl logs forgejo-from-cluster
kubectl delete pod forgejo-from-cluster
```

This test must work before configuring OAuth.

## 2. Create an OAuth2 application in Forgejo

1. Sign in to Forgejo as `ocm-admin`.
2. Open **Site Administration -> Applications**. For a personal lab,
   **Settings -> Applications** also works.
3. Create a new OAuth2 application named `woodpecker`.
4. Enter this Redirect URI exactly:

   ```text
   http://woodpecker.ocm.test:8080/authorize
   ```

5. Save the application and copy the client ID and client secret.

The scheme, host, port, and `/authorize` path must match exactly. A callback URL
with `https`, without port `8080`, or with a trailing slash is a different URL
and will not work here.

## 3. Store OAuth data in a Kubernetes Secret

Credentials are not written to Git or to a Helm values file:

```bash
kubectl create namespace woodpecker \
  --dry-run=client -o yaml | kubectl apply -f -

read -r -p 'Forgejo OAuth client ID: ' WOODPECKER_FORGEJO_CLIENT
read -r -s -p 'Forgejo OAuth client secret: ' WOODPECKER_FORGEJO_SECRET
printf '\n'

kubectl -n woodpecker create secret generic woodpecker-forgejo \
  --from-literal=WOODPECKER_FORGEJO_CLIENT="$WOODPECKER_FORGEJO_CLIENT" \
  --from-literal=WOODPECKER_FORGEJO_SECRET="$WOODPECKER_FORGEJO_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

unset WOODPECKER_FORGEJO_CLIENT WOODPECKER_FORGEJO_SECRET
```

`config/lab/woodpecker-values.yaml` references this Secret through
`server.extraSecretNamesForEnvFrom`. It contains no secrets itself.

## 4. Inspect the chart and values

```bash
helm show chart \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5

helm show values \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5 > /tmp/woodpecker-3.6.5-values.yaml
```

The lab values configure:

- Forgejo at `http://forgejo.ocm.test:8080`;
- Woodpecker's public URL `http://woodpecker.ocm.test:8080`;
- exactly one Kubernetes agent and at most one parallel workflow;
- short-lived 8-GiB RWO volumes for pipeline workspaces;
- the existing Forgejo user `ocm-admin` as the Woodpecker admin;
- an ingress through the Traefik provided by k3d.

## 5. Install Woodpecker

```bash
helm upgrade --install woodpecker \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5 \
  --namespace woodpecker \
  --values config/lab/woodpecker-values.yaml \
  --wait \
  --timeout 10m
```

Check status and logs:

```bash
kubectl -n woodpecker get pod,pvc,service,ingress
kubectl -n woodpecker rollout status \
  statefulset/woodpecker-server --timeout=300s
kubectl -n woodpecker rollout status \
  deployment/woodpecker-agent --timeout=300s
kubectl -n woodpecker logs deployment/woodpecker-agent --tail=100
kubectl -n woodpecker logs statefulset/woodpecker-server --tail=100
curl --fail --show-error \
  http://woodpecker.ocm.test:8080/healthz
```

The agent log must show the connection to the server. A `forbidden` error in
later pipeline pods points to the ServiceAccount/Role configuration.

## 6. Sign in and activate the repository

1. Open `http://woodpecker.ocm.test:8080`.
2. Choose Forgejo login and approve the OAuth access.
3. Synchronize repositories if `target-application` does not appear at once.
4. Open `ocm-admin/target-application` and activate the repository.

Woodpecker creates the required webhook in Forgejo. In Forgejo, under
**Repository Settings -> Webhooks**, check that the webhook is active and its
last test has no network error.

## 7. Trigger the first Kubernetes pipeline

The template `examples/ci/smoke.yaml` from the learning repository was copied
in Lab 02 as `.woodpecker/smoke.yaml` into the **separate target application
working copy**. The step deliberately uses the image pushed in Lab 01:

```yaml
image: localhost:5000/lab/alpine:3.21
```

A single run checks three connections: Forgejo webhook to Woodpecker,
Woodpecker agent to the Kubernetes API, and K3s to the local registry.

```bash
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="${LAB_REPO_ROOT}/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"

printf '%s\n' "Smoke test $(date -u +%FT%TZ)" \
  >> "$TARGET_APP_WORKDIR/README.md"
git -C "$TARGET_APP_WORKDIR" add README.md
git -C "$TARGET_APP_WORKDIR" commit -m 'Trigger Woodpecker smoke test'
git -C "$TARGET_APP_WORKDIR" push origin main
```

The pipeline itself was pushed with the initial commit from Lab 02. The change
to `README.md` creates a new webhook event after activation. Do not push from
the root of `ocm-learning`.

Watch the short-lived resources during the run:

```bash
kubectl -n woodpecker get pods,pvc --watch
```

The Woodpecker UI must show the `local-registry-smoke-test` step as successful.

## Troubleshooting

```bash
helm -n woodpecker status woodpecker
kubectl -n woodpecker get events --sort-by=.lastTimestamp
kubectl -n woodpecker logs deployment/woodpecker-agent --tail=200
kubectl -n woodpecker logs statefulset/woodpecker-server --tail=200
```

Common causes:

- **OAuth `redirect_uri` invalid:** Compare the URI in Forgejo character by
  character with `http://woodpecker.ocm.test:8080/authorize`.
- **Woodpecker cannot reach Forgejo:** Repeat the pod test from step 1 and
  check `coredns-custom`, `lab-ingress`, and its endpoints.
- **Webhook rejected:** In Forgejo's generated `app.ini`, check whether
  `ALLOWED_HOST_LIST` was taken from the lab values.
- **Pipeline pod remains `ImagePullBackOff`:** Repeat Lab 01 and check
  `/etc/rancher/k3s/registries.yaml` on the node.
- **Pipeline pod/PVC is `forbidden`:** In the lab,
  `WOODPECKER_BACKEND_K8S_NAMESPACE=woodpecker` and the Role created by the
  chart must be in the same namespace.

## Acceptance

- Sign-in to Woodpecker through Forgejo works.
- The activated repository has a successful Forgejo webhook.
- The smoke test runs as a Kubernetes pod and completes successfully.
- Its image comes from `localhost:5000`, not an external registry.

Manual bootstrap is now complete. [Lab 04 – automated release](04-automatischer-release.md)
turns it into automatic creation and transfer of the OCM Component Version.
