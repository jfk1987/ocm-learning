# OCM 02 – Constructor, descriptor, and self-contained CTF

**Goal:** You create the first Component Version, inspect its model objects,
and materialize all external images into a CTF.

## 1. Generate the constructor

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"

"$TARGET_APP_WORKDIR/scripts/generate-component-constructor.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
yq '.' "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
```

Look for `labels`, `sources`, `resources`, `extraIdentity`, `input`, and
`access` in that order. `input` tells the builder where data comes from. In
the finished descriptor, `access` describes where OCM finds it.

## 2. Build the descriptor CTF first

The build script creates two CTFs internally. The first may still contain
external image accesses. The second becomes self-contained with
`--copy-resources` and `--upload-as localBlob`:

```bash
"$TARGET_APP_WORKDIR/scripts/build-self-contained-ctf.sh" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml" "$DELIVERY_DIR" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"
```

This step needs Internet access on the connected station and may take several
minutes the first time because all image layers are downloaded.

## 3. Inspect the Component Descriptor

```bash
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/component.yaml"

yq '.[0].component.sources' "$DELIVERY_DIR/component.yaml"
yq '.[0].component.resources[] | {name, version, extraIdentity, access, digest}' \
  "$DELIVERY_DIR/component.yaml"
```

Every Resource must have a digest. The Git Source remains a provenance
reference; `source-archive` is its transported snapshot. In the final CTF, the
image Resources must no longer only point to Docker Hub. OCM has materialized
them as local blobs.

## 4. Try Resource selection in practice

OCM selects Resources by identity, not by their file position:

```bash
mkdir -p "$DELIVERY_DIR/inspect"
ocm download resource \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/inspect/values.yaml" \
  --extraction-policy disable
diff -u "$DELIVERY_DIR/values-airgap.yaml" "$DELIVERY_DIR/inspect/values.yaml"
```

## Acceptance

The descriptor contains one Source, six Resources, labels, digests, and
OS/architecture `extraIdentity` on all three images. The downloaded values are
byte-for-byte identical to the input.

Next: [OCM 03 – Sign and transport](03-registry-import.md).
