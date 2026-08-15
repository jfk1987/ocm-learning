# Lab 01 – k3d cluster and local registry

**Goal:** A small K3s cluster and a local OCI registry are running. An image
pushed from the host can then be pulled by the cluster under exactly the same
reference, `localhost:5000/...`.

## Why the additional registry configuration is required

From the development workstation's perspective, `localhost` means the
workstation itself; from a K3s node's perspective, it means the respective node
container. Therefore two network addresses apply:

| Perspective | Actual registry endpoint |
| --- | --- |
| Host: Docker, OCM, Skopeo | `http://localhost:5000` |
| k3d/K3s container | `http://k3d-registry.localhost:5000` |

Kubernetes manifests should not know these infrastructure details. The file
`config/lab/k3d-registries.yaml` therefore makes containerd mirror
`localhost:5000` internally to the second HTTP endpoint. The lab deliberately
has no TLS. This configuration is not suitable for a production registry.

## 1. Check the starting state

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

The three fallback assignments also make an older `config/lab.env` usable.
Compare it with `config/lab.env.example` afterwards so the new values are
present permanently.

Ports `5000` and `8080` must be free. If an older lab exists from the previous
instructions, note that the containerd mirror configuration is added only when
the cluster is created. An existing cluster does not receive it through a later
Helm or kubectl command.

If the old lab has no data worth keeping, it can be deliberately rebuilt:

```bash
k3d cluster delete ocm-lab
k3d registry delete ocm-registry || true
k3d registry delete registry.localhost || true
```

These commands delete cluster data and registry contents. Skip them if you need
to keep data.

## 2. Create the HTTP registry

```bash
k3d registry create registry.localhost --port 127.0.0.1:5000
k3d registry list
docker ps --filter name=k3d-registry.localhost
curl --fail --show-error http://localhost:5000/v2/
```

The last command returns `{}` or an empty successful response with HTTP 200.
This is the minimal Registry V2 health check.

Important: Docker tags contain neither `http://` nor `https://`, only
`localhost:5000/path/image:tag`.

## 3. Create the cluster with a registry mirror

```bash
k3d cluster create "$LAB_CLUSTER" \
  --servers 1 \
  --agents 1 \
  --registry-use "$LAB_REGISTRY_CONTAINER" \
  --registry-config config/lab/k3d-registries.yaml \
  --port "${LAB_INGRESS_PORT}:80@loadbalancer" \
  --wait
```

Afterwards, use only the newly created context:

```bash
kubectl config use-context "k3d-${LAB_CLUSTER}"
kubectl cluster-info
kubectl get nodes -o wide
kubectl wait --for=condition=Ready node --all --timeout=120s
```

Inspect the installed mirror file in the server node:

```bash
docker exec "k3d-${LAB_CLUSTER}-server-0" \
  cat /etc/rancher/k3s/registries.yaml
```

It must contain a mirror for `localhost:5000` and the HTTP endpoint
`k3d-registry.localhost:5000`.

## 4. Configure shared platform hostnames

Forgejo and Woodpecker will use OAuth redirects later. Their URLs must therefore
be reachable both from the host browser and from pods. Add this once on the
host:

```text
127.0.0.1 forgejo.ocm.test woodpecker.ocm.test
```

On macOS/Linux, put the line in `/etc/hosts`; on Windows, in
`C:\Windows\System32\drivers\etc\hosts`. The project then configures the
same names in K3s CoreDNS:

```bash
./scripts/configure-lab-hostnames.sh
kubectl -n kube-system get service,endpoints lab-ingress
```

The additional `lab-ingress` Service makes Traefik reachable at port `8080`
inside the cluster. Thus `http://forgejo.ocm.test:8080` is the same URL inside
and outside.

The script creates the `ocm.test` zone as a dedicated CoreDNS server block in
`lab.server`. It deliberately does not use `lab.override`: the K3s default
server block already contains a `hosts` plugin, and CoreDNS allows this plugin
only once per server block.

Test DNS resolution inside the cluster:

```bash
kubectl delete pod lab-dns-test --ignore-not-found
kubectl run lab-dns-test \
  --image=busybox:1.36 \
  --restart=Never --command -- \
  nslookup forgejo.ocm.test
kubectl logs lab-dns-test
kubectl delete pod lab-dns-test
```

