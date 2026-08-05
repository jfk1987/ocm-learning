# Vor dem Einsatz gegen das mitgelieferte Chart mit `helm show values` prüfen.
# Alle *_IMAGE- und *_TAG-Platzhalter stammen aus imported-platform.yaml.
agent:
  replicaCount: 1
  image:
    registry: REPLACE_WITH_LOCAL_REGISTRY_HOSTPORT
    repository: REPLACE_WITH_LOCALIZED_WOODPECKER_AGENT_PATH
    tag: REPLACE_WITH_EXACT_AGENT_TAG
  imagePullSecrets:
    - name: registry-pull
  env:
    WOODPECKER_BACKEND: kubernetes
    WOODPECKER_BACKEND_K8S_NAMESPACE: ci-jobs
    WOODPECKER_BACKEND_K8S_PULL_SECRET_NAMES: registry-pull
    WOODPECKER_MAX_WORKFLOWS: '1'
  serviceAccount:
    create: true
    rbac:
      create: true

server:
  statefulSet:
    replicaCount: 1
  image:
    registry: REPLACE_WITH_LOCAL_REGISTRY_HOSTPORT
    repository: REPLACE_WITH_LOCALIZED_WOODPECKER_SERVER_PATH
    tag: REPLACE_WITH_EXACT_SERVER_TAG
  imagePullSecrets:
    - name: registry-pull
  persistentVolume:
    enabled: true
    size: 2Gi
    storageClass: REPLACE_WITH_STORAGE_CLASS
  env:
    WOODPECKER_HOST: https://REPLACE_WITH_WOODPECKER_HOST
    WOODPECKER_FORGEJO: 'true'
    WOODPECKER_FORGEJO_URL: https://REPLACE_WITH_FORGEJO_HOST
  extraSecretNamesForEnvFrom:
    - woodpecker-secrets
