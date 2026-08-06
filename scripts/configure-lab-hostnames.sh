#!/usr/bin/env bash
# Stellt dieselben Plattform-Hostnamen auf dem Host und in Kubernetes bereit.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

kubectl apply -f "${repo_root}/config/lab/platform-ingress-service.yaml"

ingress_ip=$(kubectl -n kube-system get service lab-ingress \
  -o jsonpath='{.spec.clusterIP}')
if [[ -z "${ingress_ip}" || "${ingress_ip}" == "None" ]]; then
  echo 'lab-ingress hat keine ClusterIP erhalten.' >&2
  exit 1
fi

override=$(printf 'hosts {\n  %s forgejo.ocm.test woodpecker.ocm.test\n  fallthrough\n}\n' \
  "${ingress_ip}")

kubectl -n kube-system create configmap coredns-custom \
  --from-literal=lab.override="${override}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s

if ! kubectl -n kube-system get endpoints lab-ingress \
  -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
  echo 'lab-ingress hat keine Traefik-Endpunkte. Prüfe die Service-Selector.' >&2
  exit 1
fi

printf 'Cluster-DNS eingerichtet: %s -> forgejo.ocm.test, woodpecker.ocm.test\n' \
  "${ingress_ip}"
printf 'Auf dem Host muss zusätzlich stehen:\n'
printf '127.0.0.1 forgejo.ocm.test woodpecker.ocm.test\n'
