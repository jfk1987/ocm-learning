# OCM 00 – Zielanwendung vorbereiten und Modell verstehen

**Ziel:** Das Forgejo-Repository enthält eine konkrete, lauffähige Anwendung
und du kannst Source, Resource und Component Version auseinanderhalten.

Dieses Kapitel beginnt nach Lab 00 bis 03. Das Vorbereitungslabor darf ins
Internet; nur der spätere Zielcluster wird getrennt.

## Was in diesem Kapitel wirklich passiert

Am Anfang existiert ein separates, noch weitgehend leeres Git-Repository für
die Zielanwendung. Am Ende liegen darin Anwendungscode und alle Eingaben für
einen reproduzierbaren Release:

```text
target-application/
├── app/                          Helm-Chart und Anwendungsvorlagen
├── config/application.lock.yaml Freigabevertrag
├── delivery/target-application/ gepacktes Chart, Values und Inventar
└── scripts/                      Werkzeuge für die folgenden OCM-Schritte
```

Noch wird nichts in Kubernetes installiert und noch keine OCM Component
Version gebaut. Dieser Schritt bereitet ausschließlich die Eingaben vor.

## 1. Die Shell auf das Anwendungsrepository ausrichten

Führe die Befehle vom Wurzelverzeichnis `ocm-learning` aus:

```bash
. config/lab.env
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"
```

### Befehl für Befehl

| Ausdruck | Bedeutung |
| --- | --- |
| `. config/lab.env` | Liest die Lab-Variablen in die **aktuelle** Shell ein. Der Punkt ist die Kurzform von `source`. |
| `"$PWD"` | Der absolute Pfad des aktuellen Verzeichnisses. |
| `export NAME=...` | Setzt eine Variable und gibt sie an später gestartete Skripte weiter. |
| `test -d .../.git` | Prüft, ob das Zielrepository existiert. Erfolg bleibt absichtlich ohne Ausgabe; ein Fehler liefert einen Exit-Code ungleich null. |

Mache die beiden wichtigen Pfade einmal sichtbar:

```bash
printf 'Lernrepository: %s\n' "$LAB_REPO_ROOT"
printf 'Anwendungsrepository: %s\n' "$TARGET_APP_WORKDIR"
git -C "$TARGET_APP_WORKDIR" status --short --branch
```

`ocm-learning` enthält die Anleitung und Generatoren. `target-application`
ist das Produkt, das später als OCM Component Version ausgeliefert wird. Die
beiden Verzeichnisse haben damit bewusst verschiedene Aufgaben.

## 2. Die Anwendung und den Freigabevertrag erzeugen

```bash
./scripts/prepare-target-application.sh "$TARGET_APP_WORKDIR"
```

In Alltagssprache heißt dieser Aufruf: „Nimm die Demo-Anwendung aus diesem
Lernrepository, löse alle veränderlichen externen Eingaben auf und schreibe
einen prüfbaren Release-Stand in das separate Anwendungsrepository.“

Das Skript führt nacheinander diese Zustandsänderungen aus:

1. Es kopiert das Demo-Helm-Chart nach `app/`.
2. Es fragt mit `skopeo` für Nginx, Redis und BusyBox den Digest der passenden
   Hostarchitektur ab. Aus einem beweglichen Tag wie `nginx:1.27.4-alpine`
   wird damit eine feste Referenz `tag@sha256:...`.
3. Es paketiert das Chart als `.tgz` und berechnet auch dafür einen
   SHA-256-Digest.
4. Es schreibt die festgelegten Image-Referenzen in `values-airgap.yaml`.
5. Es rendert das Chart lokal und sammelt jedes tatsächlich verwendete
   Container-Image – einschließlich Init-Container und Helm-Hooks.
6. Es erzeugt `application.lock.yaml` als Freigabevertrag und prüft, dass
   Lockfile, Values und gerendertes Manifest dieselben Images enthalten.
7. Es kopiert die Release-Skripte und die Woodpecker-Pipeline in das
   Anwendungsrepository.

Der Datenfluss sieht damit so aus:

```text
Demo-Chart + externe Image-Tags
              │
              ▼
      Digests auflösen und Chart paketieren
              │
              ├── app/
              ├── target-application-chart.tgz
              ├── values-airgap.yaml
              ├── images.discovered.txt
              └── application.lock.yaml
```

