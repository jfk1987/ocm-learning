# OCM 04 – Zielregistry befüllen und air-gapped deployen

**Ziel:** Ein eigener Zielcluster ohne Default-Route startet die Anwendung nur
aus Ressourcen, die zuvor aus dem CTF in die lokale Registry kopiert wurden.

## 1. Getrennten Zielcluster aufbauen

Der Zielcluster darf während seines k3d/K3s-Bootstraps noch laden. Danach
entfernt das Skript die Default-Route seines Workload-Nodes. Das direkt
verbundene Docker-Netz zur Lab-Registry bleibt erhalten.

```bash
. config/lab.env
./scripts/create-airgap-target.sh ocm-target
./scripts/set-target-egress.sh status ocm-target
```

Erwartet wird `blockiert (keine Default-Route)`. Der Lab-Cluster für Forgejo
und CI bleibt davon unberührt.

## 2. Geprüftes CTF in die Registry importieren

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export AIRGAP_INBOX="$PWD/.lab/airgap-inbox"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export OCM_REPOSITORY='http://localhost:5000/ocm'

"$TARGET_APP_WORKDIR/scripts/import-self-contained-ctf.sh" \
  "$AIRGAP_INBOX/unpacked/transport-archive-$COMPONENT_VERSION" \
  "$COMPONENT_NAME" "$COMPONENT_VERSION" "$OCM_REPOSITORY"

ocm get component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION" \
  -o yaml > "$DELIVERY_DIR/imported-component.yaml"

OCM_CONFIG="$AIRGAP_INBOX/verifier-local.ocmconfig" \
  ocm verify component-version \
  "oci::$OCM_REPOSITORY//$COMPONENT_NAME:$COMPONENT_VERSION"
```

`--copy-resources` beim Import kopiert die lokalen CTF-Blobs in die Registry
und setzt passende Zugriffe im Ziel-Descriptor. Es genügt nicht, Upstream-
Tags manuell in dieselbe Registry zu pushen: Descriptor und Resources müssen
als zusammengehörige Component Version ankommen.

## 3. Chart und Values anhand ihrer Identity herunterladen

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

Die eingepackten Values kennen noch die freigegebenen Upstream-Digests. Das
Lokalisierungsskript liest die **tatsächlichen Zielzugriffe** der drei
Image-Resources aus `imported-component.yaml`:

```bash
"$TARGET_APP_WORKDIR/scripts/localize-values.sh" \
  "$DELIVERY_DIR/imported-component.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-base.yaml" \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
yq '.images' "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml"
```

## 4. Vorprüfen und installieren

```bash
kubectl config use-context k3d-ocm-target
kubectl create namespace target-application \
  --dry-run=client -o yaml | kubectl apply -f -

"$TARGET_APP_WORKDIR/scripts/render-local-chart.sh" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  localhost:5000

helm upgrade --install target-application \
  "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-$COMPONENT_VERSION/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
helm test target-application -n target-application --logs
```

`render-local-chart.sh` blockiert bereits vor Helm jedes externe `image:` und
führt einen Kubernetes-Server-Dry-Run aus.

## Abnahme

```bash
kubectl -n target-application get pod,deploy,statefulset,service,job
helm -n target-application status target-application
```

Web und Redis sind bereit, Migration und Helm-Test waren erfolgreich, und der
Node besitzt weiterhin keine Default-Route.

Weiter mit [OCM 05 – Air-Gap-Nachweis](05-nachweis.md).
