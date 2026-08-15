# Lab 02 – Forgejo as SCM

**Goal:** Forgejo runs as a persistent single instance in the lab. At the end,
there is an administrator account, a `target-application` repository, a
restricted Git access token, and a successful push into a **separate working
copy of the target application**.

This learning lab uses SQLite, one replica, and the Traefik ingress already
provided by k3d. It is lightweight and sufficient for the lab, but it is not an
HA or production configuration.

The chart version tested here is `17.1.3` (Forgejo 15). An upgrade is not done
as a side effect; it is a separate, verified step later.

## 1. Check the cluster and name resolution

```bash
. config/lab.env
kubectl config use-context "k3d-${LAB_CLUSTER}"
kubectl get nodes
curl --fail --show-error http://localhost:5000/v2/
```

`forgejo.ocm.test` must resolve locally to `127.0.0.1`:

```bash
getent hosts forgejo.ocm.test 2>/dev/null || \
  dscacheutil -q host -a name forgejo.ocm.test 2>/dev/null || true
```

If Lab 01 has not been fully completed, add this line to the local hosts file
and run the DNS script:

```text
127.0.0.1 forgejo.ocm.test woodpecker.ocm.test
```

On macOS/Linux, that is `/etc/hosts`; on Windows,
`C:\Windows\System32\drivers\etc\hosts`.

```bash
./scripts/configure-lab-hostnames.sh
```

## 2. Prepare the namespace and initial admin

The chart reads the username and initial password from a Kubernetes Secret. The
username must not simply be `admin`.

```bash
kubectl create namespace forgejo \
  --dry-run=client -o yaml | kubectl apply -f -

export FORGEJO_ADMIN_USER='ocm-admin'
export FORGEJO_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl -n forgejo create secret generic forgejo-admin \
  --from-literal=username="$FORGEJO_ADMIN_USER" \
  --from-literal=password="$FORGEJO_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

printf 'Forgejo user: %s\n' "$FORGEJO_ADMIN_USER"
printf 'Forgejo initial password: %s\n' "$FORGEJO_ADMIN_PASSWORD"
```

Keep the printed initial password only for the next step. The values use
`initialOnlyRequireReset`: Forgejo requires a new password after the first
login, and later Helm upgrades do not set it back to the Secret value.

## 3. Understand the configuration before installation

The checked-in file `config/lab/forgejo-values.yaml` sets:

- a 5-GiB PVC for repositories, configuration, and the SQLite database;
- one Forgejo replica;
- the Traefik ingress `http://forgejo.ocm.test:8080`;
- the existing admin Secret;
- disabled public self-registration;
- the webhook permission required for Woodpecker in Lab 03.

Before installation, check that the chart still knows the values in use:

```bash
helm show chart \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3

helm show values \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3 > /tmp/forgejo-17.1.3-values.yaml
```

Pinning prevents a later chart release from silently installing a different
database or image version.

## 4. Install Forgejo

```bash
helm upgrade --install forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3 \
  --namespace forgejo \
  --values config/lab/forgejo-values.yaml \
  --wait \
  --wait-for-jobs \
  --timeout 10m
```

The first start can take several minutes while the image loads, the PVC binds,
and the database is initialized.

## 5. Check Kubernetes resources

```bash
kubectl -n forgejo get pods,pvc,service,ingress
kubectl -n forgejo wait \
  --for=condition=Available deployment --all --timeout=300s
kubectl -n forgejo get ingress
curl --fail --show-error \
  http://forgejo.ocm.test:8080/api/healthz
```

The health check must return JSON with status `pass`. If only local name
resolution is missing, force the HTTP test without changing `/etc/hosts`:

```bash
curl --fail --show-error \
  --resolve forgejo.ocm.test:8080:127.0.0.1 \
  http://forgejo.ocm.test:8080/api/healthz
```

## 6. Complete the first login

1. Open `http://forgejo.ocm.test:8080` in a browser.
2. Sign in as `ocm-admin` with the password printed in step 2.
3. Set the requested new password.
4. Open **Settings -> Applications** in the top-right menu.
5. Under **Manage Access Tokens**, create a token with access to all
   repositories of this lab user and at least `write:repository`.
6. Copy the token to your password manager immediately; Forgejo shows it only
   once.

The access token is used as the password for Git over HTTP. The actual account
password therefore needs to appear neither in a remote URL nor in a CI file.

After changing the password, remove the temporary shell variable:

