# Lab 04 – Automatische OCM-Lieferung aus CI

**Ziel:** Du baust ein eigenes CI-Toolimage, legst eine Woodpecker-Pipeline im
Forgejo-Repository `target-application` an und löst sie mit einem Git-Tag aus.
Die Pipeline erzeugt aus dem Lockfile eine vollständige OCM Component Version
und überträgt sie in die lokale OCI Registry.

Dieses Kapitel setzt keine Woodpecker-, Skopeo- oder OCM-Erfahrung voraus. Die
Abschnitte sind bewusst kurz und einzeln prüfbar.

## 0. Was in diesem Lab zusammenspielt

| Werkzeug | Aufgabe in diesem Schritt |
| --- | --- |
| Forgejo | speichert das Repository und sendet beim Push eines Tags einen Webhook |
| Woodpecker | klont genau diesen Git-Stand und startet die definierten Schritte |
| CI-Toolimage | stellt `ocm`, `helm`, `yq`, `skopeo` und `bash` bereit |
| Skopeo | prüft den Zugriff auf OCI Registries, ohne einen Docker-Daemon zu benötigen |
| OCM | erzeugt das CTF, kopiert alle Resources und veröffentlicht die Component Version |
| lokale Registry | speichert Toolimages, Component Descriptors und lokalisierte Resources |

Das CI-Toolimage gehört zur Build-Plattform. Es ist **nicht** Teil der
air-gapped Zielanwendung. In die OCM-Komponente kommen nur Chart, Values,
Zusatzdateien und Laufzeitimages der Zielanwendung.

## 1. Voraussetzungen kontrollieren

Lab 01 bis 03 müssen abgeschlossen sein. Außerdem müssen die Schritte 00 bis
02 aus „Teil B – Zielanwendung mit OCM“ für die ausgewählte Anwendung erledigt
sein. Insbesondere darf das Lockfile keine Platzhalter mehr enthalten.

Führe die folgenden Befehle im Wurzelverzeichnis von `ocm-learning` aus:

```bash
export LAB_REPO_ROOT="$PWD"
export TARGET_APP_WORKDIR="${LAB_REPO_ROOT}/.lab/workspaces/target-application"

test -d "$TARGET_APP_WORKDIR/.git"
kubectl get nodes
curl --fail --show-error http://localhost:5000/v2/
curl --fail --show-error http://woodpecker.ocm.test:8080/healthz
git -C "$TARGET_APP_WORKDIR" remote -v
```

Der Git-Remote muss auf
`ocm-admin/target-application.git` in Forgejo zeigen. Er darf nicht auf das
Lern-Repository zeigen.

Prüfe jetzt die Release-Eingaben:

```bash
test -f "$TARGET_APP_WORKDIR/config/application.lock.yaml"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/target-application-chart.tgz"
test -f "$TARGET_APP_WORKDIR/delivery/target-application/values-airgap.yaml"

if grep -n -E 'TBD|REPLACE_WITH_' \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" \
  "$TARGET_APP_WORKDIR/delivery/target-application/values-airgap.yaml"; then
  echo 'Es sind noch Platzhalter vorhanden.' >&2
  false
fi
```

`grep` ohne Treffer liefert Exitcode 1; durch den `if`-Block ist das hier der
gewünschte Erfolgsfall. Bei einem Treffer wird bewusst abgebrochen.

## 2. Die zwei Git-Repositories auseinanderhalten

Lab 04 verwendet zwei Verzeichnisse mit verschiedenen Aufgaben:

| Verzeichnis | Darin wird geändert | Darin wird committed |
| --- | --- | --- |
| `$LAB_REPO_ROOT` | nein; liefert Vorlagen und die Dockerfile | nein |
| `$TARGET_APP_WORKDIR` | ja; enthält Anwendung und aktive Pipeline | ja |

Die Release-Skripte werden einmalig aus dem Lern-Repository in das
Anwendungsrepository kopiert:

```bash
mkdir -p \
  "$TARGET_APP_WORKDIR/config" \
  "$TARGET_APP_WORKDIR/delivery/target-application" \
  "$TARGET_APP_WORKDIR/scripts" \
  "$TARGET_APP_WORKDIR/.woodpecker"

cp "$LAB_REPO_ROOT/scripts/generate-component-constructor.sh" \
  "$LAB_REPO_ROOT/scripts/build-self-contained-ctf.sh" \
  "$LAB_REPO_ROOT/scripts/import-self-contained-ctf.sh" \
  "$LAB_REPO_ROOT/scripts/deliver-application.sh" \
  "$TARGET_APP_WORKDIR/scripts/"

cp "$LAB_REPO_ROOT/examples/ci/ocm-delivery.yaml" \
  "$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml"
```

