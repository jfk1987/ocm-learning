# 07 – Erste vollständig lokale Pipeline

**Ziel:** Ein Git-Push erzeugt einen CI-Pod, der ausschließlich ein gelocktes
Image aus Zot verwendet.

Vorher muss das im Beispiel verwendete CI-Basisimage im Lockfile stehen und mit
der Developer-Platform-Komponente transferiert worden sein. Ersetze die
Image-Referenz in `examples/ci/local-only.yaml` durch die lokalisierte Referenz
aus dem OCM Descriptor.

```bash
ocm download resource \
  "oci::${OCM_REPOSITORY}//example.org/platform/developer-platform:0.1.0" \
  --identity name=local-only-pipeline-template \
  --output .woodpecker/local-only.yaml
git add .woodpecker/local-only.yaml
git commit -m 'ci: add local-only pipeline'
git push
```

Beobachte die Ausführung:

```bash
kubectl get pods -n ci-jobs -w
kubectl get events -n ci-jobs --sort-by=.lastTimestamp
```

Die Pipeline muss grün werden. Ersetze anschließend testweise die Image-
Referenz durch einen öffentlichen Namen. Der Job muss beim Pull scheitern – das
ist der gewünschte Nachweis, dass keine heimliche Internetabhängigkeit besteht.

## Abnahme

Ein erfolgreicher Pipeline-Pod zeigt nur eine lokale Image-Referenz. Ein
öffentlicher Image-Name scheitert erwartbar, und Forgejo erhält den Status
dieser Pipeline zurück.
