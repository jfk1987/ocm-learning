# 01 – Inventar und Lockfile

**Ziel:** Es ist exakt bekannt, welche Artefakte in die Offline-Zone müssen.

Auf der Connected Build-Station:

```bash
./scripts/render-and-inventory.sh
cat dist/rendered/images.discovered.txt
```

Für jede gefundene Referenz wird ein Eintrag in `config/images.lock.yaml`
angelegt. Lies den Digest für die gewünschte Architektur aus und schreibe ihn
als `sha256:…` ein. Beispiel für eine einzelne Referenz:

```bash
skopeo inspect --format '{{.Digest}}' \
  docker://releases-docker.jfrog.io/jfrog/artifactory-oss:7.146.29
```

Bei Multi-Arch-Images muss die Zielarchitektur (`linux/amd64` oder `linux/arm64`)
festgelegt werden. Halte sie als Entscheidung im Merge Request fest; die
`skopeo inspect --raw`-Ausgabe zeigt, ob ein Manifest-Index vorliegt.

Danach:

```bash
./scripts/validate-lockfile.sh
```

## Abnahme

Die Image-Liste aus dem Rendering und die Einträge im Lockfile sind identisch.
Das Lockfile enthält keine `TBD`- oder `latest`-Werte und die Validierung ist
erfolgreich.
