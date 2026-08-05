# 01 – Connected Station und Lieferinventar

**Ziel:** Jede herunterzuladende Datei und jedes Image ist vor dem Transfer
explizit bekannt und durch einen Digest festgelegt.

## 1. Werkzeuge und Projektwerte

```bash
cp config/lab.env.example config/lab.env
$EDITOR config/lab.env
./scripts/preflight.sh
```

Zusätzlich werden auf der Connected Station `cosign` oder ein vergleichbares
Signaturwerkzeug und ein HTTP-Download-Werkzeug benötigt. Die OCM CLI erzeugt
und transferiert später die Component Versions.

## 2. Bootstrap locken

Lade für eine *identische* K3s-Version herunter:

- `k3s` Binary,
- `k3s-airgap-images-<arch>.tar.zst`,
- K3s `install.sh` und
- das Zot-Binary für die Zielarchitektur.

Vergleiche die Hersteller-Checksummen, ermittle zusätzlich selbst `sha256sum`
und fülle damit `config/platform.lock.yaml`. Eine Änderung an einer Datei oder
Version erzeugt eine neue Komponentenversion.

## 3. Platform-Images inventarisieren

Ziehe die festgelegten Forgejo- und Woodpecker-Charts und rendere beide mit
`helm template`. Extrahiere jedes `image:`-Feld. Auch Images aus Chart-
Abhängigkeiten, Init-Containern und Hooks gehören in `images` des
Platform-Lockfiles. Für jede Zielarchitektur wird der Digest eingetragen.

```bash
helm template forgejo <lokales-forgejo-chart.tgz> > dist/forgejo.yaml
helm template woodpecker <lokales-woodpecker-chart.tgz> > dist/woodpecker.yaml
yq -r '.. | select(type == "!!map" and has("image")) | .image | select(type == "!!str")' dist/*.yaml | sort -u
```

## Abnahme

`platform.lock.yaml` enthält keine `TBD`-Werte, alle Chart- und Image-Digests
sind dokumentiert, und die gerenderten Image-Listen sind vollständig im
Lockfile wiederzufinden.

Danach werden die geprüften lokalen Charts und die beiden Values-Vorlagen aus
`ocm/developer-platform/` nach `dist/developer-platform/` kopiert. Ersetze erst
in dieser Arbeitskopie die versionierten Platzhalter; die Originalvorlagen
bleiben als Lernreferenz unverändert.

Für die Bootstrap-Komponente werden entsprechend `zot-config.json.tpl`,
`zot.service.tpl` und `k3s-registries.yaml.tpl` zusammen mit den vier
Bootstrap-Dateien nach `dist/bootstrap/` kopiert. Damit sind selbst die
Konfigurationsvorlagen Teil der OCM-Lieferung.

Erstelle aus der Bootstrap-Vorlage in diesem Arbeitsverzeichnis einen
`component-constructor.yaml` ohne Platzhalter. Dann baue das erste CTF:

```bash
./scripts/build-self-contained-ctf.sh \
  dist/bootstrap/component-constructor.yaml dist/bootstrap \
  example.org/platform/bootstrap 0.1.0 \
  dist/bootstrap-transport-archive
```

Ein Archiv pro Komponentenversion verhindert Überschreiben und macht den
Freigabestand eindeutig.
