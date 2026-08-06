# Lab 03 – Woodpecker als CI

**Ziel:** Woodpecker authentifiziert Benutzer über Forgejo und führt einen
ersten Pipeline-Schritt als Kubernetes-Pod aus. Damit stehen SCM, CI und lokale
Registry als vollständiges Vorbereitungslabor bereit.

Verwendet wird das gepinnte Woodpecker Chart `3.6.5` mit Woodpecker `3.16.0`.
Server und Agent laufen jeweils einmal; SQLite liegt auf einer 2-GiB-PVC. Die
Pipeline-Pods bleiben im Lab im Namespace `woodpecker`, damit die vom Chart
erzeugte namespaced Role exakt passt.

## 1. Gemeinsame Erreichbarkeit prüfen

Forgejo, Browser und Woodpecker müssen dieselben öffentlichen URLs verwenden.
Andernfalls schlägt OAuth entweder beim Redirect oder beim API-Zugriff fehl.

```bash
. config/lab.env
export FORGEJO_URL="${FORGEJO_URL:-http://forgejo.ocm.test:8080}"
curl --fail --show-error "$FORGEJO_URL/api/healthz"
./scripts/configure-lab-hostnames.sh
```

Prüfe Forgejo zusätzlich aus einem Pod:

```bash
kubectl run forgejo-from-cluster \
  --image=curlimages/curl:8.12.1 \
  --restart=Never --command -- \
  curl --fail --show-error \
  http://forgejo.ocm.test:8080/api/healthz
kubectl logs forgejo-from-cluster
kubectl delete pod forgejo-from-cluster
```

Dieser Test muss vor der OAuth-Konfiguration funktionieren.

## 2. OAuth2-Anwendung in Forgejo erzeugen

1. Melde dich als `ocm-admin` an Forgejo an.
2. Öffne **Site Administration -> Applications**. Für ein persönliches Lab
   funktioniert alternativ **Settings -> Applications**.
3. Erzeuge eine neue OAuth2-Anwendung mit dem Namen `woodpecker`.
4. Trage als Redirect URI exakt ein:

   ```text
   http://woodpecker.ocm.test:8080/authorize
   ```

5. Speichere die Anwendung und kopiere Client-ID und Client-Secret.

Schema, Host, Port und der Pfad `/authorize` müssen exakt übereinstimmen. Eine
Callback-URL mit `https`, ohne Port `8080` oder mit abschließendem Slash ist
eine andere URL und funktioniert hier nicht.

## 3. OAuth-Daten als Kubernetes Secret ablegen

Die Zugangsdaten werden nicht in Git oder in eine Helm-Values-Datei
geschrieben:

```bash
kubectl create namespace woodpecker \
  --dry-run=client -o yaml | kubectl apply -f -

read -r -p 'Forgejo OAuth Client-ID: ' WOODPECKER_FORGEJO_CLIENT
read -r -s -p 'Forgejo OAuth Client-Secret: ' WOODPECKER_FORGEJO_SECRET
printf '\n'

kubectl -n woodpecker create secret generic woodpecker-forgejo \
  --from-literal=WOODPECKER_FORGEJO_CLIENT="$WOODPECKER_FORGEJO_CLIENT" \
  --from-literal=WOODPECKER_FORGEJO_SECRET="$WOODPECKER_FORGEJO_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

unset WOODPECKER_FORGEJO_CLIENT WOODPECKER_FORGEJO_SECRET
```

`config/lab/woodpecker-values.yaml` referenziert dieses Secret über
`server.extraSecretNamesForEnvFrom`. Es enthält selbst keine Secrets.

## 4. Chart und Values prüfen

```bash
helm show chart \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5

helm show values \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5 > /tmp/woodpecker-3.6.5-values.yaml
```

Die Lab-Values konfigurieren:

- Forgejo unter `http://forgejo.ocm.test:8080`;
- Woodpeckers öffentliche URL `http://woodpecker.ocm.test:8080`;
- genau einen Kubernetes-Agenten und höchstens einen parallelen Workflow;
- kurzlebige 2-GiB-RWO-Volumes für Pipeline-Workspaces;
- den vorhandenen Forgejo-Benutzer `ocm-admin` als Woodpecker-Admin;
- einen Ingress über den mit k3d gelieferten Traefik.

## 5. Woodpecker installieren

