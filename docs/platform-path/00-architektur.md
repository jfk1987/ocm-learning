# 00 – Architektur und Reihenfolge

**Ziel:** Den Bootstrap-Zyklus erkennen und bewusst auflösen.

Ein Cluster kann seine Images nur aus der lokalen Registry laden. Eine Registry,
die als erster Pod *im* Cluster läuft, wäre daher nicht erreichbar, wenn der
Cluster sie zum Starten dieses Pods bereits bräuchte. Deshalb läuft Zot in
diesem Lernpfad zunächst als systemd-Service auf dem Registry-Host – außerhalb
von Kubernetes.

```text
1. CTF nach Offline-Station
2. Zot-Binary starten                 ← keine Container-Abhängigkeit
3. K3s-Binary + Air-gap-Images laden  ← keine Registry-Abhängigkeit
4. OCM Ressourcen nach Zot übertragen
5. K3s zieht Forgejo/Woodpecker nur von Zot
6. Woodpecker erzeugt CI-Pods nur mit lokal gelockten Images
```

## Komponenten und Grenzen

| Komponente | Ort | Persistenz | Internet nötig? |
| --- | --- | --- | --- |
| Zot | Registry-Host, systemd | lokales Verzeichnis | Nein |
| K3s | Cluster-Node | K3s-Datenverzeichnis | Nein |
| Forgejo | Kubernetes | PVC, SQLite | Nein |
| Woodpecker Server | Kubernetes | PVC, SQLite | Nein |
| Woodpecker Agent | Kubernetes | temporäre CI-PVCs | Nein |

Die Connected Station ist der einzige Ort mit Internetzugang. Sie erzeugt für
jede Freigabe mindestens zwei OCM-Komponenten:

- `example.org/platform/bootstrap`: K3s-Binary, K3s-Airgap-Archiv,
  Installer, Zot-Binary und Registry-Konfiguration;
- `example.org/platform/developer-platform`: Forgejo-/Woodpecker-Charts,
  Werte-Vorlagen und sämtliche Plattform- sowie CI-Basisimages.

## Abnahme

Die Reihenfolge oben ist nachvollzogen und ein Registry-Host mit dauerhaftem
Speicher sowie ein K3s-Node sind benannt. Für das Lab dürfen beide Rollen auf
einer VM liegen; produktiv sollten Registry und Control Plane getrennt werden.
