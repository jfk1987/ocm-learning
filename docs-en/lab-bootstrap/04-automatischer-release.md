# Lab 04 – Automated OCM delivery from CI

**Goal:** You build a dedicated CI tool image, add a Woodpecker pipeline to the
Forgejo repository `target-application`, and trigger it with a Git tag. The
pipeline creates a complete OCM Component Version from the lockfile and
transfers it to the local OCI registry.

This chapter assumes no Woodpecker, Skopeo, or OCM experience. The sections are
deliberately short and individually verifiable.

## 0. What works together in this lab

| Tool | Role in this step |
| --- | --- |
| Forgejo | Stores the repository and sends a webhook when a tag is pushed |
| Woodpecker | Clones exactly that Git revision and starts the defined steps |
| CI tool image | Provides `ocm`, `helm`, `yq`, `skopeo`, and `bash` |
| Skopeo | Checks OCI registry access without requiring a Docker daemon |
| OCM | Creates the CTF, copies all Resources, and publishes the Component Version |
| Local registry | Stores tool images, Component Descriptors, and localized Resources |

The CI tool image belongs to the build platform. It is **not** part of the
air-gapped target application. The OCM component contains only the target
application's chart, values, additional files, and runtime images.

## 1. Check prerequisites

Labs 01 through 03 must be complete. In addition, steps 00 through 02 from
“Part B – Target application with OCM” must be complete for the selected
application. In particular, the lockfile must not contain placeholders.

Run the following commands from the `ocm-learning` root directory:

```bash
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="${LAB_REPO_ROOT}/.lab/workspaces/target-application"

test -d "$TARGET_APP_WORKDIR/.git"
kubectl get nodes
curl --fail --show-error http://localhost:5000/v2/
curl --fail --show-error http://woodpecker.ocm.test:8080/healthz
git -C "$TARGET_APP_WORKDIR" remote -v
```

The Git remote must point to `ocm-admin/target-application.git` in Forgejo. It
must not point to the learning repository.

Now check the release inputs:

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/values-airgap.yaml"

if grep -n -E 'TBD|REPLACE_WITH_' \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" \
  "$TARGET_APP_WORKDIR/delivery/target-application/values-airgap.yaml"; then
  echo 'Placeholders are still present.' >&2
  false
fi
```

`grep` returns exit code 1 when it finds no matches; the `if` block makes that
the desired success case. A match deliberately aborts the check.

## 2. Keep the two Git repositories separate

Lab 04 uses two directories with different responsibilities:

| Directory | Changed there | Committed there |
| --- | --- | --- |
| `$LAB_REPO_ROOT` | No; provides templates and the Dockerfile | No |
| `$TARGET_APP_WORKDIR` | Yes; contains the application and active pipeline | Yes |

OCM 00 already created the application and release scripts in a controlled way
from the learning repository. The following commands are therefore a check,
not a second bootstrap:

```bash
for file in \
  scripts/validate-application-lock.sh \
  scripts/generate-component-constructor.sh \
  scripts/build-self-contained-ctf.sh \
  scripts/import-self-contained-ctf.sh \
  scripts/deliver-application.sh \
  .woodpecker/ocm-delivery.yaml; do
  test -f "$TARGET_APP_WORKDIR/$file" || {
    echo "Missing: $file – run OCM 00 first" >&2
    false
  }
done
```

**Intermediate result:** `git -C "$TARGET_APP_WORKDIR" status --short` shows
only target-application files. The status of `ocm-learning` is irrelevant here.

## 3. Build the CI tool image

Woodpecker runs each step in a container. Our container needs more tools than a
normal Alpine image. The Dockerfile in `ci/ocm-delivery` therefore installs:

- `ocm` for Component Versions and CTFs;
- `helm` to check the chart;
- `yq` to read the YAML lockfile;
- `skopeo` to inspect and copy OCI artifacts; and
- `bash` for the release scripts.

Build the image on the host. The final dot is the build context and must not be
omitted:

```bash
export CI_TOOL_IMAGE='localhost:5000/lab/ocm-delivery:0.1.0'

docker build \
  --tag "$CI_TOOL_IMAGE" \
  --file "$LAB_REPO_ROOT/ci/ocm-delivery/Dockerfile" \
  "$LAB_REPO_ROOT"
```

The Dockerfile automatically uses the host architecture (`amd64` or `arm64`).
That fits this lab because Docker and k3d run on the same workstation.

Check the image before publishing it:

```bash
docker run --rm "$CI_TOOL_IMAGE" -lc '
  set -e
  ocm version
  helm version --short
  yq --version
  skopeo --version
'
```

Every command must print a version. `command not found` means the image was not
built successfully.

## 4. Push the tool image to the lab registry

The Woodpecker agent runs in the cluster and cannot see a Docker image that
exists only on the host. Push it to the registry:

```bash
docker push "$CI_TOOL_IMAGE"

