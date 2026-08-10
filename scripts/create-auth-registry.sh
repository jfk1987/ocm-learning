#!/usr/bin/env bash
# Startet eine zweite, HTTP-only Lab-Registry mit Basic Auth. Nur für das
# Credential-Resolution-Lab, nicht für Produktion.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="${repo_root}/.lab/auth-registry"
container=ocm-auth-registry
username=ocm-user

for command_name in docker openssl curl; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "${command_name} fehlt." >&2; exit 1; }
done

if docker inspect "$container" >/dev/null 2>&1; then
  echo "Container existiert bereits: ${container}" >&2
  echo "Zugangsdaten liegen in ${state_dir}/credentials.env" >&2
  exit 1
fi
mkdir -p "$state_dir/auth" "$state_dir/data"
password=$(openssl rand -hex 18)
docker run --rm --entrypoint htpasswd public.ecr.aws/docker/library/httpd:2.4-alpine \
  -Bbn "$username" "$password" > "${state_dir}/auth/htpasswd"

docker run -d --name "$container" \
  --publish 127.0.0.1:5001:5000 \
  --env REGISTRY_AUTH=htpasswd \
  --env 'REGISTRY_AUTH_HTPASSWD_REALM=OCM Learning Lab' \
  --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  --volume "${state_dir}/auth:/auth:ro" \
  --volume "${state_dir}/data:/var/lib/registry" \
  public.ecr.aws/docker/library/registry:2.8.3 >/dev/null

cat > "${state_dir}/credentials.env" <<EOF
export AUTH_REGISTRY_USERNAME='${username}'
export AUTH_REGISTRY_PASSWORD='${password}'
EOF
chmod 600 "${state_dir}/credentials.env"

for _ in {1..30}; do
  if curl --fail --silent --user "${username}:${password}" \
    http://localhost:5001/v2/ >/dev/null; then
    echo "Authentifizierte Registry bereit: http://localhost:5001"
    echo "Zugangsdaten: ${state_dir}/credentials.env"
    exit 0
  fi
  sleep 1
done
docker logs "$container" >&2
echo 'Registry wurde nicht rechtzeitig bereit.' >&2
exit 1
