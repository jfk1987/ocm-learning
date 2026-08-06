# Lab 02 – Forgejo als SCM

**Ziel:** Forgejo läuft als persistente Einzelinstanz im Lab. Am Ende gibt es
ein Administratorkonto, ein Repository `target-application`, einen
eingeschränkten Git-Zugriffstoken und einen erfolgreichen Push.

Für dieses Lernlabor verwenden wir SQLite, eine Replica und den bereits von
k3d bereitgestellten Traefik Ingress. Das ist leichtgewichtig und für das Lab
ausreichend, aber keine HA- oder Produktionskonfiguration.

Die hier geprüfte Chart-Version ist `17.1.3` (Forgejo 15). Ein Upgrade wird
nicht nebenbei vorgenommen, sondern später als eigener, geprüfter Schritt.

## 1. Cluster und Namensauflösung prüfen

```bash
. config/lab.env
kubectl config use-context "k3d-${LAB_CLUSTER}"
kubectl get nodes
curl --fail --show-error http://localhost:5000/v2/
```

`forgejo.ocm.test` muss lokal auf `127.0.0.1` auflösen:

```bash
getent hosts forgejo.ocm.test 2>/dev/null || \
  dscacheutil -q host -a name forgejo.ocm.test 2>/dev/null || true
```

Falls Lab 01 noch nicht vollständig ausgeführt wurde, ergänze lokal folgende
Zeile in der Hosts-Datei und führe das DNS-Skript aus:

```text
127.0.0.1 forgejo.ocm.test woodpecker.ocm.test
```

Unter macOS/Linux ist das `/etc/hosts`, unter Windows
`C:\Windows\System32\drivers\etc\hosts`.

```bash
./scripts/configure-lab-hostnames.sh
```

## 2. Namespace und Initial-Admin vorbereiten

Das Chart liest Benutzername und Startpasswort aus einem Kubernetes Secret.
Der Benutzername darf nicht einfach `admin` lauten.

```bash
kubectl create namespace forgejo \
  --dry-run=client -o yaml | kubectl apply -f -

export FORGEJO_ADMIN_USER='ocm-admin'
export FORGEJO_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"

kubectl -n forgejo create secret generic forgejo-admin \
  --from-literal=username="$FORGEJO_ADMIN_USER" \
  --from-literal=password="$FORGEJO_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

printf 'Forgejo-Benutzer: %s\n' "$FORGEJO_ADMIN_USER"
printf 'Forgejo-Startpasswort: %s\n' "$FORGEJO_ADMIN_PASSWORD"
```

Bewahre das ausgegebene Startpasswort nur für den nächsten Schritt auf. Die
Values verwenden `initialOnlyRequireReset`: Forgejo verlangt nach der ersten
Anmeldung ein neues Passwort, und spätere Helm-Upgrades setzen es nicht wieder
auf den Secret-Wert zurück.

## 3. Konfiguration vor der Installation verstehen

Die eingecheckte Datei `config/lab/forgejo-values.yaml` setzt:

- eine 5-GiB-PVC für Repositories, Konfiguration und SQLite-Datenbank;
- eine einzelne Forgejo-Replica;
- den Traefik Ingress `http://forgejo.ocm.test:8080`;
- das vorhandene Admin-Secret;
- deaktivierte öffentliche Selbstregistrierung;
- die Webhook-Freigabe, die in Lab 03 für Woodpecker gebraucht wird.

Prüfe vor der Installation, dass das Chart die verwendeten Werte noch kennt:

```bash
helm show chart \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3

helm show values \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3 > /tmp/forgejo-17.1.3-values.yaml
```

Das Pinnen verhindert, dass ein später veröffentlichtes Chart unbemerkt eine
andere Datenbank- oder Image-Version installiert.

## 4. Forgejo installieren

```bash
helm upgrade --install forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version 17.1.3 \
  --namespace forgejo \
  --values config/lab/forgejo-values.yaml \
  --wait \
  --wait-for-jobs \
  --timeout 10m
```

Der erste Start kann mehrere Minuten dauern, weil das Image geladen, das PVC
gebunden und die Datenbank initialisiert werden.

## 5. Kubernetes-Ressourcen prüfen

```bash
kubectl -n forgejo get pods,pvc,service,ingress
kubectl -n forgejo wait \
  --for=condition=Available deployment --all --timeout=300s
kubectl -n forgejo get ingress
curl --fail --show-error \
  http://forgejo.ocm.test:8080/api/healthz
```

