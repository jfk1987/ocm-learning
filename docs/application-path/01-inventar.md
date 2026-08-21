# OCM 01 – Inventar, Digests und stabile Identitäten

**Ziel:** Du verstehst das generierte Lockfile und kannst beweisen, dass
gerendertes Deployment, Values und OCM-Eingaben dieselben Images meinen.

## Was in diesem Kapitel wirklich passiert

OCM 00 hat dieselben drei Images an mehreren Stellen festgehalten. Das ist
kein unnötiges Duplikat: Jede Datei zeigt eine andere Sicht auf den Release.

```text
gerendertes Kubernetes-Manifest ── was später tatsächlich gestartet würde
Helm Values                     ── was Helm als Konfiguration erhält
application.lock.yaml           ── was für den OCM-Release freigegeben ist
```

In diesem Kapitel vergleichst du diese drei Sichtweisen und lässt einen
Validator verhindern, dass sie unbemerkt auseinanderlaufen.

## 1. Die drei Inventarsichten nebeneinander lesen

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

cat "$DELIVERY_DIR/images.discovered.txt"
yq '.images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
yq '.images' "$DELIVERY_DIR/values-airgap.yaml"
```

### Was die Befehle zeigen

| Befehl | Sicht auf den Release |
| --- | --- |
| `cat images.discovered.txt` | Die Image-Referenzen, die durch `helm template` wirklich im Manifest gelandet sind |
| `yq '.images' application.lock.yaml` | Die Images mit OCM-Resource-Namen, Version, Plattform und freigegebenem Digest |
| `yq '.images' values-airgap.yaml` | Die Image-Referenzen, die Helm beim Rendern einsetzt |

Suche beispielsweise `web-image` im Lockfile. Seine `imageReference` muss
inhaltlich dieselbe Nginx-Referenz sein, die in den Values und im gerenderten
Inventar auftaucht. Die Feldnamen unterscheiden sich, der referenzierte
Content nicht.

### Tag und Digest auseinanderhalten

Eine Referenz sieht ungefähr so aus:

```text
public.ecr.aws/docker/library/nginx:1.27.4-alpine@sha256:abc123...
└──────────────── Repository ────────────────┘ └── Tag ──┘ └── Digest ──┘
```

Der Tag ist ein verständlicher, aber grundsätzlich veränderlicher Name. Der
Digest ist der Fingerabdruck des konkreten Manifests. Die Kombination ist
lesbar und inhaltlich festgelegt. `latest` wäre weder eine Version noch ein
reproduzierbarer Freigabestand und ist deshalb verboten.

## 2. Verstehen, warum die Plattform Teil der Identität ist

Ein Registry-Digest kann auf einen Multi-Arch-Index oder auf ein einzelnes
Manifest zeigen. Das Vorbereitungsskript fragt mit `skopeo` ausdrücklich
`linux/amd64` beziehungsweise `linux/arm64` ab. Dieselben Merkmale erscheinen
später an der OCM Resource:

```yaml
name: web-image
extraIdentity:
  os: linux
  architecture: arm64
```

Der Name `web-image` allein beantwortet nur „welche Rolle?“. Die
`extraIdentity` beantwortet zusätzlich „für welche Plattform?“. So können
beispielsweise diese beiden Resources nebeneinander existieren:

```text
name=web-image, os=linux, architecture=amd64
name=web-image, os=linux, architecture=arm64
```

Sie haben denselben fachlichen Namen, aber nicht dieselbe Resource Identity.

## 3. Den Freigabevertrag validieren

```bash
"$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR"
```

Das Skript erhält zwei Eingaben: zuerst das Lockfile, danach das Verzeichnis
mit den zugehörigen Dateien. Es liest und vergleicht, verändert aber nichts.
Bei Erfolg endet es mit:

```text
Application lockfile is valid: .../config/application.lock.yaml
```

Intern prüft es unter anderem:

- SemVer, Provider und stabile Resource-Namen;
- ob Chart, Values und zusätzliche Resources wirklich existieren;
- ob der berechnete SHA-256-Digest des Chart-Pakets dem Lockfile entspricht;
- `tag@sha256` und OS/Arch für jedes Image;
- keine doppelten Resource-Identitäten oder Platzhalter;
- dieselbe Image-Menge in Lockfile, Values und gerendertem Inventar.

Ein Exit-Code `0` bedeutet „alle Bedingungen erfüllt“. Jeder andere Exit-Code
stoppt den Release und nennt die verletzte Bedingung.

## 4. Den Schutz absichtlich auslösen

Der folgende Negativtest arbeitet mit einer Kopie unter `/tmp`; dein echtes
Lockfile bleibt unverändert:

```bash
cp "$TARGET_APP_WORKDIR/config/application.lock.yaml" /tmp/application.invalid.yaml
yq -i '.images[0].version = "latest"' /tmp/application.invalid.yaml
if "$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  /tmp/application.invalid.yaml "$DELIVERY_DIR"; then
  echo 'FEHLER: Ungültiges Lockfile wurde akzeptiert.' >&2
  false
else
  echo 'Erwarteter Fehler wurde erkannt.'
fi
```

### Die Shell-Logik dahinter

1. `cp` erzeugt eine ungefährliche Arbeitskopie.
2. `yq -i` ändert in dieser Kopie die erste Image-Version zu `latest`.
   `-i` bedeutet „in place“, also Datei überschreiben.
3. `if VALIDATOR; then` verzweigt nach dem Exit-Code des Validators.
4. Akzeptiert der Validator die falsche Version, läuft der `then`-Zweig und
   markiert das als Fehler.
5. Lehnt der Validator sie erwartungsgemäß ab, läuft der `else`-Zweig und der
   Test ist erfolgreich.

Die rote Fehlermeldung des Validators ist hier also erwünscht. Du beweist
nicht nur den Erfolgsfall, sondern auch, dass eine falsche Eingabe gestoppt
wird.

## 5. Warum als Nächstes ein Constructor generiert wird

`application.lock.yaml` ist der von Menschen geprüfte Freigabevertrag. Die
OCM CLI erwartet zum Bauen eine andere Struktur, den Component Constructor.
Dieser wird aus dem Lockfile abgeleitet:

```text
application.lock.yaml   --Generator-->   component-constructor-0.1.0.yaml
von Menschen geprüft                     von der OCM CLI verarbeitet
```

Würden beide Dateien manuell gepflegt, könnten Digests, Namen oder Versionen
auseinanderlaufen. Deshalb ist das Lockfile die Quelle und der Constructor ein
wegwerfbares Build-Ergebnis.

## Checkpoint

Du solltest jetzt drei Aussagen begründen können:

1. Ein Tag benennt einen Stand; ein Digest bindet den konkreten Inhalt.
2. Lockfile, Values und gerendertes Manifest müssen dieselben Images enthalten.
3. Ein erwarteter Validator-Fehler im Negativtest ist ein erfolgreicher Test.

Weiter mit [OCM 02 – Constructor und CTF](02-komponente.md).
