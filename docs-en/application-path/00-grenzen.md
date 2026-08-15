# OCM 00 – Prepare the target application and understand the model

**Goal:** The Forgejo repository contains a concrete, runnable application and
you can distinguish a Source, Resource, and Component Version.

This part begins after Labs 00 through 03. The preparation lab may access the
Internet; only the later target cluster is isolated.

## 1. Create the application

From the `ocm-learning` root directory:

```bash
. config/lab.env
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"

./scripts/prepare-target-application.sh "$TARGET_APP_WORKDIR"
```

The script deliberately handles the error-prone initial preparation:

- copies the checked-in demo chart to `app/`;
- resolves Nginx, Redis, and BusyBox digests for the host architecture;
- packages the chart and creates digest-pinned values;
- renders all Kubernetes objects and inventories containers, init containers,
  and Helm hooks;
- creates and validates `config/application.lock.yaml`;
- copies release scripts and the later Woodpecker pipeline.

The application is small but not trivial: a web Deployment waits in an init
container for a Redis StatefulSet; it also has a migration hook and a Helm
test. This requires three different runtime images.

```bash
git -C "$TARGET_APP_WORKDIR" status --short
helm template target-application "$TARGET_APP_WORKDIR/app" \
  --namespace target-application >/tmp/target-application.yaml
```

## 2. Map the OCM terms to this repository

| OCM term | Concrete object in this lab |
| --- | --- |
| Component | `example.org/team/target-application` |
| Component Version | The same name plus `0.1.0` |
| Source | Git origin with repository and release tag |
| Resource | Source archive, chart, values, and three OCI images |
| Resource Identity | For example `name=web-image`, plus OS/architecture as `extraIdentity` |
| Provider | `example.org`; describes the publisher, not the registry |
| CTF | Portable storage for one or more Component Versions |

A **Source** describes where the component was built from using Git access.
The actual source copy also travels as a `source-archive` Resource because
`--copy-resources` deliberately materializes resources. A **Resource** is a
deliverable result. A Component Descriptor holds identities, accesses, and
digests together; the CTF is its transport container.

## 3. Record the delivery boundary

The delivery contains the chart, values, all three images, and optional
migration/configuration artifacts. It does not contain Kubernetes, k3d,
Forgejo, Woodpecker, the registry, CNI, StorageClass, or ingress controller.
Secrets do not belong in the CTF either.

This boundary prevents two common misunderstandings: the lab itself does not
need to be air-gapped, and OCM replaces neither Kubernetes nor Helm.

## Acceptance

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz"
test "$(wc -l < "$TARGET_APP_WORKDIR/delivery/target-application/images.discovered.txt" | tr -d ' ')" = 3
```

Next: [OCM 01 – Inventory and identities](01-inventar.md).
