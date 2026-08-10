# Lab 00 – Voraussetzungen

**Ziel:** Der Rechner kann das internetfähige Vorbereitungslabor aufbauen. Am
Ende dieses Schritts sind alle Werkzeuge installiert, Docker läuft und die
gemeinsamen Lab-Variablen sind geladen.

Die Plattformdienste dürfen in Teil A Images und Charts aus dem Internet
laden. Erst die in Teil B ausgelieferte Zielanwendung wird ohne externen
Registry-Zugriff installiert.

## 1. Ressourcen bereitstellen

Das Lab ist für macOS oder Linux ausgelegt. Stelle Docker Desktop auf macOS
mindestens 4 CPUs, 8 GiB RAM und ungefähr 25 GiB freien Plattenplatz zur
Verfügung. Für Forgejo allein reicht weniger; Woodpecker und parallele
CI-Schritte benötigen den Puffer später.

Unter Linux muss der aktuelle Benutzer Docker ohne `sudo` verwenden können.
Dieser Test muss erfolgreich sein:

```bash
docker run --rm public.ecr.aws/docker/library/hello-world:latest
```

## 2. Kommandozeilenwerkzeuge installieren

Benötigt werden:

| Werkzeug | Aufgabe im Lernpfad |
| --- | --- |
| Docker | Container Runtime für k3d und lokale Image-Operationen |
| k3d | leichtgewichtiger K3s-Cluster in Docker |
| kubectl | Zugriff auf Kubernetes |
| Helm | Installation von Forgejo und Woodpecker |
| OCM CLI | Erzeugen und Übertragen der OCM-Komponenten |
| yq | Validierung und Generierung von YAML |
| skopeo | Prüfung und Kopie von OCI-Images |

Auf macOS lassen sich die allgemeinen Werkzeuge mit Homebrew installieren:

```bash
brew install k3d kubectl helm yq skopeo
```

Die OCM CLI wird mit dem vom OCM-Projekt veröffentlichten Installer für macOS
und Linux installiert. Er legt die Binärdatei standardmäßig unter
`~/.local/bin` ab:

```bash
curl -sfL https://ocm.software/install-cli.sh | bash
export PATH="${HOME}/.local/bin:${PATH}"
ocm version
```

Der offizielle Installer prüft die Integrität und kann bei vorhandenem,
authentifiziertem GitHub CLI zusätzlich die Build-Attestierung prüfen. Unter
Linux verwendest du für die übrigen Werkzeuge die Installationsanleitung des
jeweiligen Projekts. Installiere keine ungeprüfte Binärdatei als `root`.

## 3. Projektvariablen anlegen

Vom Wurzelverzeichnis dieses Repositories aus:

```bash
cp config/lab.env.example config/lab.env
. config/lab.env
```

`config/lab.env` wird nicht eingecheckt. In den ersten Labs bleibt die
Registry-Adresse absichtlich `localhost:5000`. Kubernetes bekommt in Lab 01
eine Mirror-Konfiguration, die genau diese Adresse innerhalb des Clusters
korrekt auflöst.

## 4. Installation prüfen

```bash
./scripts/preflight-lab.sh
docker version
k3d version
kubectl version --client
helm version
ocm version
yq --version
skopeo --version
```

Halte die Ausgaben bei Problemen fest. Der Lernpfad pinnt später die
Artefaktversionen; die lokale Werkzeugversion darf neuer sein, sollte aber
nicht während eines Durchlaufs wechseln.

## Abnahme

- `./scripts/preflight-lab.sh` endet mit `Lab-Voraussetzungen erfüllt.`
- `docker run --rm public.ecr.aws/docker/library/hello-world:latest`
  funktioniert ohne `sudo`.
- `echo "$LOCAL_REGISTRY"` gibt `localhost:5000` aus.

Erst danach folgt [Lab 01 – Cluster und Registry](01-cluster-und-registry.md).
