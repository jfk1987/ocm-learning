# Lab 03 – Woodpecker als CI

**Ziel:** Forgejo-Pushes können einen kontrollierten Release-Job starten.

Installiere das offizielle Woodpecker-Chart. Der Kubernetes-Backend-Agent
erstellt Pipeline-Schritte als Pods; ein Docker-Socket im Cluster ist nicht
erforderlich.

```bash
helm upgrade --install woodpecker \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version <GEPRUEFTE_CHART_VERSION> \
  --namespace woodpecker --create-namespace
```

Erstelle in Forgejo eine OAuth2-Anwendung mit Callback
`https://<woodpecker-host>/authorize`. Lege Client-ID, Client-Secret,
Woodpecker-Agent-Secret und die Zugangsdaten der Zielregistry als Kubernetes
Secrets an. Konfiguriere den Agent mit `WOODPECKER_BACKEND=kubernetes` und
einem separaten Namespace `ci-jobs`.

Die genaue Values-Struktur wird vor Installation stets mit
`helm show values oci://ghcr.io/woodpecker-ci/helm/woodpecker --version ...`
gegen die gepinnte Chart-Version geprüft.

## Abnahme

Die Anmeldung an Woodpecker über Forgejo funktioniert und ein aktiviertes
Repository kann einen einfachen CI-Job auslösen.