```bash
unset FORGEJO_ADMIN_PASSWORD
```

## 7. Understand the repository boundary

From this point, two Git repositories have different responsibilities:

| Repository | Contents | Built by Woodpecker? |
| --- | --- | --- |
| `ocm-learning` | This learning project, bootstrap instructions, and templates | No |
| `target-application` | Concrete application, lockfile, chart, values, and active pipelines | Yes |

The current directory remains the learning repository. Do not add a Forgejo
remote named `target-application` to its Git checkout and do not push the entire
learning path into the application repository.

If that has already happened, nothing in Forgejo or Git is damaged. The clean
correction is:

1. Rename the accidentally populated Forgejo repository under
   **Repository Settings -> Repository Name** to `ocm-learning`.
2. Rename a remote accidentally created in the local learning checkout:

   ```bash
   git remote rename forgejo forgejo-lab
   ```

3. Then create a new, empty `target-application` repository as described in the
   next section.

Run the remote step only if a remote named `forgejo` actually exists in the
learning checkout. Check first with `git remote -v`.

## 8. Create an empty application repository

In the Forgejo UI:

1. Choose **+ -> New Repository** in the top-right corner.
2. Owner: `ocm-admin`.
3. Repository name: `target-application`.
4. Visibility: **Private** for the lab.
5. Leave **Initialize repository** disabled. The minimal working copy is built
   in a controlled way in the next section.
6. Confirm with **Create Repository**.

The resulting URL is:

```text
http://forgejo.ocm.test:8080/ocm-admin/target-application.git
```

## 9. Initialize and push the separate working copy

The target application's working copy lives inside the ignored
`.lab/workspaces` directory. Run the following commands first from the
`ocm-learning` root directory:

```bash
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="${LAB_REPO_ROOT}/.lab/workspaces/target-application"

mkdir -p "$(dirname "$TARGET_APP_WORKDIR")"
git clone \
  http://forgejo.ocm.test:8080/ocm-admin/target-application.git \
  "$TARGET_APP_WORKDIR"

mkdir -p "$TARGET_APP_WORKDIR/.woodpecker"
cp "$LAB_REPO_ROOT/examples/ci/smoke.yaml" \
  "$TARGET_APP_WORKDIR/.woodpecker/smoke.yaml"
printf '%s\n' '# Target Application' > "$TARGET_APP_WORKDIR/README.md"
```

The warning that an empty repository was cloned is expected here. Commit only
this new working copy:

```bash
git -C "$TARGET_APP_WORKDIR" add README.md .woodpecker/smoke.yaml
git -C "$TARGET_APP_WORKDIR" commit -m 'Initialize target application'
git -C "$TARGET_APP_WORKDIR" branch -M main
git -C "$TARGET_APP_WORKDIR" push -u origin main
```

At the login prompt, use `ocm-admin`; use the access token created in step 6 as
the password. Then verify an independent clone outside both work directories:

```bash
git clone \
  http://forgejo.ocm.test:8080/ocm-admin/target-application.git \
  /tmp/target-application-check
git -C /tmp/target-application-check log -1 --oneline
```

## Troubleshooting

Helm and pod status:

```bash
helm -n forgejo status forgejo
kubectl -n forgejo get events --sort-by=.lastTimestamp
kubectl -n forgejo logs deployment/forgejo --all-containers --tail=200
kubectl -n forgejo describe pod -l app.kubernetes.io/instance=forgejo
```

Common causes:

- **PVC remains `Pending`:** run `kubectl get storageclass`; k3d should provide
  the `local-path` StorageClass as the default.
- **Ingress returns 404:** Check hostname and port. The request must carry the
  host header `forgejo.ocm.test` and go to port `8080`.
- **Admin login fails:** The Secret initializes only a new installation. With
  an existing PVC, the password already stored in Forgejo remains valid. Reset
  it deliberately through the Forgejo CLI instead of changing the Secret
  repeatedly.
- **Git reports 401:** Use the access token as the HTTP password and check that
  it has `write:repository` and access to `target-application`.

## Acceptance

- `/api/healthz` reports `pass`.
- The pod and PVC in namespace `forgejo` are `Running` and `Bound`.
- The private `ocm-admin/target-application` repository exists.
- It contains only `README.md` and `.woodpecker/smoke.yaml`, not the complete
  learning path.
- `git push` and the independent `git clone` work with a token.

Forgejo is now ready as the SCM for [Lab 03 – Woodpecker](03-woodpecker.md).
