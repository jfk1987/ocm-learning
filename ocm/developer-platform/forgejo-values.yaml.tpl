# Vor dem Einsatz gegen das mitgelieferte Chart mit `helm show values` prüfen.
# Diese Minimalvariante ist ausschließlich für einen einzelnen Lab-Node gedacht.
image:
  repository: REPLACE_WITH_LOCALIZED_FORGEJO_IMAGE
  tag: REPLACE_WITH_EXACT_FORGEJO_TAG
  pullPolicy: IfNotPresent

gitea:
  config:
    database:
      DB_TYPE: sqlite3
  persistence:
    enabled: true
    size: 5Gi
    storageClass: REPLACE_WITH_STORAGE_CLASS

# Der Chart kann die Schlüssel oberhalb je nach Version anders strukturieren.
# Das gerenderte Manifest ist verbindlich; nur die Werte des importierten
# Chart-Releases verwenden und danach scripts/render-local-chart.sh ausführen.
