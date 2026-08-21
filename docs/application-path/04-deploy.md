# OCM 04 – Zielregistry befüllen und air-gapped deployen

**Ziel:** Ein eigener Zielcluster ohne Default-Route startet die Anwendung nur
aus Resources, die zuvor aus dem CTF in die lokale Registry kopiert wurden.

## Was in diesem Kapitel wirklich passiert

Das geprüfte CTF liegt bisher nur als Transportpaket in der simulierten
Zielzone. Kubernetes kann Images nicht direkt aus einem CTF starten. Deshalb
folgt jetzt eine bewusste Übersetzung zwischen drei Speichern:

```text
entpacktes CTF
   │ OCM importiert Descriptor und Resources
   ▼
lokale OCI Registry auf localhost:5000
   │ Helm liefert Kubernetes lokale Image-Adressen
   ▼
Zielcluster ohne Internet-Egress
```

OCM transportiert und lokalisiert die freigegebenen Artefakte. Helm rendert
die Installation. Kubernetes startet die Workloads. Keine dieser Aufgaben
wird von einem der anderen Werkzeuge heimlich ersetzt.

## 1. Einen getrennten Zielcluster aufbauen

Der Zielcluster darf während seines k3d/K3s-Bootstraps noch Images laden.
Danach entfernt das Skript die Default-Route seiner Workload-Nodes. Das direkt
verbundene Docker-Netz zur Lab-Registry bleibt erreichbar.

```bash
. config/lab.env
./scripts/create-airgap-target.sh ocm-target
./scripts/set-target-egress.sh status ocm-target
```

Der erste Aufruf erzeugt einen eigenen k3d-Cluster mit Registry-Mirror. Er ist
nicht der Lab-Cluster, in dem Forgejo und Woodpecker laufen. Der zweite Aufruf
schaut in die Node-Container und zeigt deren Routingzustand.

Erwartet wird sinngemäß:

```text
k3d-ocm-target-server-0: blocked (no default route)
```

„Keine Default-Route“ bedeutet: Ziele im Internet sind nicht erreichbar.
Direkt verbundene Docker-Netze besitzen weiterhin spezifische Routen. Darum
kann der Node die lokale Registry erreichen, obwohl ein Upstream-Pull später
scheitern muss.

Mache die Trennung sichtbar:

```bash
kubectl --context k3d-ocm-target get nodes -o wide
docker exec k3d-ocm-target-server-0 ip route
```

In der Routentabelle darf keine Zeile mit `default` beginnen.

## 2. Das geprüfte CTF in die Zielregistry importieren

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export OCM_REPOSITORY='http://localhost:5000/ocm'
```

`OCM_REPOSITORY` wird hier vom OCM-Prozess auf deinem Host verwendet. Deshalb
ist `localhost:5000` korrekt. Anders als eine OCI-Image-Referenz darf diese
OCM-Repository-Angabe das Protokoll `http://` enthalten.

Jetzt erfolgt der eigentliche Import:

```bash
"$TARGET_APP_WORKDIR/scripts/import-self-contained-ctf.sh" \
  "$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" "$OCM_REPOSITORY"
```

Das Skript führt im Kern diesen Transfer aus:

```text
ctf::.../transport-archive-0.1.0//example.org/team/target-application:0.1.0
                                  │
                                  │ --copy-resources --upload-as ociArtifact
                                  ▼
oci::http://localhost:5000/ocm//example.org/team/target-application:0.1.0
```

Dabei werden nicht nur Metadaten übertragen. Chart, Values, Source-Archiv und
Image-Inhalte werden aus den lokalen CTF-Blobs in die OCI Registry geschrieben.
Der Ziel-Descriptor erhält Zugriffe, die auf diese neuen Registry-Inhalte
zeigen. Manuell gleich benannte Image-Tags zu pushen wäre nicht gleichwertig:
Die Component Version, Resource-Identitäten, Zugriffe und Digests müssen als
zusammenhängendes Modell ankommen.

## 3. Den importierten Descriptor lesen und erneut verifizieren

```bash
ocm get component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/imported-component.yaml"

OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig" \
  ocm verify component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`ctf::` wurde zu `oci::`: Dieselbe Component Version wird jetzt aus der
Registry statt aus dem Transportarchiv gelesen. Die erste Zeile speichert
ihren Ziel-Descriptor für die nächsten Schritte. Die zweite verwendet nur für
diesen einen Prozess die Verifier-Konfiguration links vor dem Befehl; deine
globale Shell-Variable muss dafür nicht geändert werden.

Untersuche die neuen Image-Zugriffe:

```bash
yq '.[0].component.resources[] |
  select(.type == "ociImage") |
  {name, extraIdentity, access}' "$DELIVERY_DIR/imported-component.yaml"
