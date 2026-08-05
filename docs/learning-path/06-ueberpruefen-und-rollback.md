# 06 – Nachweis und Rollback

**Ziel:** Der Offline-Nachweis ist reproduzierbar und der Rückweg getestet.

## Nachweis

```bash
kubectl get pods -n artifactory-oss -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
helm status artifactory-oss -n artifactory-oss
kubectl get events -n artifactory-oss --sort-by=.lastTimestamp
```

Jede ausgegebene Image-Referenz muss mit `${LOCAL_REGISTRY}/` beginnen. Prüfe
zusätzlich im Netzwerktelemetrie-System, dass Nodes keine Egress-Verbindung zu
öffentlichen Registries aufgebaut haben. Ein absichtlich gesperrter DNS-Name
oder eine NetworkPolicy ist dabei nur ein Test – der eigentliche Nachweis sind
die lokalen Image-Referenzen und das fehlende Egress.

## Rollback üben

Ein OCM-Rollback bedeutet: eine bereits geprüfte, ältere Komponentenversion aus
der lokalen Registry wählen, Chart und Values dieser Version erneut aus OCM
entnehmen, rendern, den Local-only-Check wiederholen und dann ausrollen:

```bash
helm history artifactory-oss -n artifactory-oss
helm rollback artifactory-oss <REVISION> -n artifactory-oss --wait --timeout 15m
```

Bei einem Versionsrollback muss die Datenbank-Kompatibilität zur Artifactory-
Version geprüft werden. Ein Helm-Rollback ersetzt kein getestetes Backup- und
Restore-Verfahren für persistente Daten.

## Abnahme

Ein Testrollback auf eine vorherige Helm-Revision ist erfolgreich, und danach
läuft die gewünschte Zielrevision wieder. Die ausgegebenen Images bleiben bei
allen Revisionen lokal.
