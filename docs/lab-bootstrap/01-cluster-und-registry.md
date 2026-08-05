# Lab 01 – k3d-Cluster und lokale Registry

**Ziel:** Ein kleiner K3s-Cluster und eine OCI Registry stehen für das Lab
bereit.

```bash
k3d registry create ocm-registry --port 5000
k3d cluster create ocm-lab \
  --servers 1 --agents 1 \
  --registry-use k3d-ocm-registry:5000 \
  --port '8080:80@loadbalancer'
kubectl cluster-info
kubectl get nodes
```

Für lokale Pushes verwendest du `k3d-ocm-registry.localhost:5000`. K3d stellt
den Nodes den Registry-Namen `k3d-ocm-registry:5000` bereit; für diesen
Lernpfad verwenden die gerenderten Workload-Values die vom Zielcluster
erreichbare Referenz.

Teste den gesamten Pull-Pfad einmal:

```bash
docker pull alpine:3.21
docker tag alpine:3.21 k3d-ocm-registry.localhost:5000/test/alpine:3.21
docker push k3d-ocm-registry.localhost:5000/test/alpine:3.21
kubectl run registry-test \
  --image=k3d-ocm-registry.localhost:5000/test/alpine:3.21 \
  --restart=Never --command -- sleep 30
```

## Abnahme

`registry-test` erreicht `Completed` oder `Running`. Damit ist die Registry als
spätere Zielregistry einsatzbereit.
