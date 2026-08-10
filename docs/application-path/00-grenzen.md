# OCM 00 – Zielanwendung vorbereiten und Modell verstehen

**Ziel:** Das Forgejo-Repository enthält eine konkrete, lauffähige Anwendung
und du kannst Source, Resource und Component Version auseinanderhalten.

Dieser Teil beginnt nach Lab 00 bis 03. Das Vorbereitungslabor darf ins
Internet; nur der spätere Zielcluster wird getrennt.

## 1. Die Anwendung erzeugen

Vom Wurzelverzeichnis `ocm-learning` aus:

```bash
. config/lab.env
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"

./scripts/prepare-target-application.sh "$TARGET_APP_WORKDIR"
```

Das Skript erledigt bewusst die fehleranfällige Erstpräparation:

- kopiert das eingecheckte Demo-Chart nach `app/`;
- löst für die Hostarchitektur die Digests von Nginx, Redis und BusyBox auf;
- paketiert das Chart und erstellt digest-gepinnte Values;
- rendert alle Kubernetes-Objekte und inventarisiert Container, Init-Container
  sowie Helm-Hooks;
- erzeugt und validiert `config/application.lock.yaml`;
- kopiert Release-Skripte und die spätere Woodpecker-Pipeline.

Die Anwendung ist klein, aber nicht trivial: ein Web-Deployment wartet in
einem Init-Container auf ein Redis-StatefulSet; hinzu kommen ein Migrations-Hook
und ein Helm-Test. Dadurch werden drei verschiedene Laufzeitimages benötigt.

```bash
git -C "$TARGET_APP_WORKDIR" status --short
helm template target-application "$TARGET_APP_WORKDIR/app" \
  --namespace target-application >/tmp/target-application.yaml
```

## 2. Die OCM-Begriffe am eigenen Repository zuordnen

| OCM-Begriff | Konkretes Objekt dieses Labs |
| --- | --- |
| Component | `example.org/team/target-application` |
| Component Version | derselbe Name plus `0.1.0` |
| Source | Git-Herkunft mit Repository und Release-Tag |
| Resource | Source-Archiv, Chart, Values und drei OCI Images |
| Resource Identity | z. B. `name=web-image`, plus OS/Arch als `extraIdentity` |
| Provider | `example.org`; beschreibt den Herausgeber, nicht die Registry |
| CTF | transportable Ablage einer oder mehrerer Component Versions |

Eine **Source** beschreibt per Git-Zugriff, woraus die Komponente gebaut wurde.
Die tatsächliche Quellkopie reist zusätzlich als `source-archive` Resource,
weil `--copy-resources` bewusst Resources materialisiert. Eine **Resource** ist
ein auslieferbares Ergebnis. Ein Component Descriptor hält
Identitäten, Zugriffe und Digests zusammen; das CTF ist sein Transportbehälter.

## 3. Liefergrenze festhalten

Teil der Lieferung sind Chart, Values, alle drei Images und optionale
Migrations-/Konfigurationsartefakte. Nicht enthalten sind Kubernetes, k3d,
Forgejo, Woodpecker, Registry, CNI, StorageClass oder Ingress Controller.
Secrets gehören ebenfalls nicht in das CTF.

Diese Grenze verhindert zwei typische Missverständnisse: Das Lab selbst muss
nicht air-gapped sein, und OCM ersetzt weder Kubernetes noch Helm.

## Abnahme

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz"
test "$(wc -l < "$TARGET_APP_WORKDIR/delivery/target-application/images.discovered.txt" | tr -d ' ')" = 3
```

Danach folgt [OCM 01 – Inventar und Identitäten](01-inventar.md).
