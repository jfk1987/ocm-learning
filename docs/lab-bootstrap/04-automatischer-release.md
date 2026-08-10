# Lab 04 – Automatische OCM-Lieferung aus CI

**Ziel:** Ein Git-Tag erzeugt ohne manuelle Descriptor-Pflege eine vollständig
materialisierte OCM-Komponente und importiert sie in die Zielregistry.

## Welche Dateien gehören in welches Repository?

Lab 04 arbeitet im separaten Forgejo-Repository `target-application`, nicht im
Repository `ocm-learning`:

| Ort | Aufgabe |
| --- | --- |
| `ocm-learning` | Lernmaterial und Quelle für wiederverwendbare Vorlagen |
| `target-application` | freizugebende Anwendung und aktive CI-Konfiguration |
| OCI Registry/CTF | von CI erzeugte, nicht als Git-Quelltext gepflegte Ausgabe |

`skopeo` ist lediglich ein Werkzeug im CI-Toolimage. Seine Erwähnung bedeutet
nicht, dass das Lern-Repository in Forgejo als Zielanwendung eingecheckt werden
soll. Das Toolimage gehört zur internetfähigen Build-Plattform; es wird von der
Pipeline verwendet, aber nicht Bestandteil der OCM-Komponente.

Setze für die folgenden Abschnitte beide Arbeitsverzeichnisse explizit. Der
erste Befehl wird im Wurzelverzeichnis von `ocm-learning` ausgeführt:

```bash
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="${LAB_REPO_ROOT}/.lab/workspaces/target-application"
test -d "$TARGET_APP_WORKDIR/.git"
```

## Release-Vertrag im Repository

Das Forgejo-Repository der Zielanwendung enthält mindestens:

```text
config/application.lock.yaml
delivery/target-application/target-application-chart.tgz
delivery/target-application/values-airgap.yaml
scripts/generate-component-constructor.sh
scripts/build-self-contained-ctf.sh
scripts/import-self-contained-ctf.sh
scripts/deliver-application.sh
.woodpecker/ocm-delivery.yaml
```

Diese Dateien werden nicht durch einen Push des gesamten Lern-Repositories
bereitgestellt. Kopiere nur die wiederverwendbare Release-Automatisierung in
die Arbeitskopie der Zielanwendung:

```bash
mkdir -p \
  "$TARGET_APP_WORKDIR/config" \
  "$TARGET_APP_WORKDIR/delivery/target-application" \
  "$TARGET_APP_WORKDIR/scripts" \
  "$TARGET_APP_WORKDIR/.woodpecker"

cp "$LAB_REPO_ROOT/config/application.lock.yaml" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml"
cp "$LAB_REPO_ROOT/scripts/generate-component-constructor.sh" \
  "$LAB_REPO_ROOT/scripts/build-self-contained-ctf.sh" \
  "$LAB_REPO_ROOT/scripts/import-self-contained-ctf.sh" \
  "$LAB_REPO_ROOT/scripts/deliver-application.sh" \
  "$TARGET_APP_WORKDIR/scripts/"
cp "$LAB_REPO_ROOT/examples/ci/ocm-delivery.yaml" \
  "$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml"
```

Chart, `values-airgap.yaml` und optionale Zusatzressourcen stammen dagegen aus
der konkreten Anwendung und werden direkt unter
`$TARGET_APP_WORKDIR/delivery/target-application` erzeugt beziehungsweise
abgelegt. Anschließend werden Platzhalter im Lockfile und in der Pipeline
ersetzt, geprüft und nur im Anwendungsrepository committed.

`application.lock.yaml` wird im Review aktualisiert. Es enthält alle gelockten
Image-Referenzen und den Chart-Digest. Der CI-Job erstellt daraus den
Constructor, kopiert mit OCM alle Images in ein CTF und transferiert die
Komponentenversion in die Zielregistry.

## CI konfigurieren

1. Baue oder verwende außerhalb des Anwendungsrepositories ein CI-Toolimage
   mit `ocm`, `helm`, `yq`, `skopeo` und
   `bash`. Eine reproduzierbare Vorlage liegt unter
   [`ci/ocm-delivery/Dockerfile`](../../ci/ocm-delivery/Dockerfile). Dieses
   Image darf öffentlich bezogen werden. In das Anwendungsrepository kommt
   nur seine gepinnte Image-Referenz in der Pipeline.
2. Lege in Woodpecker die Secrets `target_ocm_repository`,
   `target_registry_host`, `target_registry_username` und
   `target_registry_password` an. Der Job schreibt daraus eine kurzlebige
   Docker-Credential-Datei, die OCM beim Transfer verwendet.
3. Kopiere [ocm-delivery.yaml](../../examples/ci/ocm-delivery.yaml) nach
   `.woodpecker/ocm-delivery.yaml` im Anwendungsrepository – sofern oben noch
   nicht geschehen – und setze dort die gepinnte Toolimage-Referenz.
4. Erzeuge einen semantischen Git-Tag, dessen Version mit
   `component.version` im Lockfile übereinstimmt.

Der Job ruft genau diesen einen Release-Befehl auf:

```bash
./scripts/deliver-application.sh \
  config/application.lock.yaml "$DELIVERY_DIR" "$OCM_REPOSITORY"
```

Er beendet sich bei Platzhaltern, fehlenden Dateien, fehlenden Image-Digests
oder einer schon existierenden Ausgabekomponente. Dadurch kann ein Release
nicht versehentlich überschrieben werden.

Vor dem Tag wird ausschließlich die Anwendungsarbeitskopie gepusht:

```bash
git -C "$TARGET_APP_WORKDIR" status --short
git -C "$TARGET_APP_WORKDIR" add \
  config delivery scripts .woodpecker/ocm-delivery.yaml
git -C "$TARGET_APP_WORKDIR" commit -m 'OCM-Lieferung konfigurieren'
git -C "$TARGET_APP_WORKDIR" push origin main
```

## Abnahme

Der Woodpecker-Run ist grün. `ocm get component-version` gegen die Zielregistry
zeigt die getaggte Version mit Chart, Values, Zusatzressourcen und allen Images.
