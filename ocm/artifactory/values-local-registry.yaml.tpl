# Dieses Template wird nach dem OCM-Import befüllt. Die endgültigen Werte
# ergeben sich ausschließlich aus dem lokalisierten Component Descriptor.
#
# 1. `ocm get component-version ... -o yaml` speichern.
# 2. imageReference jedes Image-Resources übernehmen.
# 3. Die Schlüssel gegen `helm show values <lokales-chart.tgz>` der exakt
#    gelieferten Chart-Version prüfen.
#
# Der Chart 107.146.29 verwendet mehrere Images (Artifactory, Router, Nginx,
# PostgreSQL sowie ggf. Init-Container). Nicht vorhandene Images nicht raten;
# sie müssen im Lockfile und OCM Descriptor enthalten sein.

artifactory:
  image:
    repository: REPLACE_WITH_LOCALIZED_ARTIFACTORY_IMAGE
    tag: REPLACE_WITH_LOCALIZED_ARTIFACTORY_TAG
  router:
    image:
      repository: REPLACE_WITH_LOCALIZED_ROUTER_IMAGE
      tag: REPLACE_WITH_LOCALIZED_ROUTER_TAG

nginx:
  enabled: false

postgresql:
  enabled: true
  image:
    repository: REPLACE_WITH_LOCALIZED_POSTGRESQL_IMAGE
    tag: REPLACE_WITH_LOCALIZED_POSTGRESQL_TAG
  auth:
    # Nur der Secret-Name gehört in versionierte Konfiguration, niemals das Passwort.
    existingSecret: artifactory-postgresql

# Für die Laborumgebung: StorageClass explizit setzen und Größe passend wählen.
# persistentVolumeClaim:
#   storageClassName: REPLACE_WITH_STORAGE_CLASS
