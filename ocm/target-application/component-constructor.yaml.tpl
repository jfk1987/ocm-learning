# In dist/target-application/ kopieren, Platzhalter aus application.lock.yaml
# ersetzen und pro Image eine Resource ergänzen.
components:
  - name: example.org/team/target-application
    version: REPLACE_WITH_COMPONENT_VERSION
    provider:
      name: example.org
    resources:
      - name: helm-chart
        type: helmChart
        version: REPLACE_WITH_CHART_VERSION
        input:
          type: File/v1
          path: ./target-application-chart.tgz
      - name: deployment-values
        type: blob
        input:
          type: File/v1
          path: ./values-airgap.yaml
      # Zusätzliche Dateien, etwa CRDs oder Migrations-Manifeste:
      # - name: migration-manifests
      #   type: blob
      #   input:
      #     type: Dir/v1
      #     path: ./manifests
      # Für JEDES Element in application.lock.yaml/images ergänzen:
      # - name: service-api
      #   type: ociImage
      #   version: 1.2.3
      #   access:
      #     type: OCIImage/v1
      #     imageReference: registry.upstream.example/team/api:1.2.3@sha256:...
