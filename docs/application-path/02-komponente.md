# 02 – OCM-Komponente und selbstständiges CTF bauen

**Ziel:** Die Anwendung und alle Laufzeitressourcen reisen als eine überprüfbare
Komponentenversion.

Lege Chart und Values mit den im Lockfile angegebenen Dateinamen in
`$DELIVERY_DIR` ab. Das Lockfile enthält für jedes Image `name`, `version` und
`imageReference` inklusive Digest. Der Constructor wird daraus generiert –
nicht manuell gepflegt:

```bash
component_name=$(yq -r '.component.name' config/application.lock.yaml)
component_version=$(yq -r '.component.version' config/application.lock.yaml)
./scripts/generate-component-constructor.sh \
  config/application.lock.yaml "$DELIVERY_DIR" \
  "$DELIVERY_DIR/component-constructor.yaml"
./scripts/build-self-contained-ctf.sh \
  "$DELIVERY_DIR/component-constructor.yaml" "$DELIVERY_DIR" \
  "$component_name" "$component_version" \
  "$DELIVERY_DIR/transport-archive"
```

Das Script erstellt zunächst einen Descriptor und transferiert ihn anschließend
mit `--copy-resources` in ein finales CTF. In diesem zweiten Schritt lädt OCM
alle gelockten OCI-Images herunter und legt sie als lokale Ressourcen ab. Nur
das finale CTF darf die Luftspalte passieren.

Optional wird die Component Version jetzt mit einem organisationsweiten
Schlüssel signiert. Öffentlicher Schlüssel, Signatur und CTF müssen gemeinsam
in die Zielzone gelangen.

## Abnahme

`ocm get component-version ctf::<ctf>//<name>:<version>` zeigt Chart, Values
und jedes gelockte Image. Das CTF kann ohne Zugriff auf Upstream-Registries
weitergegeben werden.
