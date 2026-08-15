# OCM Learning Lab: from an empty workstation to an air-gapped release

[German README](README.de.md) · [Documentation on GitHub Pages](https://jfk1987.github.io/ocm-learning/)

This repository is a complete, hands-on learning path for the
[Open Component Model](https://ocm.software/). It assumes no prior experience
with OCM, Forgejo, or Woodpecker.

The result is a concrete Nginx/Redis application with a Helm chart, init
container, StatefulSet, migration hook, and test. Source metadata, a source
archive, the chart, values, and all three runtime images are delivered as an
OCM Component Version, signed, transported through a simulated air gap as a
CTF, and installed in a target cluster without Internet egress.

```text
Connected lab                         Air-gap target
┌─────────────────────────────┐       ┌───────────────────────────┐
│ k3d + registry              │  CTF  │ k3d without default route │
│ Forgejo + Woodpecker        ├──────▶│ local registry + Helm     │
│ OCM build + signature       │       │ Nginx + Redis             │
└─────────────────────────────┘       └───────────────────────────┘
```

## The prescribed learning path

Work through the chapters from top to bottom. Each chapter has a small,
verifiable result and an acceptance section.

### Part A – Bootstrap a lightweight lab

| Step | Result |
| --- | --- |
| [Lab 00 – Prerequisites](docs-en/lab-bootstrap/00-voraussetzungen.md) | Docker, k3d, kubectl, Helm, OCM, yq, and Skopeo are ready |
| [Lab 01 – Cluster and registry](docs-en/lab-bootstrap/01-cluster-und-registry.md) | k3d/K3s successfully pulls from the local HTTP registry |
| [Lab 02 – Forgejo](docs-en/lab-bootstrap/02-forgejo.md) | SCM, user, token, and a separate application repository are ready |
| [Lab 03 – Woodpecker](docs-en/lab-bootstrap/03-woodpecker.md) | OAuth, webhook, and the first Kubernetes CI pipeline work |

### Part B – Complete OCM delivery

| Step | OCM aspect covered in practice |
| --- | --- |
| [OCM 00 – Application and model](docs-en/application-path/00-grenzen.md) | Component, version, source, resources, and delivery boundary |
| [OCM 01 – Inventory](docs-en/application-path/01-inventar.md) | Digests, platforms, `extraIdentity`, and lockfile |
| [OCM 02 – Constructor and CTF](docs-en/application-path/02-komponente.md) | Inputs, access, labels, descriptor, and resource selection |
| [OCM 03 – Signing and transport](docs-en/application-path/03-registry-import.md) | RSA signature, verification, CTF package, and transfer hash |
| [OCM 04 – Import and deployment](docs-en/application-path/04-deploy.md) | Recursive transfer, resource localization, and Helm |
| [OCM 05 – Air-gap evidence](docs-en/application-path/05-nachweis.md) | Real network isolation, positive restart, and negative upstream pull |
| [OCM 06 – Update and rollback](docs-en/application-path/06-update.md) | Separate Component Versions and recovery |

### Part C – Advanced labs

| Step | Result |
| --- | --- |
| [OCM 07 – Credentials](docs-en/advanced/07-credentials.md) | Authenticated registry and consumer identity matching |
| [OCM 08 – Component references](docs-en/advanced/08-component-references.md) | Product made of two components and recursive transfer |
| [OCM 09 – Resolver](docs-en/advanced/09-resolvers.md) | Deterministic resolution of distributed components |
| [OCM 10 – Kubernetes controller](docs-en/advanced/10-controller.md) | Repository → Component → Resource → Deployer |

### Part D – Final automation

[Lab 04 – automated OCM release](docs-en/lab-bootstrap/04-automatischer-release.md)
builts a dedicated CI tool image. A Forgejo tag triggers lockfile validation,
constructor generation, CTF materialization, and registry transfer in
Woodpecker.

## Two Git repositories, two responsibilities

`ocm-learning` contains the tutorial, templates, demo, and reusable scripts.
It is **not** checked into Forgejo as the target application. Lab 02 creates
the separate `target-application` repository at
`.lab/workspaces/target-application`; only that repository is released by
Woodpecker. OCM 00 populates it with the concrete application.

## Start

```bash
cp config/lab.env.example config/lab.env
$EDITOR config/lab.env
./scripts/preflight-lab.sh
```

Then start with Lab 00. When OCM or Helm chart versions change, check the
[references](docs-en/references.md) first; versions are intentionally pinned
so that a run remains reproducible.