```

Die fachlichen Resource-Namen und Digests bleiben erhalten, aber die
`imageReference` zeigt jetzt auf die Zielregistry.

## 4. Chart und Values anhand ihrer Resource Identity herunterladen

```bash
mkdir -p "$DELIVERY_DIR/deploy-$COMPONENT_VERSION"
ocm download resource \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=helm-chart \
  --output "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --extraction-policy disable
ocm download resource \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  --extraction-policy disable
```

Beide Aufrufe beginnen bei der Component Version und wählen dann eine Resource
über `--identity name=...`. Der physische Speicherort in der Registry muss dem
Benutzer nicht bekannt sein; er wird aus dem Descriptor aufgelöst.

`values-base.yaml` ist absichtlich noch die unveränderte, signierte
Release-Eingabe. Sie enthält die freigegebenen Upstream-Referenzen. Eine neue
Datei übersetzt diese Referenzen gleich auf die tatsächlichen Zielzugriffe.

## 5. Die Helm Values auf die Zielregistry lokalisieren

```bash
"$TARGET_APP_WORKDIR/scripts/localize-values.sh" \
  "$DELIVERY_DIR/imported-component.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
yq '.images' "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
```

Das Skript liest für `web-image`, `redis-image` und `toolbox-image` die
`access.imageReference` aus dem importierten Descriptor. Danach kopiert es die
Basis-Values und ersetzt nur die drei Image-Referenzen in der Kopie.

Damit bleiben zwei Dinge getrennt nachvollziehbar:

```text
values-base.yaml   = freigegebene, transportierte Eingabe
values-local.yaml  = für diese konkrete Zielregistry lokalisierte Installation
```

Zeige die Änderung:

```bash
diff -u "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" || true
```

Hier ist eine `diff`-Ausgabe erwartet. Geändert werden sollen nur die
Image-Adressen, nicht Anwendungsparameter oder Versionen.

## 6. Das Deployment vorprüfen

```bash
kubectl config use-context k3d-ocm-target
kubectl create namespace target-application \
  --dry-run=client -o yaml | kubectl apply -f -
```

Der erste Befehl macht den Zielcluster zum Standardkontext für folgende
`kubectl`- und Helm-Aufrufe. Der zweite ist eine Pipe:

1. `kubectl create ... --dry-run=client -o yaml` erzeugt nur YAML auf stdout.
2. `|` reicht dieses YAML an den nächsten Prozess weiter.
3. `kubectl apply -f -` liest von stdin und legt den Namespace an oder lässt
   ihn unverändert bestehen.

Nun wird das Chart geprüft, aber noch nicht installiert:

```bash
"$TARGET_APP_WORKDIR/scripts/render-local-chart.sh" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  localhost:5000
```

Das Skript führt drei Kontrollen aus:

1. `helm template` rendert das vollständige Kubernetes-Manifest.
2. `assert-local-images.sh` lehnt jedes `image:` außerhalb von
   `localhost:5000` ab.
3. `kubectl apply --dry-run=server` lässt den API-Server das Manifest prüfen,
   ohne die Workloads anzulegen.

Die Erfolgsmeldung `Validated manifest: ...` bedeutet daher: syntaktisch
renderbar, nur lokale Images und vom Kubernetes-API-Server akzeptiert.

## 7. Die Anwendung tatsächlich installieren

```bash
helm upgrade --install target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
helm test target-application -n target-application --logs
```

Erst `helm upgrade --install` verändert die Anwendungsobjekte im Cluster.
`--install` erzeugt den Release beim ersten Lauf; bei einem späteren Lauf
aktualisiert `upgrade` denselben Release. `--wait` wartet auf bereite
Workloads, `--wait-for-jobs` zusätzlich auf den Migrations-Job.

`helm test` startet den im Chart definierten Test-Pod und gibt dessen Logs
aus. Ein erfolgreicher Test zeigt nicht nur, dass Objekte existieren, sondern
dass der Webdienst im Cluster antwortet.

## Checkpoint

```bash
kubectl -n target-application get pod,deploy,statefulset,service,job
helm -n target-application status target-application
./scripts/set-target-egress.sh status ocm-target
```

Web und Redis sind bereit, Migration und Helm-Test waren erfolgreich, und der
Node besitzt weiterhin keine Default-Route. Damit ist die Installation
gelungen; der strenge Air-Gap-Beweis folgt im nächsten Kapitel.

Weiter mit [OCM 05 – Air-Gap-Nachweis](05-nachweis.md).
