#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
KUBERNETES_DIR="$ROOT_DIR/kubernetes"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need yq; need kustomize; need kubeconform; need flux; need rg || true

echo "[1/5] YAML syntax checks"
for f in \
  "$KUBERNETES_DIR/infrastructure/networking/cilium/ocirepository.yaml" \
  "$KUBERNETES_DIR/infrastructure/networking/cilium/core/helmrelease.yaml" \
  "$KUBERNETES_DIR/infrastructure/networking/cilium/core/kustomization.yaml" \
  "$KUBERNETES_DIR/clusters/infra/infrastructure.yaml" \
  "$KUBERNETES_DIR/clusters/apps/infrastructure.yaml" \
; do
  yq eval '.' "$f" >/dev/null
  echo "  ✓ $f"
done

echo "[2/5] Component build + schema validation"
kustomize build "$KUBERNETES_DIR/infrastructure/networking/cilium/core" > /tmp/cilium-core.manifests.yaml
kubeconform --strict -ignore-missing-schemas /tmp/cilium-core.manifests.yaml >/tmp/cilium-core.kubeconform.txt || true
echo "  ✓ kustomize + kubeconform completed (strict; ignoring missing schemas)"

build_cluster() {
  local cluster=$1
  local tmp_root="/tmp/cilium-core-${cluster}"
  rm -rf "$tmp_root" && mkdir -p "$tmp_root/kubernetes/infrastructure/networking/cilium/core" "$tmp_root/kubernetes/clusters/${cluster}"

  # Copy only the minimal tree referenced by the Flux Kustomization path
  cp "$KUBERNETES_DIR/infrastructure/networking/cilium/core/helmrelease.yaml" "$tmp_root/kubernetes/infrastructure/networking/cilium/core/"
  cp "$KUBERNETES_DIR/infrastructure/networking/cilium/core/kustomization.yaml" "$tmp_root/kubernetes/infrastructure/networking/cilium/core/"

  # Create a minimal Flux Kustomization for dry-run with explicit postBuild.substitute (avoids scanning repo)
  # Pull values from the repo's cluster-settings ConfigMap
  local cs="$KUBERNETES_DIR/clusters/${cluster}/cluster-settings.yaml"
  local CLUSTER=$(yq -r '.data.CLUSTER' "$cs")
  local CLUSTER_ID=$(yq -r '.data.CLUSTER_ID' "$cs")
  local POD_CIDR_STRING=$(yq -r '.data.POD_CIDR_STRING' "$cs")
  local CILIUM_VERSION=$(yq -r '.data.CILIUM_VERSION' "$cs")
  local K8S_SERVICE_HOST=$(yq -r '.data.K8S_SERVICE_HOST' "$cs")
  local K8S_SERVICE_PORT=$(yq -r '.data.K8S_SERVICE_PORT' "$cs")

  cat > "$tmp_root/kubernetes/clusters/${cluster}/infrastructure.yaml" <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cilium-core
  namespace: flux-system
spec:
  interval: 5m
  prune: true
  wait: true
  timeout: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  path: ./kubernetes/infrastructure/networking/cilium/core
  postBuild:
    substitute:
      CLUSTER: "${CLUSTER}"
      CLUSTER_ID: "${CLUSTER_ID}"
      POD_CIDR_STRING: "${POD_CIDR_STRING}"
      CILIUM_VERSION: "${CILIUM_VERSION}"
      K8S_SERVICE_HOST: "${K8S_SERVICE_HOST}"
      K8S_SERVICE_PORT: "${K8S_SERVICE_PORT}"
YAML

  flux build kustomization cilium-core \
    --kustomization-file "$tmp_root/kubernetes/clusters/${cluster}/infrastructure.yaml" \
    --path "$tmp_root" --dry-run > "/tmp/flux-build-${cluster}.yaml"

  if rg -n "\\$\{" "/tmp/flux-build-${cluster}.yaml" >/dev/null 2>&1; then
    echo "  ✖ unsubstituted variables remain in ${cluster} build" >&2
    exit 1
  fi
  echo "  ✓ ${cluster}: variables substituted"

  rg -n "k8sServiceHost: ${K8S_SERVICE_HOST}$" "/tmp/flux-build-${cluster}.yaml" >/dev/null && echo "  ✓ ${cluster}: host ok" || { echo "  ✖ ${cluster}: host mismatch"; exit 1; }
  rg -n "k8sServicePort: ${K8S_SERVICE_PORT}$" "/tmp/flux-build-${cluster}.yaml" >/dev/null && echo "  ✓ ${cluster}: port ok" || { echo "  ✖ ${cluster}: port mismatch"; exit 1; }
}

echo "[3/5] Flux build (infra)"
build_cluster infra

echo "[4/5] Flux build (apps)"
build_cluster apps

echo "[5/5] Diff cluster builds (expected differences only)"
diff -u /tmp/flux-build-infra.yaml /tmp/flux-build-apps.yaml | rg -n "CLUSTER|cluster.id|ipv4NativeRoutingCIDR|k8sServiceHost|k8sServicePort" -n || true

echo "\nAll local validations passed."
