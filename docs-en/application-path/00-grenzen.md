# OCM 00 – Prepare the target application and understand the model

**Goal:** The Forgejo repository contains a concrete, runnable application and
you can distinguish a Source, Resource, and Component Version.

This chapter begins after Labs 00 through 03. The preparation lab may access
the Internet; only the later target cluster is isolated.

## What actually happens in this chapter

At the beginning, there is a separate, mostly empty Git repository for the
target application. At the end, it contains the application code and all
inputs needed for a reproducible release:

```text
target-application/
├── app/                          Helm chart and application templates
├── config/application.lock.yaml release contract
├── delivery/target-application/ packaged chart, values, and inventory
└── scripts/                      tools for the following OCM steps
```

Nothing is installed in Kubernetes yet, and no OCM Component Version is built
yet. This step only prepares the inputs.

## 1. Point the shell at the application repository

Run these commands from the `ocm-learning` root directory:

```bash
. config/lab.env
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"
```

### Command by command

| Expression | Meaning |
| --- | --- |
| `. config/lab.env` | Reads the lab variables into the **current** shell. The dot is the short form of `source`. |
| `"$PWD"` | The absolute path of the current directory. |
| `export NAME=...` | Sets a variable and passes it to scripts started later. |
| `test -d .../.git` | Checks whether the target repository exists. Success is deliberately silent; failure returns a non-zero exit code. |

Make the two important paths visible once:

```bash
printf 'Learning repository: %s\n' "$LAB_REPO_ROOT"
printf 'Application repository: %s\n' "$TARGET_APP_WORKDIR"
git -C "$TARGET_APP_WORKDIR" status --short --branch
```

`ocm-learning` contains the instructions and generators. `target-application`
is the product that will later be delivered as an OCM Component Version. The
two directories deliberately have different responsibilities.

## 2. Create the application and release contract

```bash
./scripts/prepare-target-application.sh "$TARGET_APP_WORKDIR"
```

In plain language, this call means: “Take the demo application from this
learning repository, resolve every mutable external input, and write a
verifiable release state into the separate application repository.”

The script performs these state changes in sequence:

1. It copies the demo Helm chart to `app/`.
2. It asks `skopeo` for the matching architecture-specific digest of Nginx,
   Redis, and BusyBox. This turns a movable tag such as
   `nginx:1.27.4-alpine` into a fixed `tag@sha256:...` reference.
3. It packages the chart as a `.tgz` file and calculates its SHA-256 digest.
4. It writes the fixed image references to `values-airgap.yaml`.
5. It renders the chart locally and collects every image that is actually
   used, including init containers and Helm hooks.
6. It creates `application.lock.yaml` as the release contract and checks that
   lockfile, values, and rendered manifest contain the same images.
7. It copies the release scripts and Woodpecker pipeline into the application
   repository.

The resulting data flow is:

```text
demo chart + external image tags
              │
              ▼
      resolve digests and package chart
              │
              ├── app/
              ├── target-application-chart.tgz
              ├── values-airgap.yaml
              ├── images.discovered.txt
              └── application.lock.yaml
```

The application is small but not trivial: a web Deployment waits in an init
container for a Redis StatefulSet; there is also a migration hook and a Helm
test. All three runtime images therefore need to be inventoried completely.

### Observe the result

```bash
git -C "$TARGET_APP_WORKDIR" status --short
find "$TARGET_APP_WORKDIR" -maxdepth 2 -type f | sort
yq '.component, .images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
```

`git status --short` deliberately shows many new files here: these are the
product and release inputs created by the preparation script. `yq` only shows
selected YAML fields; it does not modify the file.

## 3. Render the Helm chart without installing anything

```bash
helm template target-application "$TARGET_APP_WORKDIR/app" \
  --namespace target-application >/tmp/target-application.yaml
```

`helm template` turns the chart and default values into ordinary Kubernetes
YAML objects. It does not contact a cluster. The `>` redirection writes the
otherwise long output to a file, which is why a successful command prints
nothing to the terminal.

Inspect the result explicitly:

```bash
wc -l /tmp/target-application.yaml
grep -nE '^kind:|^[[:space:]]*image:' /tmp/target-application.yaml
```

You should recognize a Deployment, StatefulSet, Services, Job, and three
different image references. You can now see the future Kubernetes objects even
though nothing has been started.

## 4. Map OCM terms to this repository

| OCM term | Concrete object in this lab | Plain meaning |
| --- | --- | --- |
| Component | `example.org/team/target-application` | The long-lived identity of the product |
| Component Version | the same name plus `0.1.0` | One specific released state |
| Source | Git repository and release tag | Where that state came from |
| Resource | source archive, chart, values, and three OCI images | What is actually delivered |
| Resource Identity | for example `name=web-image` plus OS/architecture | How a Resource is selected unambiguously |
| Provider | `example.org` | Who publishes the Component, not where it is stored |
| Component Descriptor | OCM document created later | Table of contents with identities, accesses, and digests |
| CTF | portable OCM storage | Container for descriptor and Resources |

A **Source** is provenance evidence: “This release was built from this Git
state.” The additional `source-archive` is a transported copy of that state.
A **Resource** is a deliverable result. The later Component Descriptor connects
names, versions, accesses, and digests; a CTF can transport that information
together with the content.

## 5. Understand the delivery boundary

The delivery contains the chart, values, all three images, and optional
migration or configuration artifacts. It does not contain Kubernetes, k3d,
Forgejo, Woodpecker, the registry, CNI, StorageClass, or ingress controller.
Secrets do not belong in the CTF either.

OCM therefore describes and transports the product. It replaces neither the
Kubernetes target platform nor the Helm installation tool.

## Checkpoint

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml" \
  && echo 'OK: lockfile exists'
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz" \
  && echo 'OK: chart is packaged'
test "$(wc -l < "$TARGET_APP_WORKDIR/delivery/target-application/images.discovered.txt" | tr -d ' ')" = 3 \
  && echo 'OK: exactly three runtime images found'
```

Before continuing, you should be able to explain: the lockfile records the
state approved for release; it is not yet an OCM Component Version or a
deployment.

Next: [OCM 01 – Inventory and identities](01-inventar.md).
