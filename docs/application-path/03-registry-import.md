# OCM 03 – Signieren, prüfen und physisch transportieren

**Ziel:** Die Component Version wird vor dem Zonentransfer signiert, portabel
verpackt und auf der Zielseite vor dem Entpacken geprüft.

## Was in diesem Kapitel wirklich passiert

Der selbstständige CTF enthält jetzt alle Lieferinhalte. Vor dem Transport
kommen zwei voneinander unabhängige Schutzmechanismen hinzu:

```text
Component Descriptor --OCM-Signatur--> Herausgeber und Lieferbeziehung prüfen
CTF-Tarball          --SHA-256-Datei--> Transportfehler am Paket erkennen
```

Die Signatur sagt, wer den beschriebenen Release freigegeben hat. Der
Paket-Hash sagt, ob das transportierte Archiv noch exakt dieselben Bytes hat.

## 1. Lab-Schlüssel und getrennte Konfigurationen erzeugen

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"

"$TARGET_APP_WORKDIR/scripts/create-signing-config.sh" \
  "$TARGET_APP_WORKDIR/.lab/signing"
export OCM_CONFIG="$TARGET_APP_WORKDIR/.lab/signing/signer.ocmconfig"
```

Das Skript erzeugt vier Dateien:

| Datei | Inhalt und erlaubter Ort |
| --- | --- |
| `private-key.pem` | Privater RSA-Schlüssel; bleibt auf der Connected Station |
| `public-key.pem` | Öffentlicher Schlüssel; darf in die Zielzone |
| `signer.ocmconfig` | OCM-Konfiguration mit privatem und öffentlichem Schlüssel; bleibt an der Quelle |
| `verifier.ocmconfig` | OCM-Konfiguration nur mit öffentlichem Schlüssel; darf in die Zielzone |

`export OCM_CONFIG=...` teilt der OCM CLI mit, welche zusätzliche
Konfigurationsdatei sie für den nächsten Aufruf verwenden soll. Der private
Schlüssel liegt in diesem Lab lokal; in Produktion gehört er in ein HSM oder
einen Secret Manager.

Kontrolliere die Dateirechte und Namen, ohne Schlüsselinhalt auszugeben:

```bash
ls -l "$TARGET_APP_WORKDIR/.lab/signing"
```

## 2. Die Component Version signieren und sofort prüfen

```bash
ocm sign component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm verify component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`ocm sign` normalisiert den Component Descriptor, berechnet daraus die
Signatur mit dem privaten Schlüssel und trägt die Signatur in die Component
Version ein. Der Descriptor enthält die Digests aller Resources. Dadurch
bindet die Signatur nicht nur Namen, sondern die gesamte Zuordnung von
Component Version zu konkreten Resource-Inhalten.

`ocm verify` wiederholt die Berechnung mit dem öffentlichen Schlüssel. Es
beweist nicht, dass du dem Herausgeber fachlich vertrauen solltest; es beweist,
dass die Signatur zum Descriptor und zum verwendeten Schlüssel gehört.

Zeige nur den neu entstandenen Signaturabschnitt:

```bash
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml | yq '.[0].component.signatures'
```

## 3. Den CTF als portables Schleusenpaket verpacken

```bash
mkdir -p "$DELIVERY_DIR/export"
"$TARGET_APP_WORKDIR/scripts/pack-ctf.sh" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" \
  "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"
```

Ein CTF ist ein Verzeichnis. Für USB, SFTP oder eine Datendiode verpackt das
Skript dieses Verzeichnis als komprimiertes Tar-Archiv und erzeugt daneben
eine Prüfsummendatei:

```text
target-application-0.1.0.ctf.tgz
target-application-0.1.0.ctf.tgz.sha256
```

Die `.sha256`-Datei enthält nur den relativen Dateinamen. Deshalb funktioniert
die Prüfung auch dann, wenn beide Dateien später in einem anderen Verzeichnis
liegen.

Mache Größe und Hash sichtbar:

```bash
ls -lh "$DELIVERY_DIR/export"
cat "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz.sha256"
```

## 4. Eine physische Zonengrenze simulieren

```bash
mkdir -p "$PWD/.lab/airgap-inbox"
cp "$DELIVERY_DIR/export/target-application-$COMPONENT_VERSION.ctf.tgz"* \
  "$PWD/.lab/airgap-inbox/"
cp "$TARGET_APP_WORKDIR/.lab/signing/public-key.pem" \
  "$TARGET_APP_WORKDIR/.lab/signing/verifier.ocmconfig" \
  "$PWD/.lab/airgap-inbox/"
```

Das zweite Verzeichnis steht für die Eingangsseite der getrennten Zone. Der
Wildcard `*` im ersten `cp` trifft sowohl das Archiv als auch seine
`.sha256`-Datei. Kopiert werden außerdem nur öffentlicher Schlüssel und
Verifier-Konfiguration.

Prüfe die Grenze ausdrücklich:

```bash
find "$PWD/.lab/airgap-inbox" -maxdepth 1 -type f -print
test ! -e "$PWD/.lab/airgap-inbox/private-key.pem" \
  && echo 'OK: kein privater Schlüssel in der Zielzone'
```

`private-key.pem` und `signer.ocmconfig` dürfen die Connected Station nicht
verlassen.

## 5. Auf der Zielseite zuerst den Hash und dann die Signatur prüfen

```bash
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
"$TARGET_APP_WORKDIR/scripts/verify-ctf-package.sh" \
  "$AIRGAP_INBOX/target-application-$COMPONENT_VERSION.ctf.tgz" \
  "$AIRGAP_INBOX/unpacked"
```

Das Skript berechnet den SHA-256-Wert des angekommenen Tarballs und vergleicht
ihn mit der `.sha256`-Datei. Erst nach erfolgreichem Vergleich entpackt es den
CTF nach `unpacked/`. Eine typische Erfolgsausgabe enthält `OK` und
`CTF verified and extracted`.

Die kopierte Verifier-Konfiguration enthält noch den absoluten Quellpfad des
öffentlichen Schlüssels. Für die Simulation wird ausschließlich dieser Pfad
lokalisiert:

```bash
sed "s#publicKeyPEMFile: .*#publicKeyPEMFile: $AIRGAP_INBOX/public-key.pem#" \
  "$AIRGAP_INBOX/verifier.ocmconfig" > "$AIRGAP_INBOX/verifier-local.ocmconfig"
export OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig"

ocm verify component-version \
  "ctf::$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`sed` schreibt wegen `>` eine neue Datei; die transportierte Originaldatei
bleibt als Nachweis erhalten. `OCM_CONFIG` zeigt danach auf die
Verifier-Konfiguration ohne privaten Schlüssel. Die abschließende
OCM-Verifikation prüft die Signatur der entpackten Component Version.

## Hash und Signatur nicht verwechseln

| Prüfung | Erkennt | Erkennt nicht |
| --- | --- | --- |
| SHA-256-Datei des Tarballs | versehentliche Änderung oder Beschädigung beim Transport | wer das Paket freigegeben hat, wenn Hash und Paket gemeinsam ersetzt würden |
| OCM-Signatur | ob Descriptor und Resource-Digests zum Herausgeberschlüssel passen | ob der Tarball beim Kopieren bytegleich blieb |

Darum werden beide Prüfungen ausgeführt.

## Checkpoint

Die Hashprüfung und OCM-Verifikation melden Erfolg. In `airgap-inbox` liegt
kein privater Schlüssel, und die entpackte Component Version kann vollständig
aus dem CTF gelesen werden.

Weiter mit [OCM 04 – Air-Gap-Import und Deployment](04-deploy.md).
