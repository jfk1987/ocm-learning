# Referenzen

- [k3d: lokale Registries](https://k3d.io/stable/usage/registries/) –
  Host-/Cluster-Adressen, `registries.yaml` und vollständiger Push-/Pull-Test.
- [K3s: eigene CoreDNS-Konfiguration](https://docs.k3s.io/advanced#coredns-custom-configuration-imports) –
  `coredns-custom` und `*.override` für die gemeinsamen Lab-Hostnamen.
- [K3s: Air-Gap Install](https://docs.k3s.io/installation/airgap) – offizielle
  K3s-Binaries, Airgap-Image-Archive und der Installationsablauf.
- [Zot: Konfiguration](https://zotregistry.dev/v2.1.3/admin-guide/admin-configuration/) –
  lokale Speicherung, TLS, Registry-Kompatibilität und Config-Prüfung.
- [Zot: Authentication and Authorization](https://zotregistry.dev/v2.1.3/articles/authn-authz/) –
  TLS, bcrypt-htpasswd und Registry-Policies.
- [Forgejo Helm Chart](https://artifacthub.io/packages/helm/forgejo-helm/forgejo) –
  offizieller OCI-Chart, Admin-Secret, Persistence und Ingress-Values.
- [Forgejo: Empfehlungen](https://forgejo.org/docs/latest/admin/setup/recommendations/) –
  SQLite für kleine bis mittlere Instanzen.
- [Woodpecker: Kubernetes Backend](https://woodpecker-ci.org/docs/administration/configuration/backends/kubernetes) –
  Ausführung von Pipeline-Schritten als Pods und Pull Secrets.
- [Woodpecker: Forgejo-Anbindung](https://woodpecker-ci.org/docs/administration/configuration/forges/forgejo) –
  OAuth- und Webhook-Konfiguration.
- [Woodpecker: Workflow-Syntax](https://woodpecker-ci.org/docs/usage/workflow-syntax) –
  `when`, Schritte, Images, Commands und Ausführungsreihenfolge.
- [Woodpecker: Umgebungsvariablen](https://woodpecker-ci.org/docs/usage/environment) –
  unter anderem `CI_COMMIT_TAG` für tag-basierte Releases.
- [Woodpecker: Secrets](https://woodpecker-ci.org/docs/usage/secrets) –
  Repository-Secrets und die Einbindung mit `from_secret`.
- [OCM: How OCM Works](https://ocm.software/docs/overview/how-ocm-works/) –
  Komponente, Packaging, Signierung und CTF für Offline-Transfers.
- [OCM: Component Identity](https://ocm.software/docs/concepts/component-identity/) –
  Namen, Versionen, Resources, Sources, References, Labels und `extraIdentity`.
- [OCM: Create Component Versions](https://ocm.software/docs/getting-started/create-component-versions/) –
  `component-constructor.yaml`, CTF und `ocm add component-version`.
- [OCM: Input and Access Types](https://ocm.software/docs/reference/input-and-access-types/) –
  `File/v1`, `Dir/v1`, `Helm/v1`, `OCIImage/v1` und resultierende Zugriffe.
- [OCM: Transfer and Transport](https://ocm.software/docs/concepts/transfer-and-transport/) –
  Verhalten von `--copy-resources` und Lokalisierung.
- [OCM: Transfer across an Air Gap](https://ocm.software/docs/how-to/transfer-components-across-an-air-gap/) –
  CTF als physischer Zonentransport und Import in ein OCI Repository.
- [OCM CLI: transfer component-version](https://ocm.software/docs/reference/ocm-cli/ocm-transfer-component-version/) –
  aktuelle Transfer-Optionen.
- [OCM: OCI verwenden](https://ocm.software/docs/tutorials/working-with-oci/) –
  OCI Registry als Ziel und `http://` für lokale Registries ohne TLS.
- [OCM: Plain Signatures](https://ocm.software/docs/tutorials/signing/plain-signatures/) –
  RSA-Schlüssel, Signing-Config, `ocm sign` und `ocm verify`.
- [OCM: Credential Resolution](https://ocm.software/docs/tutorials/understand-credential-resolution/) –
  Consumer Identities, Pfad-Patterns sowie Schema-/Port-Matching.
- [OCM: Multi-Component Product](https://ocm.software/docs/tutorials/create-a-multi-component-product/) –
  Component References und rekursive Produktlieferung.
- [OCM: Resolver Configuration](https://ocm.software/docs/reference/resolver-configuration/) –
  deterministische Repositories nach Name und Version.
- [OCM: Kubernetes Controllers](https://ocm.software/docs/concepts/kubernetes-controllers/) –
  Repository-, Component-, Resource- und Deployer-Reconciliation.
- [OCM: Deploy Manifests with Deployer](https://ocm.software/docs/how-to/deploy-manifests-with-deployer/) –
  Raw-Manifeste ohne kro/Flux sowie ApplySet-Lifecycle.
