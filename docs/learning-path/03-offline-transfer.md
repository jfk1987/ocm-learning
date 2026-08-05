# 03 – Offline-Transfer

**Ziel:** Das Lieferpaket erreicht die Offline-Zone unverändert.

Übertrage ausschließlich diese beiden Dateien:

```text
dist/<COMPONENT_VERSION>-transport-archive.tgz
dist/<COMPONENT_VERSION>-transport-archive.tgz.sha256
```

Auf der Offline-Station:

```bash
sha256sum --check <COMPONENT_VERSION>-transport-archive.tgz.sha256
tar -xzf <COMPONENT_VERSION>-transport-archive.tgz
```

Auf macOS lautet der Hash-Befehl `shasum -a 256 <COMPONENT_VERSION>-transport-archive.tgz`;
der ausgegebene Digest muss mit der `.sha256`-Datei übereinstimmen.

Wenn eine Signatur verwendet wird, erfolgt ihre OCM-Verifikation jetzt und vor
jedem Import. Ein abweichender Hash oder eine ungültige Signatur beendet den
Prozess; das Paket wird nicht „trotzdem“ importiert.

## Abnahme

Der Hash-Check meldet `OK`, und das entpackte Verzeichnis
`transport-archive/` ist vorhanden.
