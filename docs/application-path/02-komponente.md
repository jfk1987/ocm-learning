# OCM 02 – Constructor, Descriptor und selbstständiges CTF

**Ziel:** Du erzeugst die erste Component Version, inspizierst ihre
Modellobjekte und materialisierst alle externen Images in ein CTF.

## 1. Constructor generieren

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

Suche darin nacheinander `labels`, `sources`, `resources`, `extraIdentity`,
`input` und `access`. `input` sagt dem Erzeuger, woher Daten kommen. Im fertigen
Descriptor beschreibt `access`, wo OCM sie findet.

## 2. Zunächst den Descriptor-CTF bauen

Das Build-Skript erzeugt intern zwei CTFs. Der erste kann noch externe
Image-Zugriffe enthalten. Der zweite wird mit `--copy-resources` und
`--upload-as localBlob` selbstständig:

```bash
"$TARGET_APP_WORKDIR/scripts/build-self-contained-ctf.sh" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml" "$DELIVERY_DIR" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"
```

Dieser Schritt benötigt auf der Connected Station Internetzugang und kann beim
ersten Mal einige Minuten dauern, weil alle Image-Layer geladen werden.

## 3. Component Descriptor inspizieren

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

Bei jeder Resource muss ein Digest vorhanden sein. Die Git-Source bleibt eine
Herkunftsreferenz; `source-archive` ist ihre transportierte Momentaufnahme. Die
Image-Resources dürfen
im finalen CTF nicht mehr nur auf Docker Hub verweisen. OCM hat sie als lokale
Blobs materialisiert.

## 4. Resource-Selektion praktisch ausprobieren

OCM selektiert Resources über Identitäten, nicht über ihre Dateiposition:

```bash
mkdir -p "$DELIVERY_DIR/inspect"
ocm download resource \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/inspect/values.yaml" \
  --extraction-policy disable
diff -u "$DELIVERY_DIR/values-airgap.yaml" "$DELIVERY_DIR/inspect/values.yaml"
```

## Abnahme

Der Descriptor enthält eine Source, sechs Resources, Labels, Digests und
OS/Arch-`extraIdentity` an allen drei Images. Die heruntergeladenen Values sind
bytegleich mit der Eingabe.

Weiter mit [OCM 03 – Signieren und transportieren](03-registry-import.md).
