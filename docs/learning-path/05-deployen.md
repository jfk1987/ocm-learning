# 05 – Lokal deployen

**Ziel:** Helm installiert ausschließlich die mit OCM gelieferte Chart-Datei;
alle Pod-Images stammen aus der lokalen Registry.

## 1. Chart aus OCM entnehmen

```bash
mkdir -p dist/deploy
ocm download resource \
  "oci::${OCM_REPOSITORY}//${COMPONENT_NAME}:${COMPONENT_VERSION}" \
  --identity name=helm-chart \
  --output dist/deploy/artifactory-oss.tgz \
  --extraction-policy disable
helm show values dist/deploy/artifactory-oss.tgz > dist/deploy/chart-defaults.yaml
```

## 2. Lokale Values erzeugen

Kopiere `ocm/artifactory/values-local-registry.yaml.tpl` nach
`dist/deploy/values-local-registry.yaml`. Übernimm für jedes Image die
lokalisierte `imageReference` aus `dist/imported-component.yaml` und verifiziere
die jeweiligen Values-Pfade gegen `chart-defaults.yaml`.

Die Zeilen für nicht verwendete Images müssen nicht gesetzt werden. Werden
Nginx, PostgreSQL oder ein optionaler Hook aktiviert, muss das dazugehörige
Image dagegen im Lockfile und Descriptor existieren.

Erzeuge das Datenbankpasswort in eurem Secret-Management-System. Für dieses
Lab darf Helm ein Passwort beim ersten Installieren erzeugen; produktiv sind
Passwörter und Master Keys jedoch vorab als Referenz auf verwaltete Secrets zu
modellieren. Keine Klartextsecrets in Git, CTF oder Helm-Values ablegen.

## 3. Vor dem Apply rendern

```bash
helm template artifactory-oss dist/deploy/artifactory-oss.tgz \
  --namespace artifactory-oss \
  --values dist/deploy/values-local-registry.yaml \
  > dist/deploy/rendered.yaml
./scripts/assert-local-images.sh dist/deploy/rendered.yaml "$LOCAL_REGISTRY"
kubectl apply --dry-run=server -f dist/deploy/rendered.yaml
```

Erst wenn beide Prüfungen erfolgreich sind:

```bash
helm upgrade --install artifactory-oss dist/deploy/artifactory-oss.tgz \
  --namespace artifactory-oss --create-namespace \
  --values dist/deploy/values-local-registry.yaml \
  --wait --timeout 15m
```

## Abnahme

Das Release ist `deployed`, und `kubectl get pods -n artifactory-oss` zeigt nur
laufende Pods. Der Image-Check aus dem gerenderten Manifest enthält keinen
externen Registry-Namen.
