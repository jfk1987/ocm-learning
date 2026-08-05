# 03 – K3s ohne Internet installieren

**Ziel:** Ein K3s-Single-Server läuft ausschließlich mit dem gelieferten
Binary und dem gelieferten Airgap-Image-Archiv.

Auf dem K3s-Node werden die Resources aus der Bootstrap-Komponente entnommen.
Die Version des Binaries und die des Airgap-Archivs müssen übereinstimmen.

```bash
install -m 0755 dist/bootstrap/k3s /usr/local/bin/k3s
install -d -m 0755 /var/lib/rancher/k3s/agent/images
install -m 0644 dist/bootstrap/k3s-airgap-images-amd64.tar.zst \
  /var/lib/rancher/k3s/agent/images/
INSTALL_K3S_SKIP_DOWNLOAD=true \
  sh dist/bootstrap/install.sh server \
  --disable traefik \
  --disable servicelb
```

`--disable traefik` und `--disable servicelb` halten das Lab klein und
verhindern zusätzliche Workloads. Ein Ingress Controller wird erst später als
eigene OCM-Komponente ergänzt.

Nach dem Start:

```bash
k3s kubectl get nodes
k3s kubectl get pods -A
```

## Vertrauen zur Registry

Installiere die CA der Registry sowohl im Betriebssystem-Truststore als auch
für die K3s-Container-Runtime. Die genaue Datei ist
`/etc/rancher/k3s/registries.yaml`; die sichere Vorlage liegt unter
[`config/registry/k3s-registries.yaml.tpl`](../../config/registry/k3s-registries.yaml.tpl).
Die Datei enthält ein Pull-Passwort, liegt nur auf dem Node und erhält Modus
`0600`.
Nutze keine Einstellung, die TLS-Validierung global abschaltet.

## Abnahme

Der Node ist `Ready`, die K3s-Systempods laufen und ein temporärer Pod kann ein
absichtlich vorbereitetes Image aus `REGISTRY_HOST:REGISTRY_PORT` ziehen. Ein
Versuch mit einer öffentlichen Image-Referenz muss wegen fehlendem Egress
scheitern.
