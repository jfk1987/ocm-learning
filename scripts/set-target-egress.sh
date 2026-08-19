#!/usr/bin/env bash
# Removes/adds the default route of the k3d workload nodes. Direct Docker
# networks, especially the lab registry, remain reachable.
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
  echo "No workload nodes found for k3d cluster ${cluster}." >&2
  exit 1
}

case "$action" in
  block)
    for node in "${nodes[@]}"; do
      docker exec "$node" sh -c 'ip route del default 2>/dev/null || true'
      echo "Egress blocked: ${node}"
    done
    ;;
  allow)
    gateway=$(docker network inspect "$network" \
      --format '{{(index .IPAM.Config 0).Gateway}}')
    [[ -n "$gateway" ]] || { echo "Gateway for ${network} is missing." >&2; exit 1; }
    for node in "${nodes[@]}"; do
      docker exec "$node" sh -c "ip route replace default via ${gateway}"
      echo "Egress allowed: ${node} via ${gateway}"
    done
    ;;
  status)
    for node in "${nodes[@]}"; do
      printf '%s: ' "$node"
      if ! docker exec "$node" ip route show default | grep -q '^default '; then
        echo 'blocked (no default route)'
      else
        docker exec "$node" ip route show default
      fi
    done
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    exit 64
    ;;
esac
