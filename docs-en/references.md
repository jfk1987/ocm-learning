# References

- [k3d: local registries](https://k3d.io/stable/usage/registries/) – host and
  cluster addresses, `registries.yaml`, and a complete push/pull test.
- [K3s: custom CoreDNS configuration](https://docs.k3s.io/advanced#coredns-custom-configuration-imports) –
  `coredns-custom` and `*.override` for shared lab hostnames.
- [K3s: air-gap install](https://docs.k3s.io/installation/airgap) – official
  K3s binaries, air-gap image archives, and the installation process.
- [Zot: configuration](https://zotregistry.dev/v2.1.3/admin-guide/admin-configuration/) –
  local storage, TLS, registry compatibility, and config validation.
- [Zot: authentication and authorization](https://zotregistry.dev/v2.1.3/articles/authn-authz/) –
  TLS, bcrypt-htpasswd, and registry policies.
- [Forgejo Helm chart](https://artifacthub.io/packages/helm/forgejo-helm/forgejo) –
  official OCI chart, admin secret, persistence, and ingress values.
- [Forgejo: recommendations](https://forgejo.org/docs/latest/admin/setup/recommendations/) –
  SQLite for small to medium-sized instances.
- [Woodpecker: Kubernetes backend](https://woodpecker-ci.org/docs/administration/configuration/backends/kubernetes) –
  pipeline steps as pods and pull secrets.
- [Woodpecker: Forgejo integration](https://woodpecker-ci.org/docs/administration/configuration/forges/forgejo) –
  OAuth and webhook configuration.
- [Woodpecker: workflow syntax](https://woodpecker-ci.org/docs/usage/workflow-syntax) –
  `when`, steps, images, commands, and execution order.
- [Woodpecker: environment variables](https://woodpecker-ci.org/docs/usage/environment) –
  including `CI_COMMIT_TAG` for tag-based releases.
- [Woodpecker: secrets](https://woodpecker-ci.org/docs/usage/secrets) –
  repository secrets and their use with `from_secret`.
- [OCM: how OCM works](https://ocm.software/docs/overview/how-ocm-works/) –
  components, packaging, signing, and CTFs for offline transfers.
- [OCM: component identity](https://ocm.software/docs/concepts/component-identity/) –
  names, versions, resources, sources, references, labels, and `extraIdentity`.
- [OCM: create component versions](https://ocm.software/docs/getting-started/create-component-versions/) –
  `component-constructor.yaml`, CTF, and `ocm add component-version`.
- [OCM: input and access types](https://ocm.software/docs/reference/input-and-access-types/) –
  `File/v1`, `Dir/v1`, `Helm/v1`, `OCIImage/v1`, and resulting accesses.
- [OCM: transfer and transport](https://ocm.software/docs/concepts/transfer-and-transport/) –
  behavior of `--copy-resources` and localization.
- [OCM: transfer across an air gap](https://ocm.software/docs/how-to/transfer-components-across-an-air-gap/) –
  CTF as physical zone transport and import into an OCI repository.
- [OCM CLI: transfer component-version](https://ocm.software/docs/reference/ocm-cli/ocm-transfer-component-version/) –
  current transfer options.
- [OCM: working with OCI](https://ocm.software/docs/tutorials/working-with-oci/) –
  OCI registry as a target and `http://` for local registries without TLS.
- [OCM: plain signatures](https://ocm.software/docs/tutorials/signing/plain-signatures/) –
  RSA keys, signing config, `ocm sign`, and `ocm verify`.
- [OCM: credential resolution](https://ocm.software/docs/tutorials/understand-credential-resolution/) –
  consumer identities, path patterns, and schema/port matching.
- [OCM: multi-component product](https://ocm.software/docs/tutorials/create-a-multi-component-product/) –
  Component References and recursive product delivery.
- [OCM: resolver configuration](https://ocm.software/docs/reference/resolver-configuration/) –
  deterministic repositories by name and version.
- [OCM: Kubernetes controllers](https://ocm.software/docs/concepts/kubernetes-controllers/) –
  repository, component, resource, and deployer reconciliation.
- [OCM: deploy manifests with Deployer](https://ocm.software/docs/how-to/deploy-manifests-with-deployer/) –
  raw manifests without kro/Flux and ApplySet lifecycle.
