# OCM 01 – Inventar, Digests und stabile Identitäten

**Ziel:** Du verstehst das generierte Lockfile und kannst beweisen, dass
gerendertes Deployment, Values und OCM-Eingaben dieselben Images meinen.

## 1. Das Inventar lesen

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

cat "$DELIVERY_DIR/images.discovered.txt"
yq '.images' "$TARGET_APP_WORKDIR/config/application.lock.yaml"
yq '.images' "$DELIVERY_DIR/values-airgap.yaml"
```

Jede Referenz besitzt Tag **und** Digest, zum Beispiel
`nginx:1.27.4-alpine@sha256:...`. Der Tag ist lesbar; der Digest macht den
Inhalt unveränderlich. `latest` ist im Lernpfad verboten.

## 2. Plattformbindung verstehen

Ein Registry-Digest kann auf einen Multi-Arch-Index oder auf ein einzelnes
Manifest zeigen. Das Vorbereitungsskript verwendet `skopeo` mit explizitem
`linux/amd64` beziehungsweise `linux/arm64`. Die OCM Resource erhält dieselben
Merkmale später als `extraIdentity`:

```yaml
name: web-image
extraIdentity:
  os: linux
  architecture: arm64
```

Damit könnten zwei Plattformvarianten unter demselben Resource-Namen
existieren, ohne dieselbe Resource-Identität zu haben.

## 3. Den Freigabevertrag validieren

```bash
"$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml" "$DELIVERY_DIR"
```

Die Prüfung umfasst unter anderem:

- SemVer, Provider und stabile Resource-Namen;
- echte Dateien und den SHA-256-Digest des Chart-Pakets;
- `tag@sha256` und OS/Arch je Image;
- keine doppelten Resource-Identitäten oder Platzhalter;
- identische Image-Mengen in Lockfile, Values und gerendertem Inventar.

Probiere den Schutz kontrolliert aus, ohne die Datei zu speichern:

```bash
cp "$TARGET_APP_WORKDIR/config/application.lock.yaml" /tmp/application.invalid.yaml
yq -i '.images[0].version = "latest"' /tmp/application.invalid.yaml
if "$TARGET_APP_WORKDIR/scripts/validate-application-lock.sh" \
  /tmp/application.invalid.yaml "$DELIVERY_DIR"; then
  echo 'FEHLER: Ungültiges Lockfile wurde akzeptiert.' >&2
  false
else
  echo 'Erwarteter Fehler wurde erkannt.'
fi
```

## 4. Warum der Constructor generiert wird

`application.lock.yaml` ist der von Menschen geprüfte Freigabevertrag. Der
OCM Constructor ist eine abgeleitete Build-Eingabe. Würden beide manuell
gepflegt, könnten Digests, Namen oder Versionen auseinanderlaufen.

## Abnahme

Der Validator endet erfolgreich, der Negativtest scheitert erwartungsgemäß,
und du kannst `web-image`, `redis-image` sowie `toolbox-image` im gerenderten
Manifest wiederfinden.

Weiter mit [OCM 02 – Constructor und CTF](02-komponente.md).
