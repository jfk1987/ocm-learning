# OCM 01 – Inventory, digests, and stable identities

**Goal:** You understand the generated lockfile and can prove that the
rendered deployment, values, and OCM inputs refer to the same images.

## What actually happens in this chapter

OCM 00 recorded the same three images in several places. This is not pointless
duplication: each file shows a different view of the release.

```text
rendered Kubernetes manifest ── what would actually be started later
Helm values                  ── configuration passed to Helm
application.lock.yaml        ── what is approved for the OCM release
```

In this chapter, you compare these views and use a validator to prevent them
from drifting apart unnoticed.

## 1. Read the three inventory views side by side

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

cat "$DELIVERY_DIR/images.discovered.txt"
yq '.images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
yq '.images' "$DELIVERY_DIR/values-airgap.yaml"
```

### What the commands show

| Command | View of the release |
| --- | --- |
| `cat images.discovered.txt` | Image references that actually appeared after `helm template` rendered the manifest |
| `yq '.images' application.lock.yaml` | Images with OCM Resource names, versions, platforms, and approved digests |
| `yq '.images' values-airgap.yaml` | Image references Helm uses while rendering |

Find `web-image` in the lockfile. Its `imageReference` must refer to the same
Nginx content that appears in the values and rendered inventory. The field
names differ; the referenced content does not.

### Distinguish a tag from a digest

A reference looks approximately like this:

```text
public.ecr.aws/docker/library/nginx:1.27.4-alpine@sha256:abc123...
└──────────────── Repository ────────────────┘ └── Tag ──┘ └── Digest ──┘
```

The tag is understandable but can generally be moved. The digest is the
fingerprint of one concrete manifest. The combination is readable and fixed
to content. `latest` would be neither a version nor a reproducible release
state, so it is forbidden.

## 2. Understand why the platform is part of the identity

A registry digest can point to a multi-architecture index or a single
manifest. The preparation script explicitly asks `skopeo` for `linux/amd64`
or `linux/arm64`. The same properties later appear on the OCM Resource:

```yaml
name: web-image
extraIdentity:
  os: linux
  architecture: arm64
```

The name `web-image` only answers “which role?” The `extraIdentity` also
answers “for which platform?” These two Resources can therefore coexist:

```text
name=web-image, os=linux, architecture=amd64
name=web-image, os=linux, architecture=arm64
```

They have the same functional name, but not the same Resource Identity.

## 3. Validate the release contract

```bash
"$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR"
```

The script receives two inputs: first the lockfile, then the directory holding
its related files. It reads and compares them but changes nothing. On success,
it ends with:

```text
Application lockfile is valid: .../config/application.lock.yaml
```

Among other things, it checks:

- SemVer, provider, and stable Resource names;
- whether chart, values, and additional Resources actually exist;
- whether the calculated SHA-256 digest of the chart matches the lockfile;
- `tag@sha256` and OS/architecture for every image;
- no duplicate Resource identities or placeholders;
- the same image set in lockfile, values, and rendered inventory.

Exit code `0` means “all conditions passed.” Any other exit code stops the
release and names the violated condition.

## 4. Trigger the guard deliberately

The following negative test works on a copy under `/tmp`; your real lockfile
remains unchanged:

```bash
cp "$TARGET_APP_WORKDIR/config/application.lock.yaml" /tmp/application.invalid.yaml
yq -i '.images[0].version = "latest"' /tmp/application.invalid.yaml
if "$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  /tmp/application.invalid.yaml "$DELIVERY_DIR"; then
  echo 'ERROR: invalid lockfile was accepted.' >&2
  false
else
  echo 'Expected error was detected.'
fi
```

### The shell logic behind it

1. `cp` creates a safe working copy.
2. `yq -i` changes the first image version in that copy to `latest`. `-i`
   means “in place,” so the file is overwritten.
3. `if VALIDATOR; then` branches based on the validator's exit code.
4. If the validator accepts the bad version, the `then` branch runs and marks
   that as an error.
5. If the validator rejects it as expected, the `else` branch runs and the
   test succeeds.

The validator's red error message is desirable here. You are proving not only
the success path, but also that an invalid input is stopped.

## 5. Why a constructor is generated next

`application.lock.yaml` is the human-reviewed release contract. The OCM CLI
expects a different build structure called the Component Constructor. It is
derived from the lockfile:

```text
application.lock.yaml   --generator-->   component-constructor-0.1.0.yaml
human-reviewed                            processed by the OCM CLI
```

Maintaining both manually could let digests, names, or versions drift apart.
The lockfile is therefore the source, and the Constructor is a disposable
build result.

## Checkpoint

You should now be able to justify three statements:

1. A tag names a state; a digest binds the exact content.
2. Lockfile, values, and rendered manifest must contain the same images.
3. An expected validator error in the negative test is a successful test.

Next: [OCM 02 – Constructor and CTF](02-komponente.md).
