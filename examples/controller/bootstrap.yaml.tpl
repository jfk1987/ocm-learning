apiVersion: delivery.ocm.software/v1alpha1
kind: Repository
metadata:
  name: controller-demo-repository
spec:
  repositorySpec:
    baseUrl: http://k3d-registry.localhost:5000/ocm
    type: OCIRegistry
  interval: 1m
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Component
metadata:
  name: controller-demo-component
spec:
  component: example.org/ocm-learning/controller-demo
  repositoryRef:
    name: controller-demo-repository
  semver: 1.0.0
  interval: 1m
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Resource
metadata:
  name: controller-demo-manifest
spec:
  componentRef:
    name: controller-demo-component
  resource:
    byReference:
      resource:
        name: deployment-resource
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Deployer
metadata:
  name: controller-demo-deployer
spec:
  resourceRef:
    name: controller-demo-manifest
    namespace: default
