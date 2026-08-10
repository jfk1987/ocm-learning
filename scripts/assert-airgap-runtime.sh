#!/usr/bin/env bash
# Positiv-/Negativnachweis für den separaten Zielcluster.
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <kube-context> <allowed-registry-prefix>" >&2
  exit 64
fi

context=$1
allowed_prefix=$2
namespace=target-application

images=$(kubectl --context "$context" -n "$namespace" get pods -o json |
  yq -p=json -r '
    .items[] |
    ((.spec.initContainers // []) + (.spec.containers // []))[] |
    .image
  ' | sort -u)
[[ -n "$images" ]] || { echo 'Keine Workload-Images gefunden.' >&2; exit 1; }

while IFS= read -r image; do
  [[ "$image" == "${allowed_prefix}"/* ]] || {
    echo "Externe Image-Referenz gefunden: ${image}" >&2
    exit 1
  }
done <<< "$images"
printf 'Nur lokale Images:\n%s\n' "$images"

kubectl --context "$context" -n "$namespace" rollout restart deployment/target-application-web
kubectl --context "$context" -n "$namespace" rollout status \
  deployment/target-application-web --timeout=180s

negative_namespace=airgap-negative-test
kubectl --context "$context" create namespace "$negative_namespace" \
  --dry-run=client -o yaml | kubectl --context "$context" apply -f - >/dev/null
kubectl --context "$context" -n "$negative_namespace" delete pod upstream-must-fail \
  --ignore-not-found >/dev/null
kubectl --context "$context" -n "$negative_namespace" run upstream-must-fail \
  --image=registry.k8s.io/e2e-test-images/agnhost:2.53 \
  --restart=Never --command -- /agnhost pause

if kubectl --context "$context" -n "$negative_namespace" wait \
  --for=condition=Ready pod/upstream-must-fail --timeout=45s; then
  echo 'FEHLER: Ein öffentliches Image konnte trotz Air Gap starten.' >&2
  exit 1
fi
kubectl --context "$context" -n "$negative_namespace" get pod upstream-must-fail
kubectl --context "$context" -n "$negative_namespace" describe pod upstream-must-fail |
  sed -n '/Events:/,$p'
echo 'Air-Gap-Nachweis erfolgreich: lokaler Neustart klappt, Upstream-Pull scheitert.'
