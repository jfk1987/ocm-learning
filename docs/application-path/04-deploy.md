# 04 – Zielanwendung ohne Internet deployen

**Ziel:** Helm arbeitet ausschließlich mit aus OCM extrahierten Artefakten und
der gerenderte Workload enthält nur lokale Image-Referenzen.

Extrahiere Chart und Values aus der importierten Komponente:

```bash
component_name=$(yq -r '.component.name' config/application.lock.yaml)
component_version=$(yq -r '.component.version' config/application.lock.yaml)
mkdir -p "$DELIVERY_DIR/deploy"
ocm download resource \
  "oci::${OCM_REPOSITORY}//${component_name}:${component_version}" \
  --identity name=helm-chart \
  --output "$DELIVERY_DIR/deploy/chart.tgz" --extraction-policy disable
ocm download resource \
  "oci::${OCM_REPOSITORY}//${component_name}:${component_version}" \
  --identity name=deployment-values \
  --output "$DELIVERY_DIR/deploy/values-airgap.yaml" --extraction-policy disable
```

Ersetze in einer *lokalen* Arbeitskopie der Values alle Image-Repository- und
Tag-Werte durch die passenden lokalisierten Referenzen aus
`imported-component.yaml`. Secrets werden als Kubernetes Secrets oder über das
vorhandene Secret Management bereitgestellt, niemals im CTF.

Vor dem Installieren:

```bash
./scripts/render-local-chart.sh target-application "$DELIVERY_DIR/deploy/chart.tgz" \
  target-application "$DELIVERY_DIR/deploy/values-airgap.yaml" "$LOCAL_REGISTRY"
helm upgrade --install target-application "$DELIVERY_DIR/deploy/chart.tgz" \
  --namespace target-application --create-namespace \
  --values "$DELIVERY_DIR/deploy/values-airgap.yaml" --wait --timeout 15m
```

## Abnahme

`helm status` ist erfolgreich. Alle Ziel-Pods starten, obwohl der Zielnamespace
und seine Nodes keinen Internet-Egress haben.
