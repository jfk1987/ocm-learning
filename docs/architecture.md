# Architektur und Vertrauensgrenzen

## Drei Umgebungen mit klaren Aufgaben

```text
┌───────────── Connected Station / Lab ─────────────┐
│ Forgejo → Woodpecker → Constructor → CTF       │
│                 Source + Chart + Values + Images │
│                              ↓ signieren        │
└──────────────────────────────┬──────────────────┘
                               │ CTF.tgz + SHA-256
                               │ + Signatur/Public Key
                         kontrollierte Schleuse
                               │
┌──────────────────────────────▼──────────────────┐
│ Zielseite: Hash/Signatur → OCM Import → Registry │
│                                      ↓             │
│ k3d-Node ohne Default-Route ← Helm + lokale Values │
└─────────────────────────────────────────────────┘
```

Das Bootstrap-Lab darf externe Images und Charts beziehen. Die Air-Gap-
Eigenschaft gilt für die Zielanwendung im separaten Zielcluster. Seine
Default-Route wird erst entfernt, nachdem K3s selbst bereit ist.

## Verantwortlichkeiten

| Werkzeug | Verantwortung |
| --- | --- |
| Lockfile | menschlich geprüfter Freigabevertrag mit Versionen und Digests |
| OCM | Identität, Herkunft, Digests, Signatur, Transfer und Lokalisierung |
| CTF | portabler Transport von Descriptors und materialisierten Resources |
| OCI Registry | dauerhafte Zielzugriffe für OCM und Container Runtime |
| Helm | Rendern und Anwenden der aus OCM extrahierten Anwendung |
| Kubernetes | Ausführung der ausschließlich lokalen Images |

`--copy-resources` und `--recursive` sind orthogonal: Die erste Option kopiert
die Resource-Inhalte einer Version, die zweite folgt Component References zu
weiteren Versionen.

## Controller-Grenze

Der Kernpfad braucht keinen In-Cluster-Controller. Das vermeidet einen
Bootstrap-Zirkel: Auch Controller, CRDs und deren Images müssten sonst vor dem
ersten Deployment offline bereitstehen. OCM 10 zeigt den Controller deshalb
als getrenntes, internetfähiges Aufbau-Lab. Für ein produktives Air-Gap-GitOps-
System werden seine Chart-, CRD- und Image-Ressourcen anschließend mit demselben
OCM-Muster paketiert.