```bash
helm upgrade --install woodpecker \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version 3.6.5 \
  --namespace woodpecker \
  --values config/lab/woodpecker-values.yaml \
  --wait \
  --timeout 10m
```

Status und Logs prüfen:

```bash
kubectl -n woodpecker get pod,pvc,service,ingress
kubectl -n woodpecker rollout status \
  statefulset/woodpecker-server --timeout=300s
kubectl -n woodpecker rollout status \
  deployment/woodpecker-agent --timeout=300s
kubectl -n woodpecker logs deployment/woodpecker-agent --tail=100
kubectl -n woodpecker logs statefulset/woodpecker-server --tail=100
curl --fail --show-error \
  http://woodpecker.ocm.test:8080/healthz
```

Im Agent-Log muss die Verbindung zum Server erkennbar sein. Ein Fehler
`forbidden` bei späteren Pipeline-Pods weist auf die ServiceAccount-/Role-
Konfiguration hin.

## 6. Anmelden und Repository aktivieren

1. Öffne `http://woodpecker.ocm.test:8080`.
2. Wähle die Anmeldung über Forgejo und bestätige den OAuth-Zugriff.
3. Synchronisiere die Repositories, falls `target-application` nicht sofort
   erscheint.
4. Öffne `ocm-admin/target-application` und aktiviere das Repository.

Woodpecker legt dabei den benötigten Webhook in Forgejo an. Prüfe in Forgejo
unter **Repository Settings -> Webhooks**, dass der Webhook aktiv ist und sein
letzter Test keine Netzwerkfehlermeldung zeigt.

## 7. Erste Kubernetes-Pipeline auslösen

Dieses Repository enthält `.woodpecker/smoke.yaml`. Der Schritt nutzt bewusst
das in Lab 01 gepushte Image:

```yaml
image: localhost:5000/lab/alpine:3.21
```

Damit prüft ein einziger Lauf drei Verbindungen: Forgejo-Webhook zu Woodpecker,
Woodpecker-Agent zur Kubernetes API und k3s zur lokalen Registry.

```bash
git add .woodpecker/smoke.yaml
git commit -m 'Woodpecker Smoke-Test hinzufügen'
git push forgejo main
```

Beobachte während des Laufs die kurzlebigen Ressourcen:

```bash
kubectl -n woodpecker get pods,pvc --watch
```

Die Woodpecker-Oberfläche muss den Schritt
`local-registry-smoke-test` als erfolgreich anzeigen.

## Fehleranalyse

```bash
helm -n woodpecker status woodpecker
kubectl -n woodpecker get events --sort-by=.lastTimestamp
kubectl -n woodpecker logs deployment/woodpecker-agent --tail=200
kubectl -n woodpecker logs statefulset/woodpecker-server --tail=200
```

Häufige Ursachen:

- **OAuth `redirect_uri` ungültig:** Vergleiche die URI in Forgejo
  zeichenweise mit `http://woodpecker.ocm.test:8080/authorize`.
- **Woodpecker erreicht Forgejo nicht:** Wiederhole den Pod-Test aus Schritt 1
  und prüfe `coredns-custom`, `lab-ingress` und dessen Endpoints.
- **Webhook wird abgelehnt:** Prüfe in Forgejos generierter `app.ini`, ob
  `ALLOWED_HOST_LIST` aus den Lab-Values übernommen wurde.
- **Pipeline-Pod bleibt `ImagePullBackOff`:** Wiederhole Lab 01 und kontrolliere
  auf dem Node `/etc/rancher/k3s/registries.yaml`.
- **Pipeline-Pod/PVC ist `forbidden`:** Im Lab müssen
  `WOODPECKER_BACKEND_K8S_NAMESPACE=woodpecker` und die vom Chart erzeugte Role
  im selben Namespace liegen.

## Abnahme

- Anmeldung an Woodpecker über Forgejo funktioniert.
- Das aktivierte Repository besitzt einen erfolgreichen Forgejo-Webhook.
- Der Smoke-Test läuft als Kubernetes-Pod und endet erfolgreich.
- Sein Image kommt aus `localhost:5000`, nicht aus einer externen Registry.

Damit ist der manuelle Bootstrap abgeschlossen. In
[Lab 04 – automatischer Release](04-automatischer-release.md) wird daraus die
automatische Erzeugung und Übertragung der OCM Component Version.
