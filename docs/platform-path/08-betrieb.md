# 08 – Betrieb: Nachweis, Backup und Upgrade

**Ziel:** Die Plattform ist nicht nur installiert, sondern nachvollziehbar
betreibbar.

## Regelmäßiger Offline-Nachweis

```bash
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' \
  | sort -u
helm list -A
```

Alle *Anwendungs*-Images müssen auf `REGISTRY_HOST:REGISTRY_PORT` zeigen.
Ausgenommen sind die beim K3s-Bootstrap vorinstallierten Systemimages; auch sie
stammen aus dem K3s-Airgap-Archiv und werden nicht extern geladen.

## Backup

- **Zot:** Backup von `/var/lib/zot`, `/etc/zot/config.json`, Zertifikaten und
  Zugangskonfiguration. Vor Restore Konsistenz und freien Speicher prüfen.
- **Forgejo:** PVC-Inhalt inklusive Repositories und SQLite-Datei sichern. Eine
  laufende SQLite-Datei nicht blind kopieren; verwende einen abgesicherten
  Anwendungssnapshot oder halte Forgejo kurz an.
- **Woodpecker:** PVC mit SQLite-Datenbank und Secrets sichern. Build-Logs sind
  je nach Konfiguration Teil dieses Backups.
- **OCM:** Das freigegebene CTF, Descriptor, Lockfile und Signatur gehören
  zusammen und werden unveränderbar archiviert.

## Upgrade und Rollback

Eine neue Version ist immer eine neue OCM Component Version:

1. connected: Lockfile ändern, Images/Charts erneut inventarisieren, prüfen,
   CTF bauen und signieren;
2. offline: Hash/Signatur prüfen, nach Zot transferieren;
3. Cluster: lokale Charts rendern, Local-only-Check und Server-Dry-Run;
4. erst dann `helm upgrade --install`;
5. bei Problemen Helm-Revision zurückrollen und Datenbank-Kompatibilität
   prüfen.

## Abnahme

Ein Testbackup kann in einer separaten Lab-VM wiederhergestellt werden. Ein
Upgrade und ein Helm-Rollback bleiben vollständig innerhalb der Offline-Zone.
