# Lab 02 – Forgejo als SCM

**Ziel:** Ein internes Git-Repository dient als Quelle für Anwendung, Lockfile
und CI-Konfiguration.

Installiere das offizielle Forgejo-Chart in einem eigenen Namespace. Die
Plattform darf hierfür den OCI-Chart und das Image direkt beziehen. Pinne die
Chart-Version trotzdem bewusst:

```bash
helm upgrade --install forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --version <GEPRUEFTE_CHART_VERSION> \
  --namespace forgejo --create-namespace \
  --set gitea.config.database.DB_TYPE=sqlite3
```

Für das Lab genügt SQLite mit einer Replica. Richte anschließend per Ingress
oder `kubectl port-forward` den Zugriff ein, erstelle einen Administrator und
ein Repository `target-application`. Committe den Anwendungs-Chart, Values,
`config/application.lock.yaml` und die CI-Datei dorthin.

## Abnahme

Ein lokaler `git clone` und ein `git push` zum Forgejo-Repository funktionieren.
