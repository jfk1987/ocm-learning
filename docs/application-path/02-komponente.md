# OCM 02 – Constructor, Descriptor und selbstständiges CTF

**Ziel:** Du erzeugst die erste Component Version, untersuchst ihre
Modellobjekte und materialisierst alle externen Images in ein CTF.

## Was in diesem Kapitel wirklich passiert

Bis hierhin gibt es einen geprüften Freigabevertrag und Dateien, aber noch
kein OCM-Objekt. Dieses Kapitel führt durch drei verschiedene Darstellungen:

```text
application.lock.yaml
        │ Generator übersetzt den Freigabevertrag
        ▼
Component Constructor
        │ ocm add component-version baut den Descriptor
        ▼
Descriptor-CTF mit teilweise externen Zugriffen
        │ ocm transfer kopiert alle Resources
        ▼
selbstständiges CTF mit lokalen Blobs
```

Der Constructor ist die Bauanweisung. Der Component Descriptor ist das
gebaute OCM-Inhaltsverzeichnis. Das CTF ist die Ablage, in der Descriptor und
Resource-Inhalte transportiert werden können.

## 1. Pfade, Name und Version aus dem Lockfile laden

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
```

Die Form `$(...)` heißt Command Substitution: Die Shell führt den inneren
Befehl aus und setzt dessen Ausgabe als Wert ein. `yq -r` liest dabei einen
einzelnen YAML-Wert ohne zusätzliche Anführungszeichen.

Prüfe die Werte, statt ihnen blind zu vertrauen:

```bash
printf 'Component: %s\nVersion: %s\n' "$COMPONENT_NAME" "$COMPONENT_VERSION"
```

Erwartet werden `example.org/team/target-application` und `0.1.0`.

## 2. Den Component Constructor generieren

```bash
"$TARGET_APP_WORKDIR/scripts/generate-component-constructor.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
```

Der Aufruf übergibt drei Argumente:

1. das freigegebene Lockfile als Quelle;
2. das Arbeitsverzeichnis, in dem Chart, Values und Source-Archiv liegen;
3. den Pfad der neu zu erzeugenden Constructor-Datei.

Das Skript validiert zuerst erneut das Lockfile. Danach übersetzt es dessen
Felder in das Schema, das `ocm add component-version` versteht. Eine bereits
vorhandene Ausgabedatei wird nicht überschrieben; so bleibt ein alter Build
nicht unbemerkt mit neuen Eingaben vermischt.

Zeige den Constructor an:

```bash
yq '.' "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml"
```

### `input` und `access` sind zwei verschiedene Blickrichtungen

| Feld | Frage | Beispiel in diesem Lab |
| --- | --- | --- |
| `input` | Woher nimmt der Builder lokale Daten? | `./target-application-chart.tgz`, `./values-airgap.yaml`, `./source` |
| `access` im Constructor | Wo liegt eine bereits vorhandene externe Resource? | digest-gepinnte OCI-Image-Referenz |
| `access` im fertigen Descriptor | Wo findet ein Consumer die gebaute Resource? | später ein lokaler CTF-Blob oder Registry-Zugriff |

Suche nacheinander `labels`, `sources`, `resources`, `extraIdentity`, `input`
und `access`. Du solltest eine Source und sechs Resources erkennen: Chart,
Values, Source-Archiv sowie drei Images.

## 3. Die Component Version bauen und alle Inhalte einsammeln

```bash
"$TARGET_APP_WORKDIR/scripts/build-self-contained-ctf.sh" \
  "$DELIVERY_DIR/component-constructor-$COMPONENT_VERSION.yaml" "$DELIVERY_DIR" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" \
  "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"
```

Der eine Skriptaufruf kapselt zwei wichtige OCM-Operationen:

```text
1. ocm add component-version
   Constructor + lokale Dateien → transport-archive-0.1.0.descriptor-source/

2. ocm transfer component-version --recursive --copy-resources --upload-as localBlob
   erster CTF + externe Images → transport-archive-0.1.0/
