# OCM 05 – Positive and negative evidence

**Goal:** You prove both a successful local restart and the failure of an
external pull. A green deployment alone is not sufficient.

## 1. Check network isolation again

```bash
./scripts/set-target-egress.sh status ocm-target
docker exec k3d-ocm-target-server-0 \
  wget -q -T 5 -O- http://k3d-registry.localhost:5000/v2/
```

The registry responds. `ip route show default` in the node must not print a
route.

## 2. Run the complete runtime test

```bash
./scripts/assert-airgap-runtime.sh k3d-ocm-target localhost:5000
```

The script performs three checks:

1. all init and main containers start with `localhost:5000/`;
2. a rollout restart of the web application succeeds with
   `imagePullPolicy: Always` from the local registry rather than only from the
   node cache;
3. a new, uncached image from `registry.k8s.io` deliberately does **not** reach
   `Ready` within 45 seconds.

The expected state of the negative pod is `ErrImagePull` or
`ImagePullBackOff`. Its events are printed as evidence.

## 3. Record the digests that actually ran

Kubernetes shows the content digest that actually started in `imageID`:

```bash
kubectl --context k3d-ocm-target -n target-application get pods -o json |
  yq -p=json -r '
    .items[] as $pod |
    (($pod.status.initContainerStatuses // []) +
     ($pod.status.containerStatuses // []))[] |
    [$pod.metadata.name, .name, .image, .imageID] | @tsv
  '
```

Store this output together with the Component name, version, CTF hash, and
signature verification in the release evidence for your real environment.

## 4. Allow egress again deliberately after the lab

Only if you want to reuse the target cluster for other experiments:

```bash
./scripts/set-target-egress.sh allow ocm-target
./scripts/set-target-egress.sh status ocm-target
```

For the OCM evidence, keep egress blocked.

## Acceptance

The local restart succeeds, the upstream pod fails, and the list of `imageID`
digests is documented.

Next: [OCM 06 – Update and rollback](06-update.md).
