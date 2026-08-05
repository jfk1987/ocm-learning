# 04 – Plattform per OCM in Zot importieren

**Ziel:** Charts, Images und OCM-Descriptor befinden sich vollständig in der
lokalen Registry, bevor Forgejo oder Woodpecker installiert werden.

Die Connected Station erstellt aus `platform.lock.yaml`, den beiden lokalen
Chart-Dateien und allen OCI Images eine Component Version. Wie beim
Bootstrap-Modul wird diese zuerst in einen CTF transferiert, diesmal mit
`--copy-resources`; nur das resultierende CTF darf die Offline-Grenze
passieren.

Für beide Komponenten steht derselbe Helfer bereit:

```bash
./scripts/build-self-contained-ctf.sh \
  ocm/developer-platform/component-constructor.yaml \
  dist/developer-platform \
  example.org/platform/developer-platform 0.1.0 \
  dist/developer-platform-transport-archive
```

In der Offline-Zone:

```bash
./scripts/import-self-contained-ctf.sh \
  ./transport-archive example.org/platform/developer-platform 0.1.0 \
  "${OCM_REPOSITORY}"
ocm get component-version "oci::${OCM_REPOSITORY}//example.org/platform/developer-platform:0.1.0" -o yaml > imported-platform.yaml
```

Die `imageReference`-Werte im importierten Descriptor sind die alleinige Quelle
für die späteren Helm Values. Sie werden nicht aus Memory oder mit Tags wie
`latest` rekonstruiert.

## Abnahme

Alle Resources des Component Descriptors sind aus Zot lesbar. Ein Image-Pull
mit der lokalisierten Referenz klappt auf dem K3s-Node, obwohl öffentliche DNS-
Namen nicht erreichbar sind.
