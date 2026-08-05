# 01 – Chart rendern und Lieferumfang locken

**Ziel:** Kein Image und keine Chart-Abhängigkeit bleibt implizit.

Auf der Connected Build-Station wird das gewünschte Chart in eine lokale Datei
gezogen. Helm-Abhängigkeiten müssen dabei bereits im Paket enthalten sein;
führe bei einem Quellchart zuvor `helm dependency build` und `helm package`
aus. Rendere anschließend mit den Produktions-nahen Values:

```bash
mkdir -p "$DELIVERY_DIR"
helm template target-application ./target-application-chart.tgz \
  --namespace target-application --values values-airgap.yaml \
  > "$DELIVERY_DIR/rendered.yaml"
./scripts/discover-images.sh "$DELIVERY_DIR/images.discovered.txt" \
  "$DELIVERY_DIR/rendered.yaml"
```

Übernimm jede Referenz nach `config/application.lock.yaml`. Lege pro Image
Name, Upstream-Referenz, Version, Zielarchitektur und `sha256`-Digest ab. Ein
Tag allein genügt nicht. Mit `skopeo inspect --raw docker://<image>` prüfst du,
ob ein Manifest-Index vorliegt und welche Plattformen verfügbar sind.

Vergiss nicht Images, die nur bei bestimmten Helm-Values aktiviert werden:
Migrationsjobs, Exporter, Init-Container, CronJobs, Service Mesh Sidecars und
Admission-Webhooks. Für jede relevante Variante wird gerendert und die
Image-Listen werden vereinigt.

## Abnahme

`images.discovered.txt` und `application.lock.yaml` enthalten dieselbe Menge
an Images. Alle Digests sind festgelegt, und das Chart ist als lokale `.tgz`
Datei inklusive Abhängigkeiten vorhanden.
