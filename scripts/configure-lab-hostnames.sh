#!/usr/bin/env bash
# Makes the same platform hostnames available on the host and in Kubernetes.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

kubectl apply -f "${repo_root}/config/lab/platform-ingress-service.yaml"

ingress_ip=$(kubectl -n kube-system get service lab-ingress \
  -o jsonpath='{.spec.clusterIP}')
if [[ -z "${ingress_ip}" || "${ingress_ip}" == "None" ]]; then
  echo 'lab-ingress did not receive a ClusterIP.' >&2
  exit 1
fi

# K3s already uses the hosts plugin for /etc/coredns/NodeHosts in the default
# server block. A second hosts plugin in a *.override file would make CoreDNS
# exit with "this plugin can only be used once". Therefore, the lab zone gets
# its own server block through a *.server file.
if ! kubectl -n kube-system get configmap coredns-custom >/dev/null 2>&1; then
  kubectl -n kube-system create configmap coredns-custom
fi

config_patch=$(printf '%s' \
  '{"data":{"lab.override":null,"lab.server":"ocm.test:53 {\n  errors\n  hosts {\n    ' \
  "${ingress_ip}" \
  ' forgejo.ocm.test woodpecker.ocm.test\n  }\n}\n"}}')

kubectl -n kube-system patch configmap coredns-custom \
  --type=merge --patch "${config_patch}"

kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s

if kubectl -n kube-system get configmap coredns-custom \
  -o jsonpath='{.data.lab\.override}' | grep -q .; then
  echo 'Obsolete CoreDNS entry lab.override is still present.' >&2
  exit 1
fi

if ! kubectl -n kube-system get configmap coredns-custom \
  -o jsonpath='{.data.lab\.server}' | grep -q '^ocm\.test:53'; then
  echo 'CoreDNS server block lab.server is missing.' >&2
  exit 1
fi

if ! kubectl -n kube-system get endpoints lab-ingress \
  -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
  echo 'lab-ingress has no Traefik endpoints. Check the service selector.' >&2
  exit 1
fi

printf 'Cluster DNS configured: %s -> forgejo.ocm.test, woodpecker.ocm.test\n' \
  "${ingress_ip}"
printf 'The host must also contain:\n'
printf '127.0.0.1 forgejo.ocm.test woodpecker.ocm.test\n'
