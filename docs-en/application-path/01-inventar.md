# OCM 01 – Inventory, digests, and stable identities

**Goal:** You understand the generated lockfile and can prove that the
rendered deployment, values, and OCM inputs refer to the same images.

## 1. Read the inventory

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

cat "$DELIVERY_DIR/images.discovered.txt"
yq '.images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
yq '.images' "$DELIVERY_DIR/values-airgap.yaml"
```

Every reference has a tag **and** a digest, for example
`nginx:1.27.4-alpine@sha256:...`. The tag is readable; the digest makes the
content immutable. `latest` is forbidden in this learning path.

## 2. Understand platform binding

A registry digest can point to a multi-architecture index or to one manifest.
The preparation script uses `skopeo` with explicit `linux/amd64` or
`linux/arm64`. The OCM Resource later receives the same properties as
`extraIdentity`:

```yaml
name: web-image
extraIdentity:
  os: linux
  architecture: arm64
```

This allows two platform variants to exist under the same Resource name
without having the same Resource identity.

## 3. Validate the release contract

```bash
"$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR"
```

The check includes, among other things:

- SemVer, provider, and stable Resource names;
- real files and the SHA-256 digest of the chart package;
- `tag@sha256` and OS/architecture for each image;
- no duplicate Resource identities or placeholders;
- identical image sets in the lockfile, values, and rendered inventory.

Try the guard in a controlled way without saving the real file:

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

## 4. Why the constructor is generated

`application.lock.yaml` is the human-reviewed release contract. The OCM
constructor is a derived build input. Maintaining both manually could let
digests, names, or versions drift apart.

## Acceptance

The validator exits successfully, the negative test fails as expected, and you
can find `web-image`, `redis-image`, and `toolbox-image` in the rendered
manifest.

Next: [OCM 02 – Constructor and CTF](02-komponente.md).
