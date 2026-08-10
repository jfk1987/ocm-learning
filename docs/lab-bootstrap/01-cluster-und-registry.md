# Lab 01 – k3d-Cluster und lokale Registry

**Ziel:** Ein kleiner K3s-Cluster und eine lokale OCI Registry laufen. Ein vom
Host gepushtes Image kann anschließend vom Cluster unter exakt derselben
Referenz `localhost:5000/...` gepullt werden.

## Warum die zusätzliche Registry-Konfiguration nötig ist

`localhost` bezeichnet aus Sicht des Entwicklungsrechners den Rechner selbst,
aus Sicht eines k3s-Nodes aber den jeweiligen Node-Container. Deshalb gelten
zwei Netzwerkadressen:

| Sicht | tatsächlicher Registry-Endpunkt |
| --- | --- |
| Host: Docker, OCM, skopeo | `http://localhost:5000` |
| k3d-/k3s-Container | `http://k3d-registry.localhost:5000` |

Kubernetes-Manifeste sollen diese Infrastrukturdetails nicht kennen. Die Datei
`config/lab/k3d-registries.yaml` lässt containerd deshalb
`localhost:5000` intern auf den zweiten HTTP-Endpunkt spiegeln. Es gibt im Lab
bewusst kein TLS. Diese Konfiguration ist nicht für eine produktive Registry
geeignet.

## 1. Ausgangslage prüfen

```bash
. config/lab.env
export LAB_CLUSTER="${LAB_CLUSTER:-ocm-lab}"
export LAB_REGISTRY_CONTAINER="${LAB_REGISTRY_CONTAINER:-k3d-registry.localhost:5000}"
export LAB_INGRESS_PORT="${LAB_INGRESS_PORT:-8080}"
docker info >/dev/null
k3d cluster list
k3d registry list
lsof -nP -iTCP:5000 -sTCP:LISTEN || true
lsof -nP -iTCP:8080 -sTCP:LISTEN || true
```

Die drei Fallback-Zuweisungen machen auch eine ältere `config/lab.env`
lauffähig. Gleiche sie anschließend mit `config/lab.env.example` ab, damit die
neuen Werte dauerhaft vorhanden sind.

Die Ports `5000` und `8080` müssen frei sein. Falls bereits ein älteres Lab
nach der vorherigen Anleitung existiert, ist wichtig: Die containerd-Mirror-
Konfiguration wird nur beim Erzeugen des Clusters eingebaut. Ein bestehender
Cluster erhält sie nicht durch einen späteren Helm- oder kubectl-Befehl.

Wenn das alte Lab keine erhaltenswerten Daten enthält, kann es bewusst neu
aufgebaut werden:

```bash
k3d cluster delete ocm-lab
k3d registry delete ocm-registry || true
k3d registry delete registry.localhost || true
```

Die Befehle löschen Cluster-Daten und Registry-Inhalte. Überspringe sie, wenn
du Daten behalten musst.

## 2. HTTP-Registry erzeugen

```bash
k3d registry create registry.localhost --port 127.0.0.1:5000
k3d registry list
docker ps --filter name=k3d-registry.localhost
curl --fail --show-error http://localhost:5000/v2/
```

Der letzte Befehl liefert `{}` oder eine leere erfolgreiche Antwort mit HTTP
200. Das ist der minimale Registry-V2-Healthcheck.

Wichtig: In Docker-Tags steht weder `http://` noch `https://`, sondern nur
`localhost:5000/pfad/image:tag`.

## 3. Cluster mit Registry-Mirror erzeugen

```bash
k3d cluster create "$LAB_CLUSTER" \
  --servers 1 \
  --agents 1 \
  --registry-use "$LAB_REGISTRY_CONTAINER" \
  --registry-config config/lab/k3d-registries.yaml \
  --port "${LAB_INGRESS_PORT}:80@loadbalancer" \
  --wait
```

Anschließend wird ausschließlich der neu erzeugte Kontext verwendet:

```bash
kubectl config use-context "k3d-${LAB_CLUSTER}"
kubectl cluster-info
kubectl get nodes -o wide
kubectl wait --for=condition=Ready node --all --timeout=120s
```

