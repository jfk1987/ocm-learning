# Architecture and trust boundaries

## Three environments with clear responsibilities

```text
┌───────────── Connected Station / Lab ─────────────┐
│ Forgejo → Woodpecker → Constructor → CTF       │
│                 Source + Chart + Values + Images │
│                              ↓ sign              │
└──────────────────────────────┬──────────────────┘
                               │ CTF.tgz + SHA-256
                               │ + signature/public key
                         controlled transfer
                               │
┌──────────────────────────────▼──────────────────┐
│ Target: hash/signature → OCM import → registry │
│                                      ↓             │
│ k3d node without default route ← Helm + local values │
└─────────────────────────────────────────────────┘
```

The bootstrap lab may pull external images and charts. The air-gap property
applies to the target application in the separate target cluster. Its default
route is removed only after K3s itself is ready.

## Responsibilities

| Tool | Responsibility |
| --- | --- |
| Lockfile | Human-reviewed release contract with versions and digests |
| OCM | Identity, provenance, digests, signatures, transfer, and localization |
| CTF | Portable transport of descriptors and materialized resources |
| OCI registry | Durable target access for OCM and the container runtime |
| Helm | Render and apply the application extracted from OCM |
| Kubernetes | Run the exclusively local images |

`--copy-resources` and `--recursive` are orthogonal: the first option copies
the resource contents of a version; the second follows Component References to
additional versions.

## Controller boundary

The core path needs no in-cluster controller. This avoids a bootstrap cycle:
controllers, CRDs, and their images would otherwise also have to be available
offline before the first deployment. OCM 10 therefore presents the controller
as a separate, Internet-connected advanced lab. For a production air-gapped
GitOps system, package its chart, CRDs, and images afterwards using the same
OCM pattern.
