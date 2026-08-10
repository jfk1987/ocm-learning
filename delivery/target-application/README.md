# Lieferarbeitsverzeichnis der Zielanwendung

Dieses Verzeichnis wird zusammen mit dem Lockfile versioniert. Vor einem
Release liegen hier mindestens:

- `target-application-chart.tgz` – das gepinnte, inklusive Abhängigkeiten
  gepackte Helm-Chart;
- `values-airgap.yaml` – freigegebene Ziel-Values ohne Klartextsecrets;
- optionale Verzeichnisse für CRDs, Migrationsmanifeste oder Konfigurations-
  Dateien, die im Lockfile als `additionalResources` stehen.

Der CI-Release erzeugt hier nur temporär
`component-constructor-<version>.yaml` und
`transport-archive-<version>/`. Diese Dateien sind ignoriert und dürfen nicht committed
werden.
