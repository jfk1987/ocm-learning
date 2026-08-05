# 05 – Forgejo als internes SCM

**Ziel:** Ein internes Git-SCM läuft auf K3s und zieht sein Image ausschließlich
aus Zot.

## Vorgehen

1. Lade Chart und Values-Template über `ocm download resource` aus der
   importierten Developer-Platform-Komponente nach `dist/deploy/`.
2. Kopiere den lokalisierten `imageReference` des Forgejo-Images aus
   `imported-platform.yaml` in die Values-Datei.
3. Konfiguriere für das Lab SQLite auf dem Forgejo-PVC und genau eine Replica.
   SQLite ist hier absichtlich gewählt; bei hoher gleichzeitiger Nutzung wird
   später auf PostgreSQL migriert.
4. Rendere, führe den Local-only-Check aus und installiere das lokale Chart.

```bash
./scripts/render-local-chart.sh forgejo dist/deploy/forgejo-chart.tgz forgejo \
  dist/deploy/forgejo-values.yaml "$LOCAL_REGISTRY"
helm upgrade --install forgejo dist/deploy/forgejo-chart.tgz \
  --namespace forgejo --create-namespace \
  --values dist/deploy/forgejo-values.yaml --wait
```

Erzeuge danach in der Forgejo-UI einen lokalen Administrator und das Repository
`platform-demo`. Kein externer OAuth-Provider ist für das Lab nötig.

## Abnahme

Ein `git clone https://<forgejo-host>/platform/platform-demo.git` funktioniert
innerhalb des Offline-Netzes. Der Pod und sein PVC sind vorhanden; der
rendered-manifest-Check zeigt ausschließlich die lokale Registry.
