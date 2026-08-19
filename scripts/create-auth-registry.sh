#!/usr/bin/env bash
# Starts a second HTTP-only lab registry with basic auth. Only for the
# credential resolution lab, not for production.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="${repo_root}/.lab/auth-registry"
container=ocm-auth-registry
username=ocm-user

for command_name in docker openssl curl; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "${command_name} is missing." >&2; exit 1; }
done

if docker inspect "$container" >/dev/null 2>&1; then
  echo "Container already exists: ${container}" >&2
  echo "Credentials are stored in ${state_dir}/credentials.env" >&2
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
    echo "Authenticated registry ready: http://localhost:5001"
    echo "Credentials: ${state_dir}/credentials.env"
    exit 0
  fi
  sleep 1
done
docker logs "$container" >&2
echo 'Registry did not become ready in time.' >&2
exit 1
