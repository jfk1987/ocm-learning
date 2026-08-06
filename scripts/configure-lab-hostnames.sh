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

# K3s verwendet im Standard-Server-Block bereits das hosts-Plugin für
# /etc/coredns/NodeHosts. Ein zweites hosts-Plugin in einer *.override-Datei
# würde CoreDNS mit "this plugin can only be used once" beenden. Deshalb
# bekommt die Lab-Zone einen eigenen Server Block über eine *.server-Datei.
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
  echo 'Veralteter CoreDNS-Eintrag lab.override ist noch vorhanden.' >&2
  exit 1
fi

if ! kubectl -n kube-system get configmap coredns-custom \
  -o jsonpath='{.data.lab\.server}' | grep -q '^ocm\.test:53'; then
  echo 'CoreDNS-Server-Block lab.server fehlt.' >&2
  exit 1
fi

if ! kubectl -n kube-system get endpoints lab-ingress \
  -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
  echo 'lab-ingress hat keine Traefik-Endpunkte. Prüfe die Service-Selector.' >&2
  exit 1
fi

printf 'Cluster-DNS eingerichtet: %s -> forgejo.ocm.test, woodpecker.ocm.test\n' \
  "${ingress_ip}"
printf 'Auf dem Host muss zusätzlich stehen:\n'
printf '127.0.0.1 forgejo.ocm.test woodpecker.ocm.test\n'
