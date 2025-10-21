#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/validate-crd-waitset.sh <context>
CTX="${1:-}"
if [[ -z "$CTX" ]]; then
  echo "Usage: $0 <kube-context>" >&2
  exit 2
fi

echo "Validating CRD waitset in context: $CTX"

wait_crd() {
  local crd="$1"
  if kubectl --context="$CTX" get crd "$crd" &>/dev/null; then
    kubectl --context="$CTX" wait --for=condition=Established "crd/${crd}" --timeout=120s
    printf '  ✓ %s Established\n' "$crd"
  else
    printf '  ✗ %s not found\n' "$crd" >&2
    exit 1
  fi
}

# monitoring.coreos.com
wait_crd prometheusrules.monitoring.coreos.com
wait_crd servicemonitors.monitoring.coreos.com
wait_crd podmonitors.monitoring.coreos.com

# external-secrets.io
wait_crd externalsecrets.external-secrets.io
wait_crd secretstores.external-secrets.io
wait_crd clustersecretstores.external-secrets.io

# cert-manager.io
wait_crd issuers.cert-manager.io
wait_crd clusterissuers.cert-manager.io
wait_crd certificates.cert-manager.io

# gateway.networking.k8s.io
wait_crd gateways.gateway.networking.k8s.io
wait_crd gatewayclasses.gateway.networking.k8s.io
wait_crd httproutes.gateway.networking.k8s.io

echo "All required CRDs Established in context: $CTX"

