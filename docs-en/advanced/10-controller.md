# OCM 10 – Declarative deployment with the OCM controller

**Goal:** The OCM Kubernetes controller reads a Component Version and applies a
deployment Resource stored in it through the Deployer.

This advanced lab deliberately runs in the **Internet-connected lab cluster**.
The controllers are a fast-moving add-on system and are not required for the
air-gapped core path proved earlier.

## 1. Install the controller

```bash
kubectl config use-context k3d-ocm-lab
helm upgrade --install ocm-k8s-toolkit \
  oci://ghcr.io/open-component-model/kubernetes/controller/chart \
  --version 0.4.0 \
  --namespace ocm-k8s-toolkit-system --create-namespace \
  --wait --timeout 10m
kubectl -n ocm-k8s-toolkit-system get pods
```

Neither kro nor Flux is required for this raw-manifest example.

## 2. Grant minimal RBAC

By default, the Deployer may manage only its own CRDs. Our manifest creates an
`apps/Deployment`, so only that resource is granted:

```bash
kubectl apply -f examples/controller/custom-rbac.yaml
kubectl auth can-i create deployments.apps \
  --as=system:serviceaccount:ocm-k8s-toolkit-system:ocm-k8s-toolkit-controller-manager
```

The answer must be `yes`. Do not broaden this ClusterRole to `*` wholesale.

## 3. Publish the controller component

```bash
(cd examples/controller && ocm add component-version \
  --repository 'oci::http://localhost:5000/ocm' \
  --constructor component-constructor.yaml)
ocm get component-version \
  'oci::http://localhost:5000/ocm//example.org/ocm-learning/controller-demo:1.0.0'
```

The deployment Resource uses the Alpine image pushed to the local registry in
Lab 01. The controller pod reaches the same registry internally at
`k3d-registry.localhost:5000`.

## 4. Apply four controller objects

```bash
kubectl apply -f examples/controller/bootstrap.yaml.tpl
kubectl get repository,component,resource,deployer -o wide
kubectl rollout status deployment/ocm-controller-demo --timeout=180s
kubectl logs deployment/ocm-controller-demo --tail=5
```

The chain is intentionally visible:

1. `Repository` connects the OCI repository;
2. `Component` selects the name and SemVer;
3. `Resource` selects `name=deployment-resource`;
4. `Deployer` downloads the YAML and applies it with Server-Side Apply/ApplySet.

## 5. Test lifecycle and drift

```bash
kubectl scale deployment/ocm-controller-demo --replicas=2
kubectl get deployment/ocm-controller-demo --watch
```

The Deployer reconciles the state defined in the OCM artifact. Then delete the
controller chain:

```bash
kubectl delete -f examples/controller/bootstrap.yaml.tpl
kubectl get deployment/ocm-controller-demo
```

ApplySet lifecycle also removes the managed Deployment.

## Acceptance

All four OCM CRs become Ready, the pod writes logs, and removing the Deployer
graph cleans up the applied Deployment.

The final required step is [Lab 04 – automated OCM delivery](../lab-bootstrap/04-automatischer-release.md).