Die installierte Mirror-Datei lässt sich im Server-Node nachvollziehen:

```bash
docker exec "k3d-${LAB_CLUSTER}-server-0" \
  cat /etc/rancher/k3s/registries.yaml
```

Sie muss einen Mirror für `localhost:5000` und den HTTP-Endpunkt
`k3d-registry.localhost:5000` enthalten.

## 4. Gemeinsame Plattform-Hostnamen einrichten

Forgejo und Woodpecker verwenden später OAuth-Redirects. Dafür müssen ihre
URLs sowohl vom Browser auf dem Host als auch aus Pods erreichbar sein. Trage
auf dem Host einmalig ein:

```text
127.0.0.1 forgejo.ocm.test woodpecker.ocm.test
```

Unter macOS/Linux gehört die Zeile in `/etc/hosts`, unter Windows in
`C:\Windows\System32\drivers\etc\hosts`. Danach richtet das Projekt die
gleichen Namen im K3s-CoreDNS ein:

```bash
./scripts/configure-lab-hostnames.sh
kubectl -n kube-system get service,endpoints lab-ingress
```

Der zusätzliche `lab-ingress` Service macht Traefik innerhalb des Clusters an
Port `8080` erreichbar. So ist beispielsweise
`http://forgejo.ocm.test:8080` innen und außen dieselbe URL.

Das Skript legt die Zone `ocm.test` als eigenen CoreDNS Server Block in
`lab.server` an. Es verwendet bewusst kein `lab.override`: Der K3s-Standard-
Server-Block enthält bereits ein `hosts`-Plugin, und CoreDNS erlaubt dieses
Plugin pro Server Block nur einmal.

Teste die DNS-Auflösung innerhalb des Clusters:

```bash
kubectl delete pod lab-dns-test --ignore-not-found
kubectl run lab-dns-test \
  --image=busybox:1.36 \
  --restart=Never --command -- \
  nslookup forgejo.ocm.test
kubectl logs lab-dns-test
kubectl delete pod lab-dns-test
```

Falls eine ältere Version des Skripts bereits `lab.override` erzeugt hat und
CoreDNS mit `plugin/hosts: this plugin can only be used once per Server Block`
ausfällt, repariert ein erneuter Aufruf die ConfigMap und startet CoreDNS neu:

```bash
./scripts/configure-lab-hostnames.sh
kubectl -n kube-system get configmap coredns-custom -o yaml
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
kubectl -n kube-system logs deployment/coredns --tail=50
```

Unter `data` darf danach nur `lab.server`, nicht mehr `lab.override`, für das
Lab stehen.

## 5. Push vom Host prüfen

```bash
docker pull public.ecr.aws/docker/library/alpine:3.21
docker tag public.ecr.aws/docker/library/alpine:3.21 \
  localhost:5000/lab/alpine:3.21
docker image inspect localhost:5000/lab/alpine:3.21 >/dev/null
docker push localhost:5000/lab/alpine:3.21
curl --fail --show-error http://localhost:5000/v2/_catalog
curl --fail --show-error \
  http://localhost:5000/v2/lab/alpine/tags/list
```

Der Push muss mit einer Digest-Zeile erfolgreich enden. Der Katalog muss danach
`lab/alpine`, die Tag-Liste `3.21` enthalten. Damit ist der Weg
`Docker auf dem Host -> Registry` abgeschlossen. Optional bestätigt skopeo
denselben Inhalt ohne TLS:

```bash
skopeo list-tags --tls-verify=false \
  docker://localhost:5000/lab/alpine
```

## 6. Pull im Cluster prüfen

```bash
kubectl run registry-test \
  --image=localhost:5000/lab/alpine:3.21 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/registry-test --timeout=120s
kubectl get pod registry-test \
  -o jsonpath='{.spec.containers[0].image}{"\n"}'
kubectl exec registry-test -- cat /etc/alpine-release
```

Die ausgegebene Image-Referenz bleibt `localhost:5000/...`; nur der Runtime-
Mirror kennt die interne Adresse. Nach erfolgreichem Test kann der Test-Pod
entfernt werden:

