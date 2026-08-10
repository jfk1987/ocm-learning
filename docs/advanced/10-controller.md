# OCM 10 – Deklaratives Deployment mit dem OCM Controller

**Ziel:** Der OCM Kubernetes Controller liest eine Component Version und
wendet eine darin gespeicherte Deployment-Resource über den Deployer an.

Dieses Aufbau-Lab läuft bewusst im **internetfähigen Lab-Cluster**. Die
Controller sind ein sich schnell entwickelndes Zusatzsystem und nicht nötig
für den zuvor bewiesenen Air-Gap-Kernpfad.

## 1. Controller installieren

```bash
kubectl config use-context k3d-ocm-lab
helm upgrade --install ocm-k8s-toolkit \
  oci://ghcr.io/open-component-model/kubernetes/controller/chart \
  --version 0.4.0 \
  --namespace ocm-k8s-toolkit-system --create-namespace \
  --wait --timeout 10m
kubectl -n ocm-k8s-toolkit-system get pods
```

Für dieses Raw-Manifest-Beispiel sind weder kro noch Flux erforderlich.

## 2. Minimales RBAC vergeben

Der Deployer darf standardmäßig nur seine eigenen CRDs verwalten. Unser
Manifest erzeugt ein `apps/Deployment`; deshalb wird nur diese Ressource
freigegeben:

```bash
kubectl apply -f examples/controller/custom-rbac.yaml
kubectl auth can-i create deployments.apps \
  --as=system:serviceaccount:ocm-k8s-toolkit-system:ocm-k8s-toolkit-controller-manager
```

Die Antwort muss `yes` sein. Erweitere dieses ClusterRole nicht pauschal auf
`*`.

## 3. Controller-Komponente veröffentlichen

```bash
(cd examples/controller && ocm add component-version \
  --repository 'oci::http://localhost:5000/ocm' \
  --constructor component-constructor.yaml)
ocm get component-version \
  'oci::http://localhost:5000/ocm//example.org/ocm-learning/controller-demo:1.0.0'
```

Die Deployment-Resource verwendet das bereits in Lab 01 in die lokale
Registry gepushte Alpine-Image. Der Controller-Pod erreicht dieselbe Registry
intern unter `k3d-registry.localhost:5000`.

## 4. Vier Controller-Objekte anwenden

```bash
kubectl apply -f examples/controller/bootstrap.yaml.tpl
kubectl get repository,component,resource,deployer -o wide
kubectl rollout status deployment/ocm-controller-demo --timeout=180s
kubectl logs deployment/ocm-controller-demo --tail=5
```

Die Kette ist absichtlich sichtbar:

1. `Repository` verbindet das OCI Repository;
2. `Component` selektiert Name und SemVer;
3. `Resource` wählt `name=deployment-resource`;
4. `Deployer` lädt das YAML und wendet es per Server-Side Apply/ApplySet an.

## 5. Lifecycle und Drift testen

```bash
kubectl scale deployment/ocm-controller-demo --replicas=2
kubectl get deployment/ocm-controller-demo --watch
```

Der Deployer reconciliert den im OCM-Artefakt festgelegten Stand. Lösche
anschließend die Controller-Kette:

```bash
kubectl delete -f examples/controller/bootstrap.yaml.tpl
kubectl get deployment/ocm-controller-demo
```

Durch ApplySet-Lifecycle wird auch das verwaltete Deployment entfernt.

## Abnahme

Alle vier OCM-CRs werden Ready, der Pod schreibt Logs, und das Entfernen des
Deployer-Graphen räumt das angewendete Deployment auf.

Der letzte Pflichtschritt ist
[Lab 04 – automatische OCM-Lieferung](../lab-bootstrap/04-automatischer-release.md).
