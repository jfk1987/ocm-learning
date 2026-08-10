#!/usr/bin/env bash
# Entfernt/ergänzt die Default-Route der k3d-Workload-Nodes. Direkte
# Docker-Netze (insbesondere die Lab-Registry) bleiben erreichbar.
set -euo pipefail

if (($# < 1 || $# > 2)); then
  echo "Usage: $0 <block|allow|status> [cluster-name]" >&2
  exit 64
fi

action=$1
cluster=${2:-ocm-target}
network="k3d-${cluster}"

nodes=()
while IFS= read -r line; do
  [[ -n "$line" ]] && nodes+=("$line")
done < <(
  docker ps --format '{{.Names}}' |
    awk -v prefix="k3d-${cluster}-" '$0 ~ "^" prefix "(server|agent)-" { print }'
)

((${#nodes[@]} > 0)) || {
  echo "Keine Workload-Nodes für k3d-Cluster ${cluster} gefunden." >&2
  exit 1
}

case "$action" in
  block)
    for node in "${nodes[@]}"; do
      docker exec "$node" sh -c 'ip route del default 2>/dev/null || true'
      echo "Egress blockiert: ${node}"
    done
    ;;
  allow)
    gateway=$(docker network inspect "$network" \
      --format '{{(index .IPAM.Config 0).Gateway}}')
    [[ -n "$gateway" ]] || { echo "Gateway für ${network} fehlt." >&2; exit 1; }
    for node in "${nodes[@]}"; do
      docker exec "$node" sh -c "ip route replace default via ${gateway}"
      echo "Egress erlaubt: ${node} via ${gateway}"
    done
    ;;
  status)
    for node in "${nodes[@]}"; do
      printf '%s: ' "$node"
      if ! docker exec "$node" ip route show default | grep -q '^default '; then
        echo 'blockiert (keine Default-Route)'
      else
        docker exec "$node" ip route show default
      fi
    done
    ;;
  *)
    echo "Unbekannte Aktion: ${action}" >&2
    exit 64
    ;;
esac
