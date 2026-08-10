# OCM 07 – Credential Resolution praktisch untersuchen

**Ziel:** Eine zweite Registry lehnt anonyme Zugriffe ab. Erst eine passend
gematchte OCM Consumer Identity ermöglicht den Transfer.

Dieses Lab ist unabhängig vom Air-Gap-Zielcluster und läuft auf dem Host.

## 1. Authentifizierte Lab-Registry starten

```bash
./scripts/create-auth-registry.sh
. .lab/auth-registry/credentials.env

curl --show-error http://localhost:5001/v2/
curl --fail --show-error \
  --user "$AUTH_REGISTRY_USERNAME:$AUTH_REGISTRY_PASSWORD" \
  http://localhost:5001/v2/
```

Der erste Aufruf liefert erwartungsgemäß HTTP 401, der zweite HTTP 200. Die
Registry ist bewusst HTTP-only und nur an `127.0.0.1` gebunden.

## 2. OCM-Konfiguration erzeugen

```bash
cat > .lab/auth-registry/ocmconfig.yaml <<EOF
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    consumers:
      - identity:
          type: OCIRegistry
          hostname: localhost
          scheme: http
          port: "5001"
          path: protected
        credentials:
          - type: OCICredentials/v1
            username: ${AUTH_REGISTRY_USERNAME}
            password: ${AUTH_REGISTRY_PASSWORD}
EOF
chmod 600 .lab/auth-registry/ocmconfig.yaml
```

Die Identity ist kein Login-Befehl. Sie beschreibt, **wann** OCM welche
Credentials auswählt. Schema, Host, Port und Pfad müssen zum Request passen.

## 3. Fehlenden und passenden Match vergleichen

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export SOURCE_CTF="$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"

printf '%s\n' 'type: generic.config.ocm.software/v1' \
  > .lab/auth-registry/empty-config.yaml
if OCM_CONFIG="$PWD/.lab/auth-registry/empty-config.yaml" \
  ocm transfer component-version \
  "ctf::$SOURCE_CTF//$COMPONENT_NAME:$COMPONENT_VERSION" \
  'oci::http://localhost:5001/protected' \
  --recursive --copy-resources --upload-as ociArtifact; then
  echo 'FEHLER: anonymer Transfer war erfolgreich.' >&2
  false
else
  echo 'Erwarteter 401 ohne Credentials.'
fi

OCM_CONFIG="$PWD/.lab/auth-registry/ocmconfig.yaml" \
  ocm transfer component-version \
  "ctf::$SOURCE_CTF//$COMPONENT_NAME:$COMPONENT_VERSION" \
  'oci::http://localhost:5001/protected' \
  --recursive --copy-resources --upload-as ociArtifact
```

Teste danach absichtlich einen nicht passenden Pfad `other`. Die Identity mit
`path: protected` darf dort keine Credentials liefern. Ein `*` matcht bei
OCM nur genau ein Pfadsegment, nicht beliebig viele `/`.

## 4. Alternative Credential-Quellen einordnen

OCM kann Consumer auch aus Docker Config, Kubernetes Secrets oder externen
Credential-Plugins bedienen. Die Auswahl nach Identity bleibt gleich. In CI
liegt das OCM-Config-Dokument in einem Woodpecker Secret und nicht im Git-
Repository.

## Abnahme

Ohne Konfiguration erscheint 401, mit exakt passender Consumer Identity ist
die Component Version unter `protected` lesbar, und die Config-Datei hat Modus
600.

Weiter mit [OCM 08 – Component References](08-component-references.md).