If an older version of the script already created `lab.override` and CoreDNS
fails with `plugin/hosts: this plugin can only be used once per Server Block`,
run the script again to repair the ConfigMap and restart CoreDNS:

```bash
./scripts/configure-lab-hostnames.sh
kubectl -n kube-system get configmap coredns-custom -o yaml
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
kubectl -n kube-system logs deployment/coredns --tail=50
```

Under `data`, only `lab.server`, not `lab.override`, may remain for the lab.

## 5. Verify a push from the host

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

The push must end successfully with a digest line. The catalog must contain
`lab/alpine`, and the tag list must contain `3.21`. This completes the path
`Docker on the host -> registry`. Optionally, Skopeo confirms the same content
without TLS:

```bash
skopeo list-tags --tls-verify=false \
  docker://localhost:5000/lab/alpine
```

## 6. Verify a pull in the cluster

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

The emitted image reference remains `localhost:5000/...`; only the runtime
mirror knows the internal address. Remove the test pod after a successful test:

```bash
kubectl delete pod registry-test
```

## Troubleshooting: Docker expects HTTPS

Typical message:

```text
server gave HTTP response to HTTPS client
```

Check in this order:

1. Does the push use exactly `localhost:5000/...`? The former name
   `k3d-ocm-registry.localhost:5000` is not classified as a loopback/insecure
   registry on some hosts and must no longer be used.
2. Does `curl http://localhost:5000/v2/` respond? If not, check
   `docker logs k3d-registry.localhost` and port allocation.
3. Does the image name accidentally contain `https://`? Schemes are invalid in
   OCI image references.
4. If your Docker installation enforces TLS even for loopback, add only
   `localhost:5000` to Docker Engine's `insecure-registries` for this isolated
   lab and restart Docker:

   ```json
   {
     "insecure-registries": ["localhost:5000"]
   }
   ```

   Do this only if the first three checks do not explain the error. Real
   environments use a registry with TLS and a trusted CA.

## Troubleshooting: `ImagePullBackOff`

```bash
kubectl describe pod registry-test
kubectl get events --sort-by=.lastTimestamp
docker logs k3d-registry.localhost
docker exec "k3d-${LAB_CLUSTER}-server-0" \
  cat /etc/rancher/k3s/registries.yaml
```

If the events show access to `https://localhost:5000`, the cluster was created
without `--registry-config` or the mirror file is wrong. Since K3s receives
this configuration at bootstrap, recreate the lab cluster with step 3.

## Troubleshooting: the tags URL returns `404`

An HTTP `404` for `/v2/lab/alpine/tags/list` normally means the registry is
reachable but has no repository named `lab/alpine`. First show the error
without `--fail` and query the registry catalog:

```bash
curl --show-error http://localhost:5000/v2/lab/alpine/tags/list
curl --fail --show-error http://localhost:5000/v2/_catalog
```

An answer with `NAME_UNKNOWN` confirms the missing repository name. If the
catalog is empty or contains an old path such as `test/alpine`, repeat the tag
and push with the current reference and check the exit code:

```bash
docker image inspect public.ecr.aws/docker/library/alpine:3.21 >/dev/null
docker tag public.ecr.aws/docker/library/alpine:3.21 \
  localhost:5000/lab/alpine:3.21
docker push localhost:5000/lab/alpine:3.21
echo "$?"
```

Only exit code `0` confirms a successful push. If the catalog is still empty,
compare port mapping and registry logs:

```bash
docker ps --filter name=k3d-registry.localhost \
  --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'
docker logs k3d-registry.localhost --tail=100
```

The container must publish host port `127.0.0.1:5000`. Another container or a
different mapping means that push and curl are talking to different registries.

## Acceptance

- `curl http://localhost:5000/v2/lab/alpine/tags/list` contains `3.21`.
- `kubectl wait ... pod/registry-test` succeeded.
- The pod uses `localhost:5000/lab/alpine:3.21` in its manifest.
- Host and cluster can resolve `forgejo.ocm.test`.

The registry is now ready both for later OCM transfers from the host and for
Kubernetes pulls. Continue with [Lab 02 – Forgejo](02-forgejo.md).
