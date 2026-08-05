# In Schritt 01 wird diese Vorlage mit den gelockten Dateinamen, Versionen und
# Digests gefüllt. Die Dateien liegen relativ zu diesem Constructor in dist/bootstrap/.
components:
  - name: example.org/platform/bootstrap
    version: REPLACE_WITH_COMPONENT_VERSION
    provider:
      name: example.org
    resources:
      - name: k3s-binary
        type: blob
        version: REPLACE_WITH_K3S_VERSION
        input:
          type: File/v1
          path: ./k3s
      - name: k3s-airgap-images
        type: blob
        version: REPLACE_WITH_K3S_VERSION
        input:
          type: File/v1
          path: ./k3s-airgap-images-amd64.tar.zst
      - name: k3s-install-script
        type: blob
        version: REPLACE_WITH_K3S_VERSION
        input:
          type: File/v1
          path: ./install.sh
      - name: zot-binary
        type: blob
        version: REPLACE_WITH_ZOT_VERSION
        input:
          type: File/v1
          path: ./zot-linux-amd64
      - name: zot-config-template
        type: blob
        input:
          type: File/v1
          path: ./zot-config.json.tpl
      - name: zot-systemd-unit-template
        type: blob
        input:
          type: File/v1
          path: ./zot.service.tpl
      - name: k3s-registries-template
        type: blob
        input:
          type: File/v1
          path: ./k3s-registries.yaml.tpl
