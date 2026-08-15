# OCM 03 – Sign, verify, and transport physically

**Goal:** The Component Version is signed before crossing the zone boundary,
packaged portably, and verified on the target side before extraction.

## 1. Create lab keys

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"

"$TARGET_APP_WORKDIR/scripts/create-signing-config.sh" \
  "$TARGET_APP_WORKDIR/.lab/signing"
export OCM_CONFIG="$TARGET_APP_WORKDIR/.lab/signing/signer.ocmconfig"
```

The private key stays on the connected station. In production it belongs in an
HSM or secret manager; local PEM files are used here only for learning.

## 2. Sign the Component Version and verify it immediately

```bash
ocm sign component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm verify component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"

ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml | yq '.[0].component.signatures'
```

OCM signs the normalized descriptor. Because it contains the Resource digests,
the signature covers the complete delivery relationship.

## 3. Package the CTF for the transfer gate

```bash
mkdir -p "$DELIVERY_DIR/export"
"$TARGET_APP_WORKDIR/scripts/pack-ctf.sh" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" \
  "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"
```

The `.sha256` file intentionally contains only the relative file name. It
therefore remains usable after a USB, SFTP, or data-diode transfer.

Simulate the physical zone boundary with a second directory:

```bash
mkdir -p "$PWD/.lab/airgap-inbox"
cp "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"* \
  "$PWD/.lab/airgap-inbox/"
cp "$TARGET_APP_WORKDIR/.lab/signing/public-key.pem" \
  "$TARGET_APP_WORKDIR/.lab/signing/verifier.ocmconfig" \
  "$PWD/.lab/airgap-inbox/"
```

Do **not** copy `private-key.pem` or `signer.ocmconfig`.

## 4. Verify the hash and signature on the target side

```bash
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
"$TARGET_APP_WORKDIR/scripts/verify-ctf-package.sh" \
  "$AIRGAP_INBOX/target-application-$COMPONENT_VERSION.ctf.tgz" \
  "$AIRGAP_INBOX/unpacked"

# The copied verifier still contains the source path. For this simulation,
# only the public-key path is localized.
sed "s#publicKeyPEMFile: .*#publicKeyPEMFile: $AIRGAP_INBOX/public-key.pem#" \
  "$AIRGAP_INBOX/verifier.ocmconfig" > "$AIRGAP_INBOX/verifier-local.ocmconfig"
export OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig"

ocm verify component-version \
  "ctf::$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

The hash and the OCM signature answer different questions: the hash detects
transport errors; the signature binds the contents to the publisher.

## Acceptance

Verification succeeds, no private key is present in the target directory, and
the extracted CTF is readable without upstream access.

Next: [OCM 04 – Air-gap import and deployment](04-deploy.md).
