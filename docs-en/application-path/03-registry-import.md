# OCM 03 – Sign, verify, and transport physically

**Goal:** The Component Version is signed before crossing the zone boundary,
packaged portably, and verified on the target side before extraction.

## What actually happens in this chapter

The self-contained CTF now contains every delivery artifact. Two independent
protection mechanisms are added before transport:

```text
Component Descriptor --OCM signature--> verify publisher and delivery relation
CTF tarball          --SHA-256 file----> detect transport damage to the package
```

The signature says who approved the described release. The package hash says
whether the transported archive still consists of exactly the same bytes.

## 1. Create lab keys and separate configurations

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"

"$TARGET_APP_WORKDIR/scripts/create-signing-config.sh" \
  "$TARGET_APP_WORKDIR/.lab/signing"
export OCM_CONFIG="$TARGET_APP_WORKDIR/.lab/signing/signer.ocmconfig"
```

The script creates four files:

| File | Content and permitted location |
| --- | --- |
| `private-key.pem` | Private RSA key; remains on the connected station |
| `public-key.pem` | Public key; may enter the target zone |
| `signer.ocmconfig` | OCM configuration with private and public keys; remains at the source |
| `verifier.ocmconfig` | OCM configuration with only the public key; may enter the target zone |

`export OCM_CONFIG=...` tells the OCM CLI which additional configuration file
to use for the next commands. The private key is a local file in this lab; in
production, it belongs in an HSM or secret manager.

Inspect file names and permissions without printing any key content:

```bash
ls -l "$TARGET_APP_WORKDIR/.lab/signing"
```

## 2. Sign the Component Version and verify it immediately

```bash
ocm sign component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm verify component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`ocm sign` normalizes the Component Descriptor, calculates a signature using
the private key, and records it on the Component Version. The descriptor
contains every Resource digest. The signature therefore binds not just names,
but the full mapping from Component Version to concrete Resource content.

`ocm verify` repeats the calculation using the public key. It does not prove
that you should trust the publisher as an organization; it proves that the
signature matches the descriptor and the key being used.

Show only the new signature section:

```bash
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml | yq '.[0].component.signatures'
```

## 3. Package the CTF for a portable transfer gate

```bash
mkdir -p "$DELIVERY_DIR/export"
"$TARGET_APP_WORKDIR/scripts/pack-ctf.sh" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" \
  "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"
```

A CTF is a directory. For USB, SFTP, or a data diode, the script packages that
directory as a compressed tar archive and creates a checksum file beside it:

```text
target-application-0.1.0.ctf.tgz
target-application-0.1.0.ctf.tgz.sha256
```

The `.sha256` file contains only the relative filename. Verification therefore
still works after both files are moved to another directory.

Make size and hash visible:

```bash
ls -lh "$DELIVERY_DIR/export"
cat "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz.sha256"
```

## 4. Simulate a physical zone boundary

```bash
mkdir -p "$PWD/.lab/airgap-inbox"
cp "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"* \
  "$PWD/.lab/airgap-inbox/"
cp "$TARGET_APP_WORKDIR/.lab/signing/public-key.pem" \
  "$TARGET_APP_WORKDIR/.lab/signing/verifier.ocmconfig" \
  "$PWD/.lab/airgap-inbox/"
```

The second directory represents the receiving side of the isolated zone. The
`*` wildcard in the first `cp` matches both the archive and its `.sha256`
file. Only the public key and verifier configuration are copied with them.

Check the boundary explicitly:

```bash
find "$PWD/.lab/airgap-inbox" -maxdepth 1 -type f -print
test ! -e "$PWD/.lab/airgap-inbox/private-key.pem" \
  && echo 'OK: no private key in the target zone'
```

`private-key.pem` and `signer.ocmconfig` must not leave the connected station.

## 5. Verify the hash first, then the signature on the target side

```bash
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
"$TARGET_APP_WORKDIR/scripts/verify-ctf-package.sh" \
  "$AIRGAP_INBOX/target-application-$COMPONENT_VERSION.ctf.tgz" \
  "$AIRGAP_INBOX/unpacked"
```

The script calculates the SHA-256 value of the received tarball and compares
it with the `.sha256` file. Only after a successful comparison does it extract
the CTF into `unpacked/`. Typical success output includes `OK` and
`CTF verified and extracted`.

The copied verifier configuration still contains the absolute source path of
the public key. For this simulation, only that path is localized:

```bash
sed "s#publicKeyPEMFile: .*#publicKeyPEMFile: $AIRGAP_INBOX/public-key.pem#" \
  "$AIRGAP_INBOX/verifier.ocmconfig" > "$AIRGAP_INBOX/verifier-local.ocmconfig"
export OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig"

ocm verify component-version \
  "ctf::$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

Because of `>`, `sed` writes a new file; the transported original remains as
evidence. `OCM_CONFIG` now points to the verifier configuration without a
private key. The final OCM verification checks the signature on the extracted
Component Version.

## Do not confuse the hash with the signature

| Check | Detects | Does not detect |
| --- | --- | --- |
| SHA-256 file for the tarball | accidental changes or damage during transport | who approved the package if hash and package were replaced together |
| OCM signature | whether descriptor and Resource digests match the publisher key | whether the tarball remained byte-identical while being copied |

This is why both checks are performed.

## Checkpoint

The hash check and OCM verification succeed. No private key is present in
`airgap-inbox`, and the extracted Component Version can be read entirely from
the CTF.

Next: [OCM 04 – Air-gap import and deployment](04-deploy.md).
