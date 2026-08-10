# OCM 06 – Neue Component Version und Rollback

**Ziel:** Du lieferst eine sichtbare Anwendungsänderung als vollständige neue
Component Version und kannst auf die alte Version zurückkehren.

## 1. Quelländerung vornehmen

Im Forgejo-Arbeitsverzeichnis wird der Antworttext des Webservers geändert:

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"

grep -n 'OCM target application is running' \
  "$TARGET_APP_WORKDIR/app/templates/configmap.yaml"
sed -i.bak \
  's/OCM target application is running/OCM target application 0.2.0 is running/' \
  "$TARGET_APP_WORKDIR/app/templates/configmap.yaml"
rm "$TARGET_APP_WORKDIR/app/templates/configmap.yaml.bak"
```

Unter BSD/macOS und GNU/Linux erzeugt diese Schreibweise kurz eine
`.bak`-Datei und entfernt exakt diese danach.

## 2. Neue Eingaben reproduzierbar vorbereiten

```bash
"$TARGET_APP_WORKDIR/scripts/prepare-next-version.sh" \
  "$TARGET_APP_WORKDIR" 0.2.0 0.2.0
yq '.component.version, .charts[0].version, .charts[0].digest' \
  "$TARGET_APP_WORKDIR/config/application.lock.yaml"
```

Die Image-Versionen bleiben hier absichtlich unverändert. Ein echtes
Image-Upgrade verlangt erneut `skopeo inspect`, neue Digests und ein Render-
Inventar; es wird nicht als Seiteneffekt eines Chart-Updates versteckt.

## 3. Neue Version bauen, signieren und importieren

Wiederhole OCM 02 und 03 mit `COMPONENT_VERSION=0.2.0`. Wegen der
versionsbezogenen Namen bleiben beide CTFs nebeneinander erhalten:

```text
transport-archive-0.1.0/
transport-archive-0.2.0/
```

Importiere anschließend `0.2.0`, lade Chart/Values in
`deploy-0.2.0/`, lokalisiere die Values und führe `helm upgrade` wie in OCM 04
aus. Prüfe den neuen Text bei laufendem Port-Forward:

```bash
kubectl --context k3d-ocm-target -n target-application \
  port-forward service/target-application-web 18080:80
```

In einem zweiten Terminal:

```bash
curl --fail http://localhost:18080/
```

## 4. Rollback als erneute deklarative Installation

OCM 0.1.0 bleibt in Registry und CTF erhalten. Verwende erneut Chart und
lokalisierte Values aus `deploy-0.1.0/`:

```bash
helm upgrade target-application \
  "$DELIVERY_DIR/deploy-0.1.0/chart.tgz" \
  --namespace target-application \
  --values "$DELIVERY_DIR/deploy-0.1.0/values-local.yaml" \
  --wait --wait-for-jobs --timeout 10m
```

Ein bloßes `helm rollback` würde die OCM-Herkunft nicht ausdrücklich machen.
Bei Datenbankschemaänderungen muss zusätzlich die Abwärtskompatibilität
geprüft werden.

## Abnahme

0.1.0 und 0.2.0 sind getrennt abfragbar, das Upgrade zeigt den neuen Text,
und das Rollback funktioniert ohne Upstream-Download.

Der Kernpfad ist abgeschlossen. Als Nächstes folgen die unabhängigen
[fortgeschrittenen OCM-Labs](../advanced/07-credentials.md).