```

Der erste CTF beschreibt bereits die Component Version, darf für die Images
aber noch Zugriffe auf externe Registries enthalten. Der Transfer liest jede
Resource, prüft ihren Inhalt und schreibt sie als lokalen Blob in den zweiten
CTF. Die Optionen bedeuten:

| Option | Wirkung |
| --- | --- |
| `--recursive` | Überträgt auch referenzierte Komponenten; im Kernpfad gibt es noch keine, die Semantik bleibt aber vollständig. |
| `--copy-resources` | Kopiert Resource-Inhalte statt nur ihre Zugriffsadressen zu übernehmen. |
| `--upload-as localBlob` | Speichert die kopierten Inhalte direkt im CTF. |

Dieser Schritt benötigt auf der Connected Station Internetzugang. Beim ersten
Lauf können mehrere Minuten und viel Konsolenausgabe entstehen, weil OCM die
Layer aller drei Images lädt. Das ist der Moment, in dem aus Verweisen auf
externe Inhalte ein physisch selbstständiges Transportarchiv wird.

### Die entstandenen Ablagen beobachten

```bash
du -sh "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"*
find "$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION" -maxdepth 2 -type f | sort | head
```

Der endgültige CTF ist wesentlich größer als ein reiner Descriptor, weil er
nun Chart, Values, Source-Archiv und Image-Layer enthält.

## 4. Die OCM-Adresse lesen und den Descriptor untersuchen

```bash
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION"
ocm get component-version \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/component.yaml"
```

Die lange Adresse lässt sich von links nach rechts lesen:

```text
ctf::PFAD//COMPONENT:VERSION
│    │     │         └── konkreter Release-Stand
│    │     └──────────── Produktidentität
│    └────────────────── Verzeichnis des CTF
└─────────────────────── Repository-Typ
```

Der erste Befehl zeigt eine menschenlesbare Zusammenfassung. Der zweite
fordert YAML an und schreibt es mit `>` in `component.yaml`. Auch hier erklärt
die Umleitung, warum die vollständige YAML-Ausgabe nicht im Terminal steht.

Untersuche gezielt Source und Resources:

```bash
yq '.[0].component.sources' "$DELIVERY_DIR/component.yaml"
yq '.[0].component.resources[] | {name, version, extraIdentity, access, digest}' \
  "$DELIVERY_DIR/component.yaml"
```

Bei jeder Resource muss ein Digest vorhanden sein. Die Git-Source bleibt eine
Herkunftsreferenz; `source-archive` ist ihre transportierte Momentaufnahme.
Die drei Image-Resources sollen im finalen CTF lokale Blob-Zugriffe besitzen,
nicht ausschließlich Verweise auf ihre Upstream-Registry.

## 5. Eine Resource über ihre Identität herunterladen

```bash
mkdir -p "$DELIVERY_DIR/inspect"
ocm download resource \
  "ctf::$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/inspect/values.yaml" \
  --extraction-policy disable
diff -u "$DELIVERY_DIR/values-airgap.yaml" "$DELIVERY_DIR/inspect/values.yaml"
```

OCM sucht nicht nach einem Dateinamen im CTF. Es wählt die Resource mit der
stabilen Identity `name=deployment-values` und folgt deren `access` zum
zugehörigen Blob. `--extraction-policy disable` sorgt dafür, dass genau der
Blob ausgegeben und nicht automatisch weiter entpackt wird.

`diff -u` bleibt bei identischen Dateien ohne Ausgabe und liefert Exit-Code
`0`. Eine leere Konsole ist hier also der Beweis, dass die heruntergeladenen
Values bytegleich mit der ursprünglichen Datei sind.

## Checkpoint

Der Descriptor enthält eine Source, sechs Resources, Labels und Digests. Die
drei Images besitzen OS/Arch-`extraIdentity` und lokale Blob-Zugriffe. Du
solltest außerdem den Unterschied zwischen Constructor, Descriptor und CTF in
einem Satz erklären können.

Weiter mit [OCM 03 – Signieren und transportieren](03-registry-import.md).
