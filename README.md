# OCM-Lernlabor: Bootstrap, komplexe Anwendung und automatischer Release

Dieses Projekt ist ein vollständiger Lernpfad mit zwei klar getrennten Ebenen:

1. ein leichtgewichtiges, internetfähiges Lab mit Cluster, Registry, SCM und CI;
2. eine komplexe Zielanwendung, die mit OCM so ausgeliefert wird, dass ihr
   Deployment nur noch die Zielregistry benötigt.

```text
┌───────────── Vorbereitungslabor (Internet erlaubt) ──────────────┐
│ k3d/K3s + OCI Registry + Forgejo + Woodpecker                    │
└─────────────────────────────┬────────────────────────────────────┘
                              │ Git-Tag löst Release aus
                              ▼
┌──────────── OCM-Anwendungs-Lieferung (vollständig) ──────────────┐
│ Chart + Values + CRDs/Dateien + Init-/Job-/App-Images + Digests  │
│           └─ automatischer Constructor → CTF → Registry-Transfer │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
                 Ziel-Workload ohne externen Registry-Pull
```

Die Plattformdienste dürfen selbst Images aus beliebigen Quellen beziehen.
Das Ziel ist ausschließlich, **alle Ressourcen der Zielanwendung** in ihrer
OCI Registry bereitzustellen und sie ohne Internetzugang zu deployen.

## Zwei Git-Repositories mit unterschiedlichen Aufgaben

Dieses Repository `ocm-learning` ist das **Lern- und Bootstrap-Repository**.
Es enthält die Anleitungen, Lab-Konfigurationen, wiederverwendbare Skripte und
Beispiel-Pipelines. Es muss nicht in das Forgejo-Lab gepusht werden und ist
nicht das Repository, das Woodpecker später als Zielanwendung veröffentlicht.

In Lab 02 wird in Forgejo ein zweites, separates Repository
`target-application` angelegt. Nur dort liegen der konkrete Anwendungscode,
das ausgefüllte Lockfile, Chart und Air-Gap-Values sowie die für diese
Anwendung aktivierten Woodpecker-Pipelines. Die Arbeitskopie wird lokal unter
`.lab/workspaces/target-application` angelegt; `.lab/` ist bewusst von Git
ignoriert.

## Teil A – Lab bootstrap

| Schritt | Ergebnis |
| --- | --- |
| [00 – Voraussetzungen](docs/lab-bootstrap/00-voraussetzungen.md) | lokale Werkzeuge bereit |
| [01 – Cluster und Registry](docs/lab-bootstrap/01-cluster-und-registry.md) | k3d/K3s und OCI Registry laufen |
| [02 – Forgejo](docs/lab-bootstrap/02-forgejo.md) | internes SCM bereit |
| [03 – Woodpecker](docs/lab-bootstrap/03-woodpecker.md) | CI mit Kubernetes-Backend bereit |

## Teil B – Zielanwendung mit OCM

| Schritt | Ergebnis |
| --- | --- |
| [00 – Grenzen](docs/application-path/00-grenzen.md) | Lieferumfang eindeutig |
| [01 – Inventar](docs/application-path/01-inventar.md) | Images und Chart fest gelockt |
| [02 – Komponente](docs/application-path/02-komponente.md) | selbstständiges OCM-CTF gebaut |
| [03 – Registry](docs/application-path/03-registry-import.md) | Ressourcen lokalisiert |
| [04 – Deploy](docs/application-path/04-deploy.md) | Workload zieht nur lokal |
| [05 – Nachweis](docs/application-path/05-nachweis.md) | Air-gap verifiziert |
| [06 – Update](docs/application-path/06-update.md) | Update und Rollback wiederholbar |

## Automatisierung als Abschluss

Der letzte Schritt ist [Lab 04 – automatischer Release](docs/lab-bootstrap/04-automatischer-release.md):
Ein Git-Tag löst die OCM-Lieferung aus.

`config/application.lock.yaml` ist der geprüfte Freigabevertrag. Der finale
CI-Schritt führt [deliver-application.sh](/Users/jankahnt/Documents/ai/ocm-learning/scripts/deliver-application.sh)
aus und erledigt in dieser Reihenfolge:

1. Constructor aus dem Lockfile generieren;
2. alle Images und Dateien in ein selbstständiges CTF materialisieren;
3. Component Version samt Resources in die Zielregistry transferieren.

Damit bleibt der Component Descriptor ableitbar, überprüfbar und frei von
manueller YAML-Duplizierung.

## Start

```bash
cp config/lab.env.example config/lab.env
$EDITOR config/lab.env
./scripts/preflight-lab.sh
```

Beginne anschließend bei Lab 00. `latest` ist für die Zielanwendung nicht
zulässig; jede Image-Resource benötigt einen `sha256`-Digest.

Weiterführende Quellen stehen in [docs/references.md](docs/references.md).
