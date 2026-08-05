# OCM Delivery Builder

Dieses Image ist der Ausführungscontainer für den Woodpecker-Release-Job. Es
enthält OCM, Helm, Mike Farahs `yq` und Skopeo. Es ist ausdrücklich **nicht**
Teil der Zielanwendungs-Komponente und darf im Vorbereitungslabor aus dem
Internet gebaut oder bezogen werden.

```bash
docker build -t ocm-delivery:0.1.0 -f ci/ocm-delivery/Dockerfile .
docker run --rm ocm-delivery:0.1.0 -lc 'ocm version && helm version && yq --version'
```

Für Woodpecker dieses Image in `examples/ci/ocm-delivery.yaml` eintragen. Vor
dem produktiven Einsatz werden alle Versionen in der Dockerfile wie ein
normales Build-Artefakt überprüft und gepflegt.
