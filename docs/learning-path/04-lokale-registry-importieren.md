# 04 – In die lokale Registry importieren

**Ziel:** Der Component Descriptor und alle referenzierten Ressourcen befinden
sich in der einzigen vom Cluster erreichbaren OCI Registry.

Lege die entpackte Lieferung als `dist/transport-archive` neben das Projekt und
führe in der Offline-Zone aus:

```bash
./scripts/import-ctf.sh
```

Entscheidend sind `--copy-resources` und `--upload-as ociArtifact`: Ohne
`--copy-resources` würde nur der Descriptor importiert und die Images blieben
in der öffentlichen Connected-Registry.

Sichere den importierten Descriptor für den folgenden Schritt:

```bash
ocm get component-version \
  "oci::${OCM_REPOSITORY}//${COMPONENT_NAME}:${COMPONENT_VERSION}" \
  -o yaml > dist/imported-component.yaml
```

## Abnahme

Der Descriptor ist aus `OCM_REPOSITORY` lesbar und jede Image-Resource zeigt
auf die lokale Registry. Kein Zugriff auf `releases-docker.jfrog.io` darf für
den Import oder späteren Pod-Start notwendig sein.
