# 03 – Alle Ressourcen in die Zielregistry lokalisieren

**Ziel:** Die Registry enthält den Component Descriptor und die vollständige
Laufzeitmenge, bevor ein Ziel-Pod erstellt wird.

Übertrage das CTF in die Zielzone – über eine Schleuse, ein Artefakt-Repository
oder einen kontrollierten Netzwerktransfer. Prüfe vor dem Import mindestens den
Hash und, falls verwendet, die OCM-Signatur.

```bash
component_name=$(yq -r '.component.name' config/application.lock.yaml)
component_version=$(yq -r '.component.version' config/application.lock.yaml)
./scripts/import-self-contained-ctf.sh \
  "$DELIVERY_DIR/transport-archive" "$component_name" \
  "$component_version" "$OCM_REPOSITORY"

ocm get component-version \
  "oci::${OCM_REPOSITORY}//${component_name}:${component_version}" \
  -o yaml > "$DELIVERY_DIR/imported-component.yaml"
```

`--copy-resources` ist entscheidend: Ohne diese Option würde der Descriptor auf
die ursprünglichen Upstream-Registries verweisen. Die `imageReference`-Werte im
importierten Descriptor sind die autoritative Quelle für die nun lokalisierten
Image-Referenzen.

## Abnahme

Alle OCM Resources lassen sich aus `OCM_REPOSITORY` lesen. Die lokalisierte
Image-Referenz jedes Resources kann von einem Node des Zielclusters authentisiert
und per TLS aus der Zielregistry gezogen werden.
