# 00 – Voraussetzungen

**Ziel:** Die beiden Zonen und die Werkzeuge sind definiert.

## Benötigt

- Connected Build-Station: `ocm` (aktuelle 0.12-Linie), `helm`, `yq`, `skopeo`,
  `sha256sum` und Internetzugang.
- Offline-Station: dieselben Tools plus Netzwerkzugang zur lokalen OCI Registry.
- Kubernetes-Zugang: `kubectl`, eine StorageClass und Berechtigung für Namespace,
  Secret, PVC und Workloads.
- Ein sicherer, dokumentierter Transferweg für eine Datei (beispielsweise eine
  geprüfte Schleuse oder ein verschlüsseltes Wechsellaufwerk).

## Aufgabe

```bash
cp config/artifactory-lab.env.example config/artifactory-lab.env
$EDITOR config/artifactory-lab.env
./scripts/preflight.sh
```

Trage echte DNS-Namen für `LOCAL_REGISTRY` und `OCM_REPOSITORY` ein. Die
Registry muss von *jedem* Kubernetes-Node erreichbar sein. Wenn sie TLS mit
einer privaten CA nutzt, muss diese CA dem Container-Runtime-Truststore jedes
Nodes bekannt sein.

## Abnahme

`./scripts/preflight.sh` endet erfolgreich und `config/artifactory-lab.env` enthält keine
Credentials. Registry-Zugangsdaten werden später als Kubernetes Pull Secret
oder in einem lokalen Credential Store hinterlegt.
