# OCM 05 – Positiv- und Negativnachweis

**Ziel:** Du beweist sowohl den erfolgreichen lokalen Neustart als auch das
Scheitern eines externen Pulls. Ein grünes Deployment allein reicht nicht.

## 1. Netztrennung erneut prüfen

```bash
./scripts/set-target-egress.sh status ocm-target
docker exec k3d-ocm-target-server-0 \
  wget -q -T 5 -O- http://k3d-registry.localhost:5000/v2/
```

Die Registry antwortet. `ip route show default` im Node darf dagegen keine
Route ausgeben.

## 2. Vollständigen Laufzeittest ausführen

```bash
./scripts/assert-airgap-runtime.sh k3d-ocm-target localhost:5000
```

Das Skript führt drei Kontrollen durch:

1. alle Init- und Hauptcontainer beginnen mit `localhost:5000/`;
2. ein Rollout-Neustart der Web-Anwendung gelingt mit `imagePullPolicy: Always`
   aus der lokalen Registry statt nur aus dem Node-Cache;
3. ein neues, nicht vorgecachtes Image aus `registry.k8s.io` erreicht innerhalb
   von 45 Sekunden absichtlich **nicht** den Zustand `Ready`.

Das erwartete Ende des Negativ-Pods ist `ErrImagePull` oder
`ImagePullBackOff`. Seine Events werden als Nachweis ausgegeben.

## 3. Gelaufene Digests dokumentieren

Kubernetes zeigt in `imageID` den tatsächlich gestarteten Content-Digest:

```bash
kubectl --context k3d-ocm-target -n target-application get pods -o json |
  yq -p=json -r '
    .items[] as $pod |
    (($pod.status.initContainerStatuses // []) +
     ($pod.status.containerStatuses // []))[] |
    [$pod.metadata.name, .name, .image, .imageID] | @tsv
  '
```

Speichere diese Ausgabe zusammen mit Component-Name, Version, CTF-Hash und
Signaturprüfung im Release-Nachweis deiner realen Umgebung.

## 4. Nach dem Lab Egress gezielt wieder erlauben

Nur wenn du den Zielcluster für andere Experimente weiterverwenden willst:

```bash
./scripts/set-target-egress.sh allow ocm-target
./scripts/set-target-egress.sh status ocm-target
```

Für den OCM-Nachweis bleibt Egress blockiert.

## Abnahme

Der lokale Neustart ist erfolgreich, der Upstream-Pod scheitert, und die
Liste der `imageID`-Digests ist dokumentiert.

Weiter mit [OCM 06 – Update und Rollback](06-update.md).
