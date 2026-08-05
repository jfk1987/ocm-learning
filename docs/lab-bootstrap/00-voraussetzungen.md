# Lab 00 – Voraussetzungen

**Ziel:** Die lokale Lernumgebung kann Cluster, Registry und Plattformdienste
aus dem Internet aufbauen. Erst die Zielanwendung wird später air-gapped
geliefert.

Installiere auf dem Rechner Docker Desktop oder Docker Engine sowie `k3d`,
`kubectl`, `helm`, `ocm`, `yq` und `skopeo`. Für macOS ist Homebrew, für Linux
der jeweilige Paketmanager geeignet. Prüfe danach:

```bash
docker version
k3d version
kubectl version --client
helm version
ocm version
```

Dieses Lab ist für einen Entwicklungsrechner gedacht, nicht für Produktion.
Die Vorbereitung darf Images und Charts aus dem Internet laden.

Prüfe alles zusammen mit:

```bash
./scripts/preflight-lab.sh
```

## Abnahme

Alle Befehle sind verfügbar und Docker kann einen Testcontainer starten.