curl --fail --show-error \
  http://localhost:5000/v2/lab/ocm-delivery/tags/list
```

The response must contain tag `0.1.0`. The lab registry deliberately has no TLS
and no authentication, so neither `docker login` nor registry Secrets are
needed here.

Then test whether Kubernetes can pull the image through the k3d mirror set up
in Lab 01:

```bash
kubectl -n woodpecker run ocm-toolimage-test \
  --image="$CI_TOOL_IMAGE" \
  --restart=Never \
  --command -- /bin/bash -lc 'ocm version && skopeo --version'

kubectl -n woodpecker wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/ocm-toolimage-test --timeout=180s
kubectl -n woodpecker logs ocm-toolimage-test
kubectl -n woodpecker delete pod ocm-toolimage-test
```

**Intermediate result:** The test pod ends with `Succeeded`. With
`ImagePullBackOff`, repair the registry mirror from Lab 01, not Woodpecker.

## 5. Understand registry addresses and test from a pod

The lab has three spellings for the same registry:

| Where it is used | Address | Why |
| --- | --- | --- |
| Host commands such as `docker push` and `curl` | `localhost:5000` | Port 5000 is published to the host |
| Kubernetes `image:` field | `localhost:5000/...` | K3s translates it through its registry mirror |
| Process inside a pipeline pod | `k3d-registry.localhost:5000` | `localhost` would be the pipeline pod itself |

Check the third variant with Skopeo. `--tls-verify=false` is needed only for the
unencrypted lab registry:

```bash
kubectl -n woodpecker run registry-aus-pod \
  --image="$CI_TOOL_IMAGE" \
  --restart=Never \
  --command -- /bin/bash -lc \
  'skopeo list-tags --tls-verify=false \
    docker://k3d-registry.localhost:5000/lab/ocm-delivery'

kubectl -n woodpecker wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/registry-aus-pod --timeout=180s
kubectl -n woodpecker logs registry-aus-pod
kubectl -n woodpecker delete pod registry-aus-pod
```

The output must again contain `0.1.0`. This test prevents the common errors
`connection refused` against `localhost` and `server gave HTTP response to
HTTPS client`.

## 6. Read the Woodpecker file

Open `$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml`. The file has three
levels:

```yaml
when:
  - event: tag

steps:
  - name: release-eingaben-pruefen
    image: localhost:5000/lab/ocm-delivery:0.1.0
    pull: true
    commands:
      - ocm version

  - name: ocm-komponente-liefern
    image: localhost:5000/lab/ocm-delivery:0.1.0
    pull: true
    environment:
      DELIVERY_DIR: delivery/target-application
      OCM_REPOSITORY: http://k3d-registry.localhost:5000/ocm
    commands:
      - ./scripts/deliver-application.sh ...
```

- `when` enables the entire workflow only for a pushed Git tag;
- `steps` is the ordered list of container steps;
- `image` selects the tool environment for each step;
- `pull: true` makes Woodpecker pull the tag from the registry before the step;
- `commands` run in the automatically cloned repository; and
- `environment` sets ordinary environment variables in the step.

The first step checks tools, input files, byte equality between `app/` and the
packaged source copy, registry access, and that `CI_COMMIT_TAG` exactly matches
the `component.version` in the lockfile. Only then does the second step perform
the actual OCM delivery.

`OCM_REPOSITORY` starts with `http://` because OCM assumes HTTPS when a
registry has no scheme. A production registry uses TLS and might be written as
`registry.example.org/ocm`.

Check that the image reference matches the one just pushed:

```bash
grep -n 'image: localhost:5000/lab/ocm-delivery:0.1.0' \
  "$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml"
```

Two matches are expected, one per step.

## 7. Why this lab needs no Woodpecker Secrets

The registry from Lab 01 has no authentication. Therefore a username,
password, and `skopeo login` would be unnecessary and misleading. The repository
address is not secret either and is visible in the pipeline.

For a real registry with login, do **not** commit credentials to Git. In
Woodpecker, open:

1. `ocm-admin/target-application`;
2. **Settings**;
3. **Secrets**;
4. **Add secret**;
5. a name such as `target_registry_password` and the registry password;
6. allow the Secret at least for the `tag` event and save it.

Then include it in the pipeline under any environment variable name:

```yaml
environment:
  REGISTRY_PASSWORD:
    from_secret: target_registry_password
```

This is only the pattern for a later TLS/authenticated registry. Do not add
this Secret to the current HTTP lab.

## 8. Check and commit the release state

Read the Component Version from the lockfile and inspect the working tree:

```bash
export COMPONENT_VERSION="$(
  yq -r '.component.version' \
    "$TARGET_APP_WORKDIR/config/application.lock.yaml"
)"

test -n "$COMPONENT_VERSION"
test "$COMPONENT_VERSION" != 'null'
printf 'Release version: %s\n' "$COMPONENT_VERSION"
git -C "$TARGET_APP_WORKDIR" status --short
```

