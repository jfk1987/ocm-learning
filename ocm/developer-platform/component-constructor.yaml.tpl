# In Schritt 01 wird die Marker-Liste durch jede gelockte Image-Resource ersetzt.
# Alle referenzierten Images werden auf der Connected Station mit
# `ocm transfer ... --copy-resources` in das finale CTF materialisiert.
components:
  - name: example.org/platform/developer-platform
    version: REPLACE_WITH_COMPONENT_VERSION
    provider:
      name: example.org
    resources:
      - name: forgejo-chart
        type: helmChart
        version: REPLACE_WITH_FORGEJO_CHART_VERSION
        input:
          type: File/v1
          path: ./forgejo-chart.tgz
      - name: woodpecker-chart
        type: helmChart
        version: REPLACE_WITH_WOODPECKER_CHART_VERSION
        input:
          type: File/v1
          path: ./woodpecker-chart.tgz
      - name: forgejo-values-template
        type: blob
        input:
          type: File/v1
          path: ./forgejo-values.yaml.tpl
      - name: woodpecker-values-template
        type: blob
        input:
          type: File/v1
          path: ./woodpecker-values.yaml.tpl
      - name: local-only-pipeline-template
        type: blob
        input:
          type: File/v1
          path: ./local-only.yaml
      # IMAGE_RESOURCES_FROM_platform.lock.yaml
