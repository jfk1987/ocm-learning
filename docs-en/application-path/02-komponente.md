# OCM 02 – Constructor, descriptor, and self-contained CTF

**Goal:** You create the first Component Version, inspect its model objects,
and materialize every external image into a CTF.

## What actually happens in this chapter

So far there is an approved release contract and a set of files, but no OCM
object. This chapter moves through three different representations:

```text
application.lock.yaml
        │ generator translates the release contract
        ▼
Component Constructor
        │ ocm add component-version builds the descriptor
        ▼
descriptor CTF with some external accesses
        │ ocm transfer copies every Resource
        ▼
self-contained CTF with local blobs
```

The Constructor is the build instruction. The Component Descriptor is the
built OCM table of contents. The CTF is storage that can transport the
descriptor and Resource contents.

## 1. Load paths, name, and version from the lockfile

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
```

The `$(...)` form is command substitution: the shell runs the inner command
and inserts its output as the value. `yq -r` reads one YAML value without
additional quotation marks.

Inspect the values instead of trusting them blindly:

```bash
printf 'Component: %s\nVersion: %s\n' "$COMPONENT_NAME" "$COMPONENT_VERSION"
```

The expected values are `example.org/team/target-application` and `0.1.0`.

## 2. Generate the Component Constructor

```bash
"$TARGET_APP_WORKDIR/scripts/generate-component-constructor.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
```

The call passes three arguments:

1. the approved lockfile as the source;
2. the working directory holding chart, values, and source archive;
3. the path of the Constructor file to create.

The script validates the lockfile again before translating its fields into the
schema understood by `ocm add component-version`. It refuses to overwrite an
existing output file, preventing an old build from being mixed with new inputs
without notice.

Display the Constructor:

```bash
yq '.' "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
```

### `input` and `access` describe different viewpoints

| Field | Question | Example in this lab |
| --- | --- | --- |
| `input` | Where does the builder obtain local data? | `./target-application-chart.tgz`, `./values-airgap.yaml`, `./source` |
| `access` in the Constructor | Where is an existing external Resource? | digest-pinned OCI image reference |
| `access` in the finished descriptor | Where can a consumer find the built Resource? | later a local CTF blob or registry access |

Look for `labels`, `sources`, `resources`, `extraIdentity`, `input`, and
`access` in that order. You should find one Source and six Resources: chart,
values, source archive, and three images.

## 3. Build the Component Version and collect all content

```bash
"$TARGET_APP_WORKDIR/scripts/build-self-contained-ctf.sh" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml" "$DELIVERY_DIR" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"
```

This one script call wraps two important OCM operations:

```text
1. ocm add component-version
   Constructor + local files → transport-archive-0.1.0.descriptor-source/

2. ocm transfer component-version --recursive --copy-resources --upload-as localBlob
   first CTF + external images → transport-archive-0.1.0/
```

The first CTF already describes the Component Version, but its images may
still use external registry accesses. The transfer reads every Resource,
checks its content, and writes it as a local blob to the second CTF. The
options mean:

| Option | Effect |
| --- | --- |
| `--recursive` | Also transfers referenced Components; the core path has none yet, but keeps the full semantics. |
| `--copy-resources` | Copies Resource contents rather than carrying only their access addresses. |
| `--upload-as localBlob` | Stores the copied contents directly inside the CTF. |

This step requires Internet access on the connected station. The first run may
take several minutes and produce considerable console output because OCM
downloads all layers of the three images. This is the point where references
to external content become a physically self-contained transport archive.

### Observe the resulting storage

```bash
du -sh "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"*
find "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" -maxdepth 2 -type f | sort | head
```

The final CTF is much larger than a descriptor alone because it now contains
the chart, values, source archive, and image layers.

## 4. Read the OCM address and inspect the descriptor

```bash
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/component.yaml"
```

Read the long address from left to right:

```text
ctf::PATH//COMPONENT:VERSION
│    │     │         └── concrete release state
│    │     └──────────── product identity
│    └────────────────── CTF directory
└─────────────────────── repository type
```

The first command prints a human-readable summary. The second requests YAML
and writes it to `component.yaml` using `>`. Again, redirection explains why
the full YAML does not appear in the terminal.

Inspect the Source and Resources deliberately:

```bash
yq '.[0].component.sources' "$DELIVERY_DIR/component.yaml"
yq '.[0].component.resources[] | {name, version, extraIdentity, access, digest}' \
  "$DELIVERY_DIR/component.yaml"
```

Every Resource must have a digest. The Git Source remains a provenance
reference; `source-archive` is its transported snapshot. In the final CTF, the
three image Resources should have local blob accesses instead of exclusively
pointing to their upstream registry.

## 5. Download a Resource by its identity

```bash
mkdir -p "$DELIVERY_DIR/inspect"
ocm download resource \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/inspect/values.yaml" \
  --extraction-policy disable
diff -u "$DELIVERY_DIR/values-airgap.yaml" "$DELIVERY_DIR/inspect/values.yaml"
```

OCM does not search for a filename inside the CTF. It selects the Resource
with the stable Identity `name=deployment-values` and follows its `access` to
the corresponding blob. `--extraction-policy disable` outputs exactly that
blob instead of unpacking it automatically.

`diff -u` prints nothing and returns exit code `0` when files are identical. A
silent console is therefore the evidence that the downloaded values are
byte-for-byte identical to the original file.

## Checkpoint

The descriptor contains one Source, six Resources, labels, and digests. The
three images have OS/architecture `extraIdentity` and local blob accesses. You
should also be able to explain Constructor, descriptor, and CTF in one sentence
each.

Next: [OCM 03 – Sign and transport](03-registry-import.md).
