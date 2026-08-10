#!/usr/bin/env bash
# Baut einen separaten k3d-Zielcluster auf und blockiert danach Internet-Egress
# auf seinen Workload-Nodes. Die direkt verbundene Lab-Registry bleibt sichtbar.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cluster=${1:-ocm-target}
registry=${LAB_REGISTRY_CONTAINER:-k3d-registry.localhost:5000}

for command_name in docker k3d kubectl; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Fehlendes Werkzeug: ${command_name}" >&2
    exit 1
  }
done

if k3d cluster list --no-headers | awk '{print $1}' | grep -Fxq "$cluster"; then
  echo "Cluster existiert bereits: ${cluster}" >&2
  echo "Zum erneuten Aufbau zuerst bewusst ausführen: k3d cluster delete ${cluster}" >&2
  exit 1
fi

docker inspect k3d-registry.localhost >/dev/null 2>&1 || {
  echo 'Die Registry aus Lab 01 fehlt: k3d-registry.localhost' >&2
  exit 1
}

k3d cluster create "$cluster" \
  --servers 1 \
  --agents 0 \
  --registry-use "$registry" \
  --registry-config "${repo_root}/config/lab/k3d-registries.yaml" \
  --k3s-arg '--disable=traefik@server:0' \
  --wait

kubectl --context "k3d-${cluster}" wait \
  --for=condition=Ready node --all --timeout=180s
kubectl --context "k3d-${cluster}" -n kube-system rollout status \
  deployment/coredns --timeout=180s

"${repo_root}/scripts/set-target-egress.sh" block "$cluster"
"${repo_root}/scripts/set-target-egress.sh" status "$cluster"

server="k3d-${cluster}-server-0"
if docker exec "$server" ip route show default | grep -q '^default '; then
  echo 'FEHLER: Der Ziel-Node besitzt weiterhin eine Default-Route.' >&2
  exit 1
fi
docker exec "$server" wget -q -T 5 -O - \
  http://k3d-registry.localhost:5000/v2/ >/dev/null
if docker exec "$server" wget -q -T 5 -O /dev/null \
  https://registry-1.docker.io/v2/; then
  echo 'FEHLER: Der Ziel-Node erreicht weiterhin Docker Hub.' >&2
  exit 1
fi

echo "Air-Gap-Zielcluster bereit: k3d-${cluster}"
echo 'Die Lab-Registry ist erreichbar; die Default-Route ins Internet fehlt.'
