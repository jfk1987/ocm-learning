# 06 – Update und Rollback

**Ziel:** Jede Änderung bleibt eine vollständige, reproduzierbare Lieferung.

Für ein Update wird nicht ein einzelnes Image nachgeschoben. Stattdessen:

1. neue Chart-/Image-Versionen in einem neuen Lockfile festlegen;
2. alle Varianten erneut rendern und inventarisieren;
3. neue OCM Component Version samt CTF bauen und prüfen;
4. in die Zielregistry importieren;
5. aus dieser Version rendern, Local-only-Check und Server-Dry-Run durchführen;
6. Helm-Upgrade ausführen.

Ein Rollback verwendet die vorherige, weiterhin in der Registry verfügbare OCM
Komponentenversion und ihre zugehörigen Values. Ein reines `helm rollback` ist
nur dann ausreichend, wenn Datenbank- und Schema-Kompatibilität der Anwendung
vorher geprüft wurden.

## Abnahme

Eine frühere Component Version kann ohne neue Downloads wiederhergestellt
werden. Das Rollback referenziert weiterhin ausschließlich die Zielregistry.