Die Anwendung ist klein, aber nicht trivial: Ein Web-Deployment wartet in
einem Init-Container auf ein Redis-StatefulSet; hinzu kommen ein
Migrations-Hook und ein Helm-Test. Deshalb müssen drei verschiedene
Laufzeitimages vollständig inventarisiert werden.

### Das Ergebnis beobachten

```bash
git -C "$TARGET_APP_WORKDIR" status --short
find "$TARGET_APP_WORKDIR" -maxdepth 2 -type f | sort
yq '.component, .images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
```

`git status --short` zeigt hier absichtlich viele neue Dateien: Das sind die
vom Vorbereitungsskript erzeugten Produkt- und Release-Eingaben. `yq` zeigt
nur ausgewählte YAML-Felder an und verändert die Datei nicht.

## 3. Das Helm-Chart rendern, ohne etwas zu installieren

```bash
helm template target-application "$TARGET_APP_WORKDIR/app" \
  --namespace target-application >/tmp/target-application.yaml
```

`helm template` verarbeitet Chart und Standard-Values zu gewöhnlichen
Kubernetes-YAML-Objekten. Es spricht dabei nicht mit einem Cluster. Die
Umleitung `>` schreibt die sonst sehr lange Ausgabe in eine Datei; deshalb
erscheint bei Erfolg nichts im Terminal.

Prüfe das entstandene Ergebnis ausdrücklich:

```bash
wc -l /tmp/target-application.yaml
grep -nE '^kind:|^[[:space:]]*image:' /tmp/target-application.yaml
```

Du solltest unter anderem Deployment, StatefulSet, Services, Job und drei
unterschiedliche Image-Referenzen erkennen. Damit siehst du die späteren
Kubernetes-Objekte, obwohl noch nichts gestartet wurde.

## 4. Die OCM-Begriffe am eigenen Repository zuordnen

| OCM-Begriff | Konkretes Objekt dieses Labs | Einfache Bedeutung |
| --- | --- | --- |
| Component | `example.org/team/target-application` | Die langfristige Identität des Produkts |
| Component Version | derselbe Name plus `0.1.0` | Ein bestimmter freigegebener Stand |
| Source | Git-Repository und Release-Tag | Woher der Stand stammt |
| Resource | Source-Archiv, Chart, Values und drei OCI Images | Was tatsächlich ausgeliefert wird |
| Resource Identity | z. B. `name=web-image` plus OS/Arch | Wie eine Resource eindeutig ausgewählt wird |
| Provider | `example.org` | Wer die Komponente herausgibt; nicht der Speicherort |
| Component Descriptor | später erzeugtes OCM-Dokument | Inhaltsverzeichnis mit Identitäten, Zugriffen und Digests |
| CTF | transportable OCM-Ablage | Behälter für Descriptor und Resources |

Eine **Source** ist ein Herkunftsnachweis: „Dieser Release wurde aus diesem
Git-Stand gebaut.“ Das zusätzliche `source-archive` ist dagegen eine
transportierte Kopie dieses Stands. Eine **Resource** ist ein auslieferbares
Ergebnis. Der spätere Component Descriptor verbindet Namen, Versionen,
Zugriffe und Digests; ein CTF kann diese Informationen und Inhalte gemeinsam
transportieren.

## 5. Die Liefergrenze verstehen

Teil der Lieferung sind Chart, Values, alle drei Images und optionale
Migrations- oder Konfigurationsartefakte. Nicht enthalten sind Kubernetes,
k3d, Forgejo, Woodpecker, Registry, CNI, StorageClass oder Ingress Controller.
Secrets gehören ebenfalls nicht in das CTF.

OCM beschreibt und transportiert also das Produkt. Es ersetzt weder die
Zielplattform Kubernetes noch das Installationswerkzeug Helm.

## Checkpoint

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml" \
  && echo 'OK: Lockfile vorhanden'
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz" \
  && echo 'OK: Chart paketiert'
test "$(wc -l < "$TARGET_APP_WORKDIR/delivery/target-application/images.discovered.txt" | tr -d ' ')" = 3 \
  && echo 'OK: genau drei Laufzeitimages gefunden'
```

Bevor du weitergehst, solltest du erklären können: Das Lockfile hält den
freizugebenden Stand fest; es ist noch keine OCM Component Version und noch
kein Deployment.

Danach folgt [OCM 01 – Inventar und Identitäten](01-inventar.md).
