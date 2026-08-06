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
- [OCM: How OCM Works](https://ocm.software/docs/overview/how-ocm-works/) –
  Komponente, Packaging, Signierung und CTF für Offline-Transfers.
- [OCM: Create Component Versions](https://ocm.software/docs/getting-started/create-component-versions/) –
  `component-constructor.yaml`, CTF und `ocm add component-version`.
- [OCM: Transfer and Transport](https://ocm.software/docs/concepts/transfer-and-transport/) –
  Verhalten von `--copy-resources` und Lokalisierung.
- [OCM CLI: transfer component-version](https://ocm.software/docs/reference/ocm-cli/ocm-transfer-component-version/) –
  aktuelle Transfer-Optionen.
- [JFrog Artifactory OSS Helm Chart](https://artifacthub.io/packages/helm/jfrog/artifactory-oss) –
  Chart, optionale PostgreSQL- und Nginx-Komponenten sowie enthaltene Images.
- [JFrog Docker-Installation](https://docs.jfrog.com/installation/docs/docker) –
  offizieller Image-Pfad `releases-docker.jfrog.io/jfrog/artifactory-oss`.
