# Architektur und Begriffe

## Zwei Vertrauenszonen

Die Connected Station darf nur zum Beschaffen, Prüfen und Paketieren verwendet
werden. Der Cluster bekommt niemals Zugang zu öffentlichen Registries. Die
Offline-Zone vertraut ausschließlich dem importierten Paket und ihrer lokalen
OCI Registry.

```text
┌──────────────── connected ────────────────┐       ┌──────────── offline ────────────┐
│ JFrog Chart + Image-Digests                │       │ lokale OCI Registry             │
│             │                              │ CTF   │   │                              │
│             ▼                              │──────►│   ▼                              │
│ OCM component-constructor.yaml             │       │ OCM transfer --copy-resources   │
│             │                              │       │   │                              │
│             ▼                              │       │   ▼                              │
│ Common Transport Format (CTF)               │       │ Helm chart + lokale Image-Refs  │
└────────────────────────────────────────────┘       └─────────────────────────────────┘
```

## Was OCM hier sicherstellt

Eine OCM-Komponentenversion ist ein unveränderlicher, versionierter Vertrag.
Sie enthält die Ressourcen (Chart, Images, Values/Manifeste) und deren Zugriffe.
Beim Transfer mit `--copy-resources` werden die referenzierten Ressourcen in
das Ziel kopiert und der Descriptor auf die Zielorte lokalisiert. Dadurch kann
der Import kontrolliert, wiederholt und auditiert werden.

OCM ersetzt nicht Kubernetes, Helm oder die Registry:

| Werkzeug | Aufgabe |
| --- | --- |
| OCM | Lieferumfang beschreiben, signieren, prüfen, transportieren |
| CTF | portabler Offline-Container für eine OCM-Komponente |
| lokale OCI Registry | dauerhafte Quelle für Images und OCM-Artefakte |
| Helm | Artifactory-Kubernetes-Ressourcen rendern und installieren |
| Kubernetes | Workloads aus der lokalen Registry ausführen |

## Bootstrap-Grenze

Ein OCM Controller im Cluster wäre selbst ein weiterer Workload mit Images und
CRDs. Dieser Lernpfad startet daher absichtlich *ohne* Controller: Die
Build-/Import-Station führt OCM aus und Helm installiert das bereits
lokalisierte Chart. Das reduziert den ersten Bootstrapping-Zyklus.

Nach Schritt 06 kann derselbe Mechanismus für einen OCM Controller, Flux und
weitere Plattform-Komponenten wiederholt werden. Erst wenn deren Images,
Charts, CRDs und Konfiguration ebenfalls als OCM-Lieferung vorliegen, ist ein
vollständiges In-Cluster-GitOps-Modell air-gapped.
