# OCM Delivery Builder

Dieses Image ist der Ausführungscontainer für den Woodpecker-Release-Job. Es
enthält OCM, Helm, Mike Farahs `yq` und Skopeo. Es ist ausdrücklich **nicht**
Teil der Zielanwendungs-Komponente und darf im Vorbereitungslabor aus dem
Internet gebaut oder bezogen werden.

```bash
docker build \
  --tag localhost:5000/lab/ocm-delivery:0.1.0 \
  --file ci/ocm-delivery/Dockerfile .
docker run --rm localhost:5000/lab/ocm-delivery:0.1.0 -lc \
  'ocm version && helm version && yq --version && skopeo --version'
docker push localhost:5000/lab/ocm-delivery:0.1.0
```

Für Woodpecker dieses Image in `examples/ci/ocm-delivery.yaml` eintragen. Vor
dem produktiven Einsatz werden alle Versionen in der Dockerfile wie ein
normales Build-Artefakt überprüft und gepflegt. Die Dockerfile verwendet
`TARGETARCH`, damit sie sowohl auf `amd64`- als auch auf `arm64`-Hosts gebaut
werden kann. Im Lab wird für dieselbe Architektur wie der k3d-Node gebaut.
