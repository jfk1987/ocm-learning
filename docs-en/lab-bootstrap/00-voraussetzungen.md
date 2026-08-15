# Lab 00 – Prerequisites

**Goal:** The workstation can build the Internet-connected preparation lab. At
the end of this step, all tools are installed, Docker is running, and the
shared lab variables are loaded.

During Part A, the platform services may download images and charts from the
Internet. Only the target application delivered in Part B is installed without
external registry access.

## 1. Provide resources

The lab targets macOS or Linux. On macOS, give Docker Desktop at least 4 CPUs,
8 GiB of RAM, and roughly 25 GiB of free disk space. Forgejo alone needs less;
Woodpecker and parallel CI steps need the extra headroom later.

On Linux, the current user must be able to use Docker without `sudo`. This test
must succeed:

```bash
docker run --rm public.ecr.aws/docker/library/hello-world:latest
```

## 2. Install command-line tools

Required:

| Tool | Role in the learning path |
| --- | --- |
| Docker | Container runtime for k3d and local image operations |
| k3d | Lightweight K3s cluster in Docker |
| kubectl | Access to Kubernetes |
| Helm | Installation of Forgejo and Woodpecker |
| OCM CLI | Create and transfer OCM components |
| yq | Validate and generate YAML |
| skopeo | Inspect and copy OCI images |

On macOS, install the general tools with Homebrew:

```bash
brew install k3d kubectl helm yq skopeo
```

Install the OCM CLI with the installer published by the OCM project for macOS
and Linux. By default, it places the binary under `~/.local/bin`:

```bash
curl -sfL https://ocm.software/install-cli.sh | bash
export PATH="${HOME}/.local/bin:${PATH}"
ocm version
```

The official installer checks integrity and, when an authenticated GitHub CLI
is available, can also check build attestation. On Linux, use each project's
installation instructions for the remaining tools. Do not install an
unverified binary as `root`.

## 3. Create project variables

From this repository's root directory:

```bash
cp config/lab.env.example config/lab.env
. config/lab.env
```

`config/lab.env` is not checked in. In the first labs, the registry address is
deliberately `localhost:5000`. Lab 01 gives Kubernetes a mirror configuration
that resolves exactly this address correctly inside the cluster.

## 4. Verify the installation

```bash
./scripts/preflight-lab.sh
docker version
k3d version
kubectl version --client
helm version
ocm version
yq --version
skopeo --version
```

Keep the output if you run into problems. The learning path pins artifact
versions later; local tool versions may be newer, but should not change during
one run.

## Acceptance

- `./scripts/preflight-lab.sh` ends with `Lab-Voraussetzungen erfüllt.`.
- `docker run --rm public.ecr.aws/docker/library/hello-world:latest` works
  without `sudo`.
- `echo "$LOCAL_REGISTRY"` prints `localhost:5000`.

Only then continue with [Lab 01 – Cluster and registry](01-cluster-und-registry.md).