**Zwischenergebnis:** `git -C "$TARGET_APP_WORKDIR" status --short` zeigt nur
Dateien der Zielanwendung. Der Status von `ocm-learning` ist dafür irrelevant.

## 3. Das CI-Toolimage bauen

Woodpecker führt jeden Schritt in einem Container aus. Unser Container braucht
mehr Werkzeuge als ein normales Alpine-Image. Die Dockerfile unter
`ci/ocm-delivery` installiert deshalb:

- `ocm` für Component Versions und CTFs,
- `helm` zum Prüfen des Charts,
- `yq` zum Lesen des YAML-Lockfiles,
- `skopeo` zum Prüfen und Kopieren von OCI-Artefakten sowie
- `bash` für die Release-Skripte.

Baue das Image auf dem Host. Der Punkt am Ende des Befehls ist der Build-
Kontext und darf nicht fehlen:

```bash
export CI_TOOL_IMAGE='localhost:5000/lab/ocm-delivery:0.1.0'

docker build \
  --tag "$CI_TOOL_IMAGE" \
  --file "$LAB_REPO_ROOT/ci/ocm-delivery/Dockerfile" \
  "$LAB_REPO_ROOT"
```

Die Dockerfile nutzt automatisch die Architektur des Hosts (`amd64` oder
`arm64`). Das passt für dieses Lab, weil Docker und k3d auf demselben Rechner
laufen.

Prüfe das Image, bevor du es veröffentlichst:

```bash
docker run --rm "$CI_TOOL_IMAGE" -lc '
  set -e
  ocm version
  helm version --short
  yq --version
  skopeo --version
'
```

Jeder Befehl muss eine Version ausgeben. `command not found` bedeutet, dass
das Image nicht erfolgreich gebaut wurde.

## 4. Das Toolimage in die Lab-Registry pushen

Der Woodpecker-Agent läuft im Cluster und kann das nur lokal auf dem Host
vorhandene Docker-Image nicht sehen. Deshalb wird es in die Registry gepusht:

```bash
docker push "$CI_TOOL_IMAGE"

curl --fail --show-error \
  http://localhost:5000/v2/lab/ocm-delivery/tags/list
```

Die Antwort muss den Tag `0.1.0` enthalten. Die Registry ist im Lab bewusst
ohne TLS und ohne Anmeldung konfiguriert; hier werden daher weder `docker
login` noch Registry-Secrets benötigt.

Teste anschließend, ob Kubernetes das Image über den in Lab 01 eingerichteten
k3d-Mirror ziehen kann:

```bash
kubectl -n woodpecker run ocm-toolimage-test \
  --image="$CI_TOOL_IMAGE" \
  --restart=Never \
  --command -- /bin/bash -lc 'ocm version && skopeo --version'

kubectl -n woodpecker wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/ocm-toolimage-test --timeout=180s
kubectl -n woodpecker logs ocm-toolimage-test
kubectl -n woodpecker delete pod ocm-toolimage-test
```

**Zwischenergebnis:** Der Test-Pod endet mit `Succeeded`. Bei
`ImagePullBackOff` ist nicht Woodpecker, sondern der Registry-Mirror aus Lab 01
zu reparieren.

## 5. Registry-Adressen verstehen und aus dem Pod testen

Im Lab gibt es für dieselbe Registry drei Schreibweisen:

| Ort der Verwendung | Adresse | Warum |
| --- | --- | --- |
| Host-Befehle wie `docker push` und `curl` | `localhost:5000` | Port 5000 ist zum Host veröffentlicht |
| Kubernetes Feld `image:` | `localhost:5000/...` | k3s übersetzt dies über seinen Registry-Mirror |
| Prozess in einem Pipeline-Pod | `k3d-registry.localhost:5000` | `localhost` wäre hier der Pipeline-Pod selbst |

Prüfe die dritte Variante mit Skopeo. `--tls-verify=false` ist nur für die
unverschlüsselte Lab-Registry nötig:

```bash
kubectl -n woodpecker run registry-aus-pod \
  --image="$CI_TOOL_IMAGE" \
  --restart=Never \
  --command -- /bin/bash -lc \
  'skopeo list-tags --tls-verify=false \
    docker://k3d-registry.localhost:5000/lab/ocm-delivery'

kubectl -n woodpecker wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/registry-aus-pod --timeout=180s
kubectl -n woodpecker logs registry-aus-pod
kubectl -n woodpecker delete pod registry-aus-pod
```

Die Ausgabe muss wieder `0.1.0` enthalten. Dieser Test verhindert die häufigen
Fehler `connection refused` gegen `localhost` und `server gave HTTP response to
HTTPS client`.

## 6. Die Woodpecker-Datei lesen

Öffne jetzt
`$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml`. Die Datei besteht aus drei
Ebenen:

```yaml
when:
  - event: tag

steps:
  - name: release-eingaben-pruefen
    image: localhost:5000/lab/ocm-delivery:0.1.0
    pull: true
    commands:
      - ocm version

  - name: ocm-komponente-liefern
    image: localhost:5000/lab/ocm-delivery:0.1.0
    pull: true
    environment:
      DELIVERY_DIR: delivery/target-application
      OCM_REPOSITORY: http://k3d-registry.localhost:5000/ocm
    commands:
      - ./scripts/deliver-application.sh ...
```

- `when` aktiviert den gesamten Workflow nur für einen gepushten Git-Tag.
- `steps` ist die geordnete Liste der Container-Schritte.
- `image` bestimmt die Werkzeugumgebung des jeweiligen Schritts.
- `pull: true` lässt Woodpecker den Tag vor dem Schritt aus der Registry holen.
- `commands` werden im automatisch geklonten Repository ausgeführt.
- `environment` setzt normale Umgebungsvariablen im Schritt.

Der erste Schritt prüft Werkzeuge, Eingabedateien, Registry-Zugriff und dass
`CI_COMMIT_TAG` exakt der `component.version` im Lockfile entspricht. Der
zweite Schritt führt erst danach die eigentliche OCM-Lieferung aus.

`OCM_REPOSITORY` beginnt mit `http://`, weil OCM bei einer Registry ohne
Schema HTTPS annimmt. Eine produktive Registry verwendet TLS und würde zum
Beispiel `registry.example.org/ocm` heißen.

Kontrolliere, dass die Image-Referenz der gerade gepushten entspricht:

```bash
grep -n 'image: localhost:5000/lab/ocm-delivery:0.1.0' \
  "$TARGET_APP_WORKDIR/.woodpecker/ocm-delivery.yaml"
```

Es werden zwei Treffer erwartet, einer pro Schritt.

## 7. Warum dieses Lab keine Woodpecker-Secrets braucht

Die Registry aus Lab 01 besitzt keine Authentisierung. Deshalb wären Benutzer,
Passwort und `skopeo login` nicht nur unnötig, sondern irreführend. Auch die
Repository-Adresse ist nicht geheim und steht lesbar in der Pipeline.

Bei einer echten Registry mit Login werden Zugangsdaten **nicht** in Git
committed. Dann öffnest du in Woodpecker:

1. `ocm-admin/target-application`;
2. **Settings**;
3. **Secrets**;
4. **Add secret**;
5. Name zum Beispiel `target_registry_password`, Wert das Registry-Passwort;
6. Secret mindestens für das Ereignis `tag` freigeben und speichern.

In der Pipeline wird es anschließend unter einem frei gewählten
Umgebungsvariablennamen eingebunden:

```yaml
environment:
  REGISTRY_PASSWORD:
    from_secret: target_registry_password
```

Das ist nur das Muster für eine spätere TLS-/Auth-Registry. Füge dieses Secret
im jetzigen HTTP-Lab nicht hinzu.

## 8. Release-Stand prüfen und committen

Lies die Component Version aus dem Lockfile und kontrolliere den Arbeitsbaum:

```bash
export COMPONENT_VERSION="$(
  yq -r '.component.version' \
    "$TARGET_APP_WORKDIR/config/application.lock.yaml"
)"

test -n "$COMPONENT_VERSION"
test "$COMPONENT_VERSION" != 'null'
printf 'Release-Version: %s\n' "$COMPONENT_VERSION"
git -C "$TARGET_APP_WORKDIR" status --short
```

Für dieses Lab wird ein Tag ohne vorangestelltes `v` verwendet, zum Beispiel
`0.1.0`. Committe ausschließlich im Anwendungsrepository:

```bash
git -C "$TARGET_APP_WORKDIR" add \
  config \
  delivery \
  scripts \
  .woodpecker/ocm-delivery.yaml

git -C "$TARGET_APP_WORKDIR" diff --cached --stat
git -C "$TARGET_APP_WORKDIR" commit -m 'Automatische OCM-Lieferung konfigurieren'
git -C "$TARGET_APP_WORKDIR" push origin main
```

Der Push auf `main` startet eventuell weiterhin `smoke.yaml`. Die neue
`ocm-delivery.yaml` wird dabei wegen `event: tag` übersprungen. Das ist
beabsichtigt und erlaubt, die Konfiguration vor dem Release in Forgejo zu
prüfen.

## 9. Den Release mit einem Git-Tag auslösen

Ein Git-Tag ist ein Name für einen festen Commit. Ein lokaler Tag allein löst
noch keine CI aus; erst `git push origin <tag>` sendet das Ereignis an Forgejo.

Prüfe vor dem Tag noch einmal Version und vorhandene Tags:

```bash
git -C "$TARGET_APP_WORKDIR" status --short
git -C "$TARGET_APP_WORKDIR" tag --list
test -z "$(git -C "$TARGET_APP_WORKDIR" status --porcelain)"
```