```bash
kubectl delete pod registry-test
```

## Fehleranalyse: Docker erwartet HTTPS

Typische Meldung:

```text
server gave HTTP response to HTTPS client
```

Prüfe der Reihe nach:

1. Nutzt der Push exakt `localhost:5000/...`? Der frühere Name
   `k3d-ocm-registry.localhost:5000` ist auf manchen Hosts nicht als
   Loopback-/Insecure-Registry klassifiziert und darf nicht mehr verwendet
   werden.
2. Antwortet `curl http://localhost:5000/v2/`? Wenn nicht, prüfe
   `docker logs k3d-registry.localhost` und die Portbelegung.
3. Enthält der Image-Name versehentlich `https://`? Schemas sind in
   OCI-Image-Referenzen unzulässig.
4. Erzwingt deine Docker-Installation auch für Loopback TLS, trage nur für
   dieses isolierte Lab `localhost:5000` unter Docker Engine als
   `insecure-registries` ein und starte Docker neu:

   ```json
   {
     "insecure-registries": ["localhost:5000"]
   }
   ```

   Führe diesen Schritt nur aus, wenn die ersten drei Prüfungen den Fehler
   nicht erklären. Für echte Umgebungen wird eine Registry mit TLS und
   vertrauenswürdiger CA verwendet.

## Fehleranalyse: `ImagePullBackOff`

```bash
kubectl describe pod registry-test
kubectl get events --sort-by=.lastTimestamp
docker logs k3d-registry.localhost
docker exec "k3d-${LAB_CLUSTER}-server-0" \
  cat /etc/rancher/k3s/registries.yaml
```

Steht in den Events ein Zugriff auf `https://localhost:5000`, wurde der
Cluster ohne `--registry-config` erzeugt oder die Mirror-Datei ist falsch. Da
k3s diese Konfiguration beim Bootstrap erhält, wird der Lab-Cluster dann mit
Schritt 3 neu erzeugt.

## Fehleranalyse: Die Tags-URL liefert `404`

Ein HTTP `404` auf `/v2/lab/alpine/tags/list` bedeutet normalerweise, dass die
Registry erreichbar ist, aber dort kein Repository namens `lab/alpine`
existiert. Zeige die Fehlerantwort zunächst ohne `--fail` und frage den
Registry-Katalog ab:

```bash
curl --show-error http://localhost:5000/v2/lab/alpine/tags/list
curl --fail --show-error http://localhost:5000/v2/_catalog
```

Eine Antwort mit `NAME_UNKNOWN` bestätigt den fehlenden Repository-Namen. Ist
der Katalog leer oder enthält nur einen früher verwendeten Pfad wie
`test/alpine`, wiederhole Tag und Push mit der aktuellen Referenz und achte auf
den Exit-Code:

```bash
docker image inspect public.ecr.aws/docker/library/alpine:3.21 >/dev/null
docker tag public.ecr.aws/docker/library/alpine:3.21 \
  localhost:5000/lab/alpine:3.21
docker push localhost:5000/lab/alpine:3.21
echo "$?"
```

Nur der Exit-Code `0` bestätigt einen erfolgreichen Push. Bleibt der Katalog
danach leer, vergleiche Port-Mapping und Registry-Logs:

```bash
docker ps --filter name=k3d-registry.localhost \
  --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'
docker logs k3d-registry.localhost --tail=100
```

Der Container muss Host-Port `127.0.0.1:5000` veröffentlichen. Ein anderer
Container oder ein anderes Port-Mapping bedeutet, dass Push und curl nicht
dieselbe Registry ansprechen.

## Abnahme

- `curl http://localhost:5000/v2/lab/alpine/tags/list` enthält `3.21`.
- `kubectl wait ... pod/registry-test` war erfolgreich.
- Der Pod verwendet in seinem Manifest `localhost:5000/lab/alpine:3.21`.
- Host und Cluster können `forgejo.ocm.test` auflösen.

Damit ist die Registry sowohl für spätere OCM-Transfers vom Host als auch für
Kubernetes-Pulls vorbereitet. Weiter geht es mit
[Lab 02 – Forgejo](02-forgejo.md).
