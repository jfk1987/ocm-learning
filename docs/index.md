# OCM-Lernlabor: vom leeren Rechner bis zum Air-Gap-Release

Dieses Repository ist ein durchgängiger, praktischer Lernpfad für das
[Open Component Model](https://ocm.software/). Es setzt keine Erfahrung mit
OCM, Forgejo oder Woodpecker voraus.

Das Ergebnis ist eine konkrete Nginx/Redis-Anwendung mit Helm-Chart,
Init-Container, StatefulSet, Migrations-Hook und Test. Source-Metadaten,
Source-Archiv, Chart, Values und alle drei Laufzeitimages werden als OCM
Component Version ausgeliefert, signiert, durch ein CTF über eine simulierte
Luftspalte transportiert und in einem Zielcluster ohne Internet-Egress
installiert.

## Der verbindliche Lernpfad

Arbeite die Kapitel von oben nach unten ab. Jedes Kapitel hat ein kleines,
prüfbares Ergebnis und einen Abnahmeabschnitt.

### Teil A – Leichtgewichtiges Labor bootstrappen

| Schritt | Ergebnis |
| --- | --- |
| [Lab 00 – Voraussetzungen](lab-bootstrap/00-voraussetzungen.md) | Docker, k3d, kubectl, Helm, OCM, yq und Skopeo bereit |
| [Lab 01 – Cluster und Registry](lab-bootstrap/01-cluster-und-registry.md) | k3d/K3s zieht erfolgreich aus der lokalen HTTP-Registry |
| [Lab 02 – Forgejo](lab-bootstrap/02-forgejo.md) | SCM, Benutzer, Token und separates Anwendungsrepository bereit |
| [Lab 03 – Woodpecker](lab-bootstrap/03-woodpecker.md) | OAuth, Webhook und erste Kubernetes-CI-Pipeline funktionieren |

### Teil B – Vollständige OCM-Lieferung

| Schritt | Praktisch behandelter OCM-Aspekt |
| --- | --- |
| [OCM 00 – Anwendung und Modell](application-path/00-grenzen.md) | Component, Version, Source, Resources und Liefergrenze |
| [OCM 01 – Inventar](application-path/01-inventar.md) | Digests, Plattformen, `extraIdentity`, Lockfile |
| [OCM 02 – Constructor und CTF](application-path/02-komponente.md) | Inputs, Access, Labels, Descriptor, Resource-Selektion |
| [OCM 03 – Signatur und Transport](application-path/03-registry-import.md) | RSA-Signatur, Verifikation, CTF-Paket und Schleusenhash |
| [OCM 04 – Import und Deployment](application-path/04-deploy.md) | rekursiver Transfer, Resource-Lokalisierung, Helm |
| [OCM 05 – Air-Gap-Nachweis](application-path/05-nachweis.md) | echte Netztrennung, positiver Neustart, negativer Upstream-Pull |
| [OCM 06 – Update und Rollback](application-path/06-update.md) | getrennte Component Versions und Wiederherstellung |

### Teil C – Aufbau-Labs

| Schritt | Ergebnis |
| --- | --- |
| [OCM 07 – Credentials](advanced/07-credentials.md) | authentifizierte Registry und Consumer-Identity-Matching |
| [OCM 08 – Component References](advanced/08-component-references.md) | Produkt aus zwei Komponenten, rekursiver Transfer |
| [OCM 09 – Resolver](advanced/09-resolvers.md) | deterministische Auflösung verteilter Komponenten |
| [OCM 10 – Kubernetes Controller](advanced/10-controller.md) | Repository → Component → Resource → Deployer |

### Teil D – Abschlussautomatisierung

[Lab 04 – automatischer OCM-Release](lab-bootstrap/04-automatischer-release.md)
baut ein eigenes CI-Toolimage. Ein Forgejo-Tag löst in Woodpecker die
Lockfile-Prüfung, Constructor-Erzeugung, CTF-Materialisierung und den
Registry-Transfer aus.

## Zwei Git-Repositories, zwei Aufgaben

`ocm-learning` enthält Tutorial, Vorlagen, Demo und wiederverwendbare Skripte.
Es wird **nicht** als Zielanwendung in Forgejo eingecheckt. Lab 02 erzeugt das
separate Repository `target-application` unter
`.lab/workspaces/target-application`; nur dieses Repository wird von
Woodpecker released. OCM 00 füllt es mit der konkreten Anwendung.

## Start

```bash
cp config/lab.env.example config/lab.env
$EDITOR config/lab.env
./scripts/preflight-lab.sh
```

Beginne danach bei Lab 00. Bei Versionsänderungen an OCM oder den Helm-Charts
prüfe zuerst die [Referenzen](references.md); das Repository pinnt Versionen
bewusst, damit ein Durchlauf reproduzierbar bleibt.
