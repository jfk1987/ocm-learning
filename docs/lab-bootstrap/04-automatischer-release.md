# Lab 04 – Automatische OCM-Lieferung aus CI

**Ziel:** Ein Git-Tag erzeugt ohne manuelle Descriptor-Pflege eine vollständig
materialisierte OCM-Komponente und importiert sie in die Zielregistry.

## Release-Vertrag im Repository

Das Forgejo-Repository der Zielanwendung enthält mindestens:

```text
config/application.lock.yaml
delivery/target-application/target-application-chart.tgz
delivery/target-application/values-airgap.yaml
scripts/generate-component-constructor.sh
scripts/build-self-contained-ctf.sh
scripts/import-self-contained-ctf.sh
scripts/deliver-application.sh
.woodpecker/ocm-delivery.yaml
```

`application.lock.yaml` wird im Review aktualisiert. Es enthält alle gelockten
Image-Referenzen und den Chart-Digest. Der CI-Job erstellt daraus den
Constructor, kopiert mit OCM alle Images in ein CTF und transferiert die
Komponentenversion in die Zielregistry.

## CI konfigurieren

1. Baue oder verwende ein CI-Toolimage mit `ocm`, `helm`, `yq`, `skopeo` und
   `bash`. Eine reproduzierbare Vorlage liegt unter
   [`ci/ocm-delivery/Dockerfile`](../../ci/ocm-delivery/Dockerfile). Dieses
   Image darf öffentlich bezogen werden.
2. Lege in Woodpecker die Secrets `target_ocm_repository`,
   `target_registry_host`, `target_registry_username` und
   `target_registry_password` an. Der Job schreibt daraus eine kurzlebige
   Docker-Credential-Datei, die OCM beim Transfer verwendet.
3. Kopiere [ocm-delivery.yaml](../../examples/ci/ocm-delivery.yaml) nach
   `.woodpecker/ocm-delivery.yaml` im Anwendungsrepository und setze das
   Toolimage.
4. Erzeuge einen semantischen Git-Tag, dessen Version mit
   `component.version` im Lockfile übereinstimmt.

Der Job ruft genau diesen einen Release-Befehl auf:

```bash
./scripts/deliver-application.sh \
  config/application.lock.yaml "$DELIVERY_DIR" "$OCM_REPOSITORY"
```

Er beendet sich bei Platzhaltern, fehlenden Dateien, fehlenden Image-Digests
oder einer schon existierenden Ausgabekomponente. Dadurch kann ein Release
nicht versehentlich überschrieben werden.

## Abnahme

Der Woodpecker-Run ist grün. `ocm get component-version` gegen die Zielregistry
zeigt die getaggte Version mit Chart, Values, Zusatzressourcen und allen Images.