Der Arbeitsbaum muss leer sein und der Release-Tag darf noch nicht existieren.
Erzeuge und pushe ihn dann:

```bash
git -C "$TARGET_APP_WORKDIR" tag -a "$COMPONENT_VERSION" \
  -m "Release $COMPONENT_VERSION"
git -C "$TARGET_APP_WORKDIR" push origin "$COMPONENT_VERSION"
```

Öffne `http://woodpecker.ocm.test:8080`, wähle
`ocm-admin/target-application` und dann **Pipelines**. Es muss ein Lauf mit dem
Ereignis `tag` erscheinen. Öffne den Lauf und danach einen Schrittnamen, um die
Live-Ausgabe zu sehen.

Parallel kannst du die kurzlebigen Kubernetes-Ressourcen beobachten:

```bash
kubectl -n woodpecker get pods,pvc --watch
```

Der erste Lauf kann länger dauern: OCM lädt jedes im Lockfile referenzierte
Image und schreibt seine Layers in das selbstständige CTF.

## 10. Das Ergebnis unabhängig prüfen

Beide Woodpecker-Schritte müssen grün sein. Hole danach Name und Version aus
dem Lockfile:

```bash
export COMPONENT_NAME="$(
  yq -r '.component.name' \
    "$TARGET_APP_WORKDIR/config/application.lock.yaml"
)"

ocm get component-version \
  "oci::http://localhost:5000/ocm//${COMPONENT_NAME}:${COMPONENT_VERSION}"
```

Die Ausgabe muss Chart, Values, Zusatzresources und jedes gelockte Image
enthalten. Der Registry-Katalog liefert eine zusätzliche, aber weniger
aussagekräftige Kontrolle:

```bash
curl --fail --show-error http://localhost:5000/v2/_catalog
```

`_catalog` zeigt nur Repository-Namen. Die OCM-Abfrage ist der eigentliche
Nachweis, dass die Component Version lesbar ist.

## Fehleranalyse

### Nach dem Tag erscheint kein Pipeline-Lauf

- Prüfe in Forgejo unter **Repository Settings -> Webhooks** den letzten
  Zustellversuch.
- Prüfe, dass das Repository in Woodpecker aktiviert ist.
- Prüfe mit `git -C "$TARGET_APP_WORKDIR" ls-remote --tags origin`, ob der Tag
  wirklich gepusht wurde.
- Prüfe Einrückung und Dateiendung von `.woodpecker/ocm-delivery.yaml`.

### `ImagePullBackOff` beim Toolimage

```bash
kubectl -n woodpecker describe pod <PODNAME>
curl --fail --show-error \
  http://localhost:5000/v2/lab/ocm-delivery/tags/list
```

Wiederhole anschließend den Kubernetes-Test aus Abschnitt 4. Die
Pipeline-Datei muss exakt denselben Image-Tag verwenden, den du gepusht hast.

### `connection refused` auf `localhost:5000`

Ein Pipeline-Prozess verwendet die falsche Perspektive. In `image:` bleibt
`localhost:5000/...`; in `OCM_REPOSITORY` und Skopeo-Befehlen innerhalb des
Pods muss `k3d-registry.localhost:5000` stehen.

### HTTPS-Fehler gegen die HTTP-Registry

- Skopeo benötigt im Lab `--tls-verify=false`.
- OCM benötigt in der Repository-Adresse das Präfix `http://`.
- Für eine echte TLS-Registry werden diese Ausnahmen entfernt.

### Tag und Lockfile-Version unterscheiden sich

Der erste Pipeline-Schritt bricht absichtlich ab. Ändere nicht nachträglich den
bereits gepushten Release-Tag. Korrigiere das Lockfile, committe die Änderung
und erzeuge eine neue Component Version mit einem neuen Tag.

### `Ziel existiert bereits`

Die Release-Skripte überschreiben keine Component-Ausgabe. In einem normalen
Woodpecker-Lauf ist der Checkout frisch. Tritt der Fehler trotzdem auf, wurden
`component-constructor.yaml`, `transport-archive` oder
`transport-archive.descriptor-source` versehentlich ins Git-Repository
committed. Entferne diese generierten Dateien aus Git und ergänze sie in
`.gitignore`.

## Abnahme

- Das Toolimage liegt als `localhost:5000/lab/ocm-delivery:0.1.0` in der
  lokalen Registry und lässt sich als Kubernetes-Pod starten.
- Nur `target-application` enthält die aktive Release-Pipeline.
- Ein gepushter Git-Tag löst genau den OCM-Workflow aus.
- Tag und `component.version` sind identisch.
- `ocm get component-version` zeigt die veröffentlichte Version mit allen
  Resources.

Damit ist die manuelle OCM-Lieferung aus Teil B als reproduzierbarer
CI-Release automatisiert.
