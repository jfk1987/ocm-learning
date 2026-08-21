# OCM 05 – Positive and negative evidence

**Goal:** You prove both a successful local restart and the failure of an
external pull. A green deployment alone is not sufficient.

## What this chapter actually proves

An already running Pod might have obtained its image from the local node
cache. A green status therefore does not prove that the application can be
restarted using only the target registry.

The evidence requires two opposite results:

```text
local, approved image  ── must start again successfully
new public image       ── must fail because Internet access is absent
```

Together, these tests show that the cluster is not simply broken. It is
deliberately isolated from upstream registries while local delivery still
works.

## 1. Check network isolation and the local path separately

```bash
./scripts/set-target-egress.sh status ocm-target
docker exec k3d-ocm-target-server-0 \
  wget -q -T 5 -O- http://k3d-registry.localhost:5000/v2/
```

The first command confirms that the node has no default route. The second runs
`wget` **inside the k3d node container** and requests the Registry V2 endpoint
over the directly connected Docker network.

The `wget` options mean:

| Option | Meaning |
| --- | --- |
| `-q` | suppress progress output |
| `-T 5` | abort after five seconds |
| `-O-` | write the response to stdout instead of a file |

An empty response or `{}` with exit code `0` is successful. Two facts are now
visible at the same time: Internet egress is blocked, while the local registry
is reachable.

## 2. Run the complete runtime test

```bash
./scripts/assert-airgap-runtime.sh k3d-ocm-target localhost:5000
```

The two arguments are the Kubernetes context and the permitted registry
prefix. The script then performs three independent checks.

### Check A: Only local image addresses

The script reads all running Pods as JSON, collects main and init containers,
and checks every `.image` value. A reference outside `localhost:5000/` stops
the test immediately.

The output starts approximately like this:

```text
Local images only:
localhost:5000/...
```

This proves the declared configuration, but not yet a fresh pull.

### Check B: The local restart must succeed

The script performs a `rollout restart` of the web Deployment and waits for
the rollout to succeed. With `imagePullPolicy: Always`, Kubernetes must resolve
the reference through the local registry again instead of relying only on an
already running Pod.

A successful rollout proves that DNS/registry mirror, registry content,
manifest, and Kubernetes startup work together despite blocked egress.

### Check C: The public pull must fail

In a separate namespace, the script creates a new Pod using an uncached image
from `registry.k8s.io`. It waits 45 seconds for `Ready`. If the Pod became
ready, the air-gap assumption would be disproved and the script would exit
with an error.

Instead, expect:

```text
ErrImagePull
```

or:

```text
ImagePullBackOff
```

The Pod events printed afterwards show the failed access. In this negative
test, the red Kubernetes state is the desired result. The final script line
therefore still confirms:

```text
Air-gap check succeeded: local restart works and the upstream pull fails.
```

## 3. Record the digests that actually ran

Kubernetes distinguishes between the requested image reference in `.image`
and the content that actually started in `.imageID`. Read both values:

```bash
kubectl --context k3d-ocm-target -n target-application get pods -o json |
  yq -p=json -r '
    .items[] as $pod |
    (($pod.status.initContainerStatuses // []) +
     ($pod.status.containerStatuses // []))[] |
    [$pod.metadata.name, .name, .image, .imageID] | @tsv
  '
```

The data flows from left to right:

1. `kubectl ... -o json` returns every Pod as JSON.
2. The pipe passes that JSON to `yq`.
3. `-p=json` tells `yq` which input format it reads; `-r` produces raw text.
4. Init and main container status lists are combined.
5. Pod name, container name, declared reference, and `imageID` are printed as
   tab-separated values for every container.

The `imageID` contains the content digest actually started by the runtime. For
real release evidence, store this output together with Component name,
Component Version, CTF hash, and signature verification result.

## 4. Re-enable egress deliberately after the lab

Only if you want to reuse the target cluster for other experiments:

```bash
./scripts/set-target-egress.sh allow ocm-target
./scripts/set-target-egress.sh status ocm-target
```

`allow` restores the default route through the gateway of the k3d Docker
network. The following status should now show a `default via ...` route. Keep
egress blocked for the OCM evidence.

## Checkpoint

The local restart succeeds, the upstream Pod fails, and the list of actually
running `imageID` digests is recorded. You can now explain why neither a green
deployment nor one failed Internet pull alone would be complete air-gap
evidence.

Next: [OCM 06 – Update and rollback](06-update.md).