Der Healthcheck muss JSON mit dem Status `pass` liefern. Falls nur die lokale
Namensauflösung fehlt, kann der HTTP-Test ohne Änderung an `/etc/hosts` so
erzwungen werden:

```bash
curl --fail --show-error \
  --resolve forgejo.ocm.test:8080:127.0.0.1 \
  http://forgejo.ocm.test:8080/api/healthz
```

## 6. Erstanmeldung abschließen

1. Öffne `http://forgejo.ocm.test:8080` im Browser.
2. Melde dich als `ocm-admin` mit dem in Schritt 2 ausgegebenen Passwort an.
3. Setze das verlangte neue Passwort.
4. Öffne rechts oben **Settings -> Applications**.
5. Erzeuge unter **Manage Access Tokens** einen Token mit Zugriff auf alle
   Repositories dieses Lab-Benutzers und mindestens `write:repository`.
6. Kopiere den Token sofort in deinen Passwortmanager; Forgejo zeigt ihn nur
   einmal an.

Der Zugriffstoken wird bei Git-over-HTTP als Passwort verwendet. Das echte
Kontopasswort muss dadurch weder in einer Remote-URL noch in einer CI-Datei
stehen.

Nachdem das Passwort geändert wurde, kann die temporäre Shellvariable entfernt
werden:

```bash
unset FORGEJO_ADMIN_PASSWORD
```

## 7. Repository anlegen

In der Forgejo-Oberfläche:

1. Wähle rechts oben **+ -> New Repository**.
2. Owner: `ocm-admin`.
3. Repository name: `target-application`.
4. Visibility: für das Lab **Private**.
5. **Initialize repository** bleibt deaktiviert, weil der vorhandene
   Projektstand gepusht wird.
6. Bestätige mit **Create Repository**.

Die Ziel-URL lautet danach:

```text
http://forgejo.ocm.test:8080/ocm-admin/target-application.git
```

## 8. Projekt pushen und erneut klonen

Falls dieses Verzeichnis noch kein Git-Repository ist:

```bash
git init -b main
git add .
git commit -m 'Initialer OCM-Lernpfad'
```

Remote hinzufügen und pushen:

```bash
git remote add forgejo \
  http://forgejo.ocm.test:8080/ocm-admin/target-application.git
git push -u forgejo main
```

Existiert ein Remote namens `forgejo` bereits, wird statt `remote add`
folgender Befehl verwendet:

```bash
git remote set-url forgejo \
  http://forgejo.ocm.test:8080/ocm-admin/target-application.git
```

Bei der Anmeldemaske ist der Benutzer `ocm-admin`; als Passwort wird der in
Schritt 6 erzeugte Zugriffstoken eingegeben. Prüfe danach einen unabhängigen
Clone außerhalb des Arbeitsverzeichnisses:

```bash
git clone \
  http://forgejo.ocm.test:8080/ocm-admin/target-application.git \
  /tmp/target-application-check
git -C /tmp/target-application-check log -1 --oneline
```

## Fehleranalyse

Helm- und Pod-Status:

```bash
helm -n forgejo status forgejo
kubectl -n forgejo get events --sort-by=.lastTimestamp
kubectl -n forgejo logs deployment/forgejo --all-containers --tail=200
kubectl -n forgejo describe pod -l app.kubernetes.io/instance=forgejo
```

Häufige Ursachen:

- **PVC bleibt `Pending`:** `kubectl get storageclass`; k3d sollte die
  `local-path` StorageClass als Standard bereitstellen.
- **Ingress antwortet mit 404:** Prüfe Hostname und Port. Der Request muss den
  Host-Header `forgejo.ocm.test` tragen und an Port `8080` gehen.
- **Admin-Anmeldung schlägt fehl:** Das Secret initialisiert nur eine neue
  Installation. Bei einer bestehenden PVC bleibt das bereits in Forgejo
  gespeicherte Passwort gültig. Setze es dann gezielt über die Forgejo-CLI
  zurück, statt das Secret wiederholt zu ändern.
- **Git meldet 401:** Nutze den Zugriffstoken als HTTP-Passwort und prüfe, ob
  er `write:repository` sowie Zugriff auf `target-application` besitzt.

## Abnahme

- `/api/healthz` meldet `pass`.
- Pod und PVC im Namespace `forgejo` sind `Running` beziehungsweise `Bound`.
- Das private Repository `ocm-admin/target-application` existiert.
- `git push` und der unabhängige `git clone` funktionieren mit einem Token.

Danach ist Forgejo als SCM für [Lab 03 – Woodpecker](03-woodpecker.md)
vorbereitet.
