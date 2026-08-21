# OCM 05 – Positiv- und Negativnachweis

**Ziel:** Du beweist sowohl den erfolgreichen lokalen Neustart als auch das
Scheitern eines externen Pulls. Ein grünes Deployment allein reicht nicht.

## Was in diesem Kapitel wirklich bewiesen wird

Ein bereits laufender Pod könnte sein Image aus dem lokalen Node-Cache erhalten
haben. Ein grüner Status beweist deshalb noch nicht, dass die Anwendung nach
einem Neustart ausschließlich aus der Zielregistry versorgt werden kann.

Der Nachweis braucht zwei entgegengesetzte Ergebnisse:

```text
lokales, freigegebenes Image  ── muss erneut startbar sein
neues öffentliches Image     ── muss am fehlenden Internetzugang scheitern
```

Nur zusammen zeigen diese Tests: Der Cluster ist nicht einfach kaputt, sondern
gezielt von Upstream-Registries getrennt und lokal weiterhin versorgbar.

## 1. Netztrennung und lokalen Weg getrennt prüfen

```bash
./scripts/set-target-egress.sh status ocm-target
docker exec k3d-ocm-target-server-0 \
  wget -q -T 5 -O- http://k3d-registry.localhost:5000/v2/
```

Der erste Befehl prüft, dass im Node keine Default-Route existiert. Der zweite
startet `wget` **im k3d-Node-Container** und fragt den Registry-V2-Endpunkt
über das direkt verbundene Docker-Netz ab.

Die Optionen von `wget` bedeuten:

| Option | Bedeutung |
| --- | --- |
| `-q` | keine Fortschrittsanzeige |
| `-T 5` | nach fünf Sekunden abbrechen |
| `-O-` | Antwort nach stdout statt in eine Datei schreiben |

Eine leere Antwort oder `{}` bei Exit-Code `0` ist erfolgreich. Damit sind
gleichzeitig zwei Aussagen sichtbar: Internet-Egress ist blockiert, die
lokale Registry ist erreichbar.

## 2. Den vollständigen Laufzeittest ausführen

```bash
./scripts/assert-airgap-runtime.sh k3d-ocm-target localhost:5000
```

Die beiden Argumente sind Kubernetes-Kontext und erlaubtes Registry-Präfix.
Das Skript führt anschließend drei voneinander unabhängige Kontrollen aus.

### Kontrolle A: Nur lokale Image-Adressen

Das Skript liest alle laufenden Pods als JSON, sammelt Haupt- und
Init-Container und prüft jede `.image`-Angabe. Eine Referenz außerhalb von
`localhost:5000/` beendet den Test sofort.

Die Ausgabe beginnt ungefähr so:

```text
Local images only:
localhost:5000/...
```

Das beweist die deklarierte Konfiguration, aber noch nicht den erneuten Pull.

### Kontrolle B: Lokaler Neustart muss gelingen

Das Skript führt einen `rollout restart` des Web-Deployments aus und wartet
auf den erfolgreichen Rollout. Mit `imagePullPolicy: Always` muss Kubernetes
die Referenz erneut über die lokale Registry auflösen, statt sich nur auf
einen bereits laufenden Pod zu verlassen.

Ein erfolgreicher Rollout beweist: DNS/Registry-Mirror, Registry-Inhalt,
Manifest und Kubernetes-Start funktionieren trotz blockiertem Egress
gemeinsam.

### Kontrolle C: Öffentlicher Pull muss scheitern

In einem separaten Namespace erzeugt das Skript einen neuen Pod mit einem
nicht vorgecachten Image aus `registry.k8s.io`. Es wartet 45 Sekunden auf
`Ready`. Würde der Pod bereit, wäre die Air-Gap-Annahme widerlegt und das
Skript beendet sich mit einem Fehler.

Erwartet werden stattdessen:

```text
ErrImagePull
```

oder:

```text
ImagePullBackOff
```

Die danach ausgegebenen Pod-Events zeigen den gescheiterten Zugriff. In diesem
Negativtest ist der rote Kubernetes-Status das gewünschte Ergebnis. Die letzte
Skriptzeile bestätigt deshalb trotzdem:

```text
Air-gap check succeeded: local restart works and the upstream pull fails.
```

## 3. Die tatsächlich gestarteten Digests dokumentieren

Kubernetes unterscheidet zwischen der gewünschten Image-Referenz in `.image`
und dem tatsächlich gestarteten Inhalt in `.imageID`. Lies beide Werte aus:

```bash
kubectl --context k3d-ocm-target -n target-application get pods -o json |
  yq -p=json -r '
    .items[] as $pod |
    (($pod.status.initContainerStatuses // []) +
     ($pod.status.containerStatuses // []))[] |
    [$pod.metadata.name, .name, .image, .imageID] | @tsv
  '
```

Der Datenstrom läuft von links nach rechts:

1. `kubectl ... -o json` liefert alle Pods als JSON.
2. Die Pipe reicht das JSON an `yq` weiter.
3. `-p=json` sagt `yq`, welches Eingabeformat es liest; `-r` erzeugt
   unformatierten Text.
4. Init- und Hauptcontainer-Statuslisten werden zusammengeführt.
5. Pro Container werden Podname, Containername, deklarierte Referenz und
   `imageID` tabulatorgetrennt ausgegeben.

Die `imageID` enthält den Content-Digest, den die Runtime tatsächlich gestartet
hat. Für einen realen Release-Nachweis speicherst du diese Ausgabe zusammen mit
Component-Name, Component-Version, CTF-Hash und Ergebnis der Signaturprüfung.

## 4. Egress nach dem Lab nur bewusst wieder erlauben

Wenn du den Zielcluster für andere Experimente weiterverwenden möchtest:

```bash
./scripts/set-target-egress.sh allow ocm-target
./scripts/set-target-egress.sh status ocm-target
```

`allow` setzt die Default-Route über das Gateway des k3d-Docker-Netzes wieder.
Der anschließende Status muss nun eine `default via ...`-Route zeigen. Für den
OCM-Nachweis bleibt Egress dagegen blockiert.

## Checkpoint

Der lokale Neustart ist erfolgreich, der Upstream-Pod scheitert und die Liste
der tatsächlich gestarteten `imageID`-Digests ist dokumentiert. Du kannst nun
erklären, warum weder ein grünes Deployment noch ein einzelner fehlgeschlagener
Internet-Pull für sich allein ein vollständiger Air-Gap-Nachweis wäre.

Weiter mit [OCM 06 – Update und Rollback](06-update.md).
