# OCM 03 – Signieren, prüfen und physisch transportieren

**Ziel:** Die Component Version wird vor dem Zonentransfer signiert, portabel
verpackt und auf der Zielseite vor dem Entpacken geprüft.

## 1. Lab-Schlüssel erzeugen

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"

"$TARGET_APP_WORKDIR/scripts/create-signing-config.sh" \
  "$TARGET_APP_WORKDIR/.lab/signing"
export OCM_CONFIG="$TARGET_APP_WORKDIR/.lab/signing/signer.ocmconfig"
```

Der private Schlüssel bleibt auf der Connected Station. In Produktion gehört
er in HSM oder Secret Manager; lokale PEM-Dateien dienen hier nur dem Lernen.

## 2. Component Version signieren und sofort prüfen

```bash
ocm sign component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm verify component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"

ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml | yq '.[0].component.signatures'
```

OCM signiert den normalisierten Descriptor. Weil dieser die Digests der
Resources enthält, deckt die Signatur die gesamte Lieferbeziehung ab.

## 3. CTF als Schleusenpaket verpacken

```bash
mkdir -p "$DELIVERY_DIR/export"
"$TARGET_APP_WORKDIR/scripts/pack-ctf.sh" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" \
  "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"
```

Die `.sha256`-Datei enthält absichtlich nur den relativen Dateinamen. Dadurch
funktioniert sie nach USB-, SFTP- oder Datendiode-Transfer weiterhin.

Simuliere die physische Zonengrenze mit einem zweiten Verzeichnis:

```bash
mkdir -p "$PWD/.lab/airgap-inbox"
cp "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"* \
  "$PWD/.lab/airgap-inbox/"
cp "$TARGET_APP_WORKDIR/.lab/signing/public-key.pem" \
  "$TARGET_APP_WORKDIR/.lab/signing/verifier.ocmconfig" \
  "$PWD/.lab/airgap-inbox/"
```

Kopiere **nicht** `private-key.pem` oder `signer.ocmconfig`.

## 4. Auf der Zielseite Hash und Signatur prüfen

```bash
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
"$TARGET_APP_WORKDIR/scripts/verify-ctf-package.sh" \
  "$AIRGAP_INBOX/target-application-$COMPONENT_VERSION.ctf.tgz" \
  "$AIRGAP_INBOX/unpacked"

# Der kopierte Verifier enthält noch den Quellpfad. Für die Simulation wird
# nur der Public-Key-Pfad lokalisiert.
sed "s#publicKeyPEMFile: .*#publicKeyPEMFile: $AIRGAP_INBOX/public-key.pem#" \
  "$AIRGAP_INBOX/verifier.ocmconfig" > "$AIRGAP_INBOX/verifier-local.ocmconfig"
export OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig"

ocm verify component-version \
  "ctf::$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

Hash und OCM-Signatur beantworten unterschiedliche Fragen: Der Hash erkennt
Transportfehler; die Signatur bindet die Inhalte an den Herausgeber.

## Abnahme

Die Verifikation meldet Erfolg, im Zielverzeichnis liegt kein privater
Schlüssel, und das entpackte CTF ist ohne Upstream-Zugriff lesbar.

Weiter mit [OCM 04 – Air-Gap-Import und Deployment](04-deploy.md).
