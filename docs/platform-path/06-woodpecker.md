# 06 – Woodpecker als Kubernetes-native CI

**Ziel:** Push- und Pull-Request-Ereignisse aus Forgejo können CI-Pods in K3s
auslösen.

Woodpecker verwendet im Lab SQLite und einen einzelnen Agent. Der Agent wird
mit `WOODPECKER_BACKEND=kubernetes` konfiguriert. Dadurch startet jeder
Pipeline-Schritt als temporärer Pod; ein Docker-Socket oder privilegierter
Docker-in-Docker-Container ist nicht erforderlich.

## Einrichtung

1. Erzeuge in Forgejo eine systemweite OAuth2-Anwendung. Die Callback-URL ist
   exakt `https://<woodpecker-host>/authorize`.
2. Lege Client-ID, Client-Secret und das Woodpecker-Agent-Secret als Kubernetes
   Secrets an. Niemals in Values, CTF oder Git einchecken.
3. Fülle in der lokalen Woodpecker-Values-Datei:

```text
WOODPECKER_FORGEJO=true
WOODPECKER_FORGEJO_URL=https://<forgejo-host>
WOODPECKER_BACKEND=kubernetes
WOODPECKER_BACKEND_K8S_NAMESPACE=ci-jobs
WOODPECKER_BACKEND_K8S_PULL_SECRET_NAMES=registry-pull
```

4. Stelle sicher, dass die zugehörige ServiceAccount/RBAC-Regel nur Pods, Jobs,
   ConfigMaps, Secrets und temporäre PVCs im Namespace `ci-jobs` verwalten darf.
5. Rendere und installiere wie bei Forgejo ausschließlich aus dem lokal
   extrahierten Chart.

Falls Forgejo und Woodpecker intern miteinander sprechen, setze in Forgejo die
Webhook-Allowlist so, dass die Webhooks nicht blockiert werden.

## Abnahme

Die Anmeldung an Woodpecker per Forgejo-OAuth funktioniert. Das Repository
`platform-demo` kann dort aktiviert werden und Forgejo zeigt einen erreichbaren
Webhook für Woodpecker.