This lab uses a tag without a leading `v`, for example `0.1.0`. Commit only in
the application repository:

```bash
git -C "$TARGET_APP_WORKDIR" add \
  .gitignore \
  app \
  config \
  delivery \
  scripts \
  .woodpecker/ocm-delivery.yaml

git -C "$TARGET_APP_WORKDIR" diff --cached --stat
git -C "$TARGET_APP_WORKDIR" commit -m 'Configure automated OCM delivery'
git -C "$TARGET_APP_WORKDIR" push origin main
```

The push to `main` may still start `smoke.yaml`. The new `ocm-delivery.yaml` is
skipped because of `event: tag`. This is intentional and lets you check the
configuration in Forgejo before releasing.

## 9. Trigger the release with a Git tag

A Git tag names a fixed commit. A local tag does not trigger CI; only
`git push origin <tag>` sends the event to Forgejo.

Before tagging, check the version and existing tags once more:

```bash
git -C "$TARGET_APP_WORKDIR" status --short
git -C "$TARGET_APP_WORKDIR" tag --list
test -z "$(git -C "$TARGET_APP_WORKDIR" status --porcelain)"
```

The working tree must be clean and the release tag must not already exist.
Create and push it:

```bash
git -C "$TARGET_APP_WORKDIR" tag -a "$COMPONENT_VERSION" \
  -m "Release $COMPONENT_VERSION"
git -C "$TARGET_APP_WORKDIR" push origin "$COMPONENT_VERSION"
```

Open `http://woodpecker.ocm.test:8080`, choose
`ocm-admin/target-application`, then **Pipelines**. A run with event `tag` must
appear. Open the run and then a step name to see live output.

In parallel, watch the short-lived Kubernetes resources:

```bash
kubectl -n woodpecker get pods,pvc --watch
```

The first run can take longer: OCM downloads every image referenced in the
lockfile and writes its layers into the self-contained CTF.

## 10. Verify the result independently

Both Woodpecker steps must be green. Afterwards, read the name and version from
the lockfile:

```bash
export COMPONENT_NAME="$(
  yq -r '.component.name' \
    "$TARGET_APP_WORKDIR/config/application.lock.yaml"
)"

ocm get component-version \
  "oci::http://localhost:5000/ocm//${COMPONENT_NAME}:${COMPONENT_VERSION}"
```

The output must contain the chart, values, additional Resources, and every
locked image. The registry catalog is an additional, less meaningful check:

```bash
curl --fail --show-error http://localhost:5000/v2/_catalog
```

`_catalog` shows only repository names. The OCM query is the actual proof that
the Component Version is readable.

## Troubleshooting

### No pipeline run appears after the tag

- In Forgejo, check the last delivery attempt under **Repository Settings ->
  Webhooks**.
- Check that the repository is enabled in Woodpecker.
- Use `git -C "$TARGET_APP_WORKDIR" ls-remote --tags origin` to verify that the
  tag was actually pushed.
- Check indentation and the file extension of
  `.woodpecker/ocm-delivery.yaml`.

### `ImagePullBackOff` for the tool image

```bash
kubectl -n woodpecker describe pod <PODNAME>
curl --fail --show-error \
  http://localhost:5000/v2/lab/ocm-delivery/tags/list
```

Then repeat the Kubernetes test from section 4. The pipeline file must use
exactly the image tag that was pushed.

### `connection refused` on `localhost:5000`

A pipeline process is using the wrong perspective. Keep `localhost:5000/...`
in `image:`; in `OCM_REPOSITORY` and Skopeo commands inside the pod, use
`k3d-registry.localhost:5000`.

### HTTPS error against the HTTP registry

- Skopeo needs `--tls-verify=false` in the lab.
- OCM needs the `http://` prefix in the repository address.
- For a real TLS registry, remove these exceptions.

### Tag and lockfile version differ

The first pipeline step stops deliberately. Do not change an already pushed
release tag afterwards. Correct the lockfile, commit the change, and create a
new Component Version with a new tag.

### `Target already exists`

The release scripts do not overwrite Component output. In a normal Woodpecker
run, the checkout is fresh. If the error still occurs,
`component-constructor-<version>.yaml`, `transport-archive-<version>`, or
`transport-archive-<version>.descriptor-source` were accidentally committed to
the Git repository. Remove those generated files from Git and add them to
`.gitignore`.

## Acceptance

- The tool image is available as `localhost:5000/lab/ocm-delivery:0.1.0` in the
  local registry and can start as a Kubernetes pod.
- Only `target-application` contains the active release pipeline.
- A pushed Git tag triggers exactly the OCM workflow.
- The tag and `component.version` are identical.
- `ocm get component-version` shows the published version with all Resources.

Manual OCM delivery from Part B is now automated as a reproducible CI release.
