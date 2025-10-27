# 11 — STORY-NET-SPEGEL-REGISTRY-MIRROR — Create Spegel Registry Mirror Manifests

Sequence: 11/50 | Prev: STORY-NET-CILIUM-BGP-CP-IMPLEMENT.md | Next: STORY-NET-CILIUM-CLUSTERMESH.md
Sprint: 4 | Lane: Networking
Global Sequence: 11/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §9, §19; kubernetes/infrastructure/networking/spegel/

---

## Story

As a platform engineer, I want to **create Spegel registry mirror manifests** for node-local OCI image caching, so that when deployed in Story 45, clusters provide P2P distributed image mirroring, reducing external registry bandwidth and improving image pull performance across all nodes.

This story creates the declarative Spegel manifests (HelmRelease, OCIRepository, ServiceMonitor). Actual deployment and image caching validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create Spegel manifests for GitOps deployment
- Enable P2P distributed image caching across cluster nodes
- Reduce external registry bandwidth and improve pull performance
- Support Talos Linux with containerd CRI integration
- Foundation for resilient cluster operations (offline capability)

## Scope

**This Story (Manifest Creation):**
- Create Spegel manifests in `kubernetes/infrastructure/networking/spegel/app/`
- Create HelmRelease for Spegel with Talos-specific configuration
- Create OCIRepository for Spegel Helm chart
- Create ServiceMonitor for observability
- Create Kustomization for Spegel resources
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying Spegel to clusters
- Verifying DaemonSet running on all nodes
- Testing image pull performance (cache hits)
- Validating containerd registry configuration
- Metrics scraping validation

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/infrastructure/networking/spegel/app/helmrelease.yaml` exists
   - Spegel chart version configured
   - Namespace: `kube-system`
   - Talos-specific configuration:
     - `containerdRegistryConfigPath: /etc/cri/conf.d/hosts`
     - `hostPort: 29999`
   - ServiceMonitor enabled
   - Grafana dashboard enabled

2. **OCIRepository Manifest Created:**
   - OCIRepository defined in same file as HelmRelease
   - References Spegel chart from `oci://ghcr.io/spegel-org/helm-charts/spegel`
   - Chart version specified

3. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/spegel/ks.yaml` exists
   - References Spegel manifests
   - Includes dependency on `coredns`
   - DaemonSet health check configured
   - `kubernetes/infrastructure/networking/spegel/app/kustomization.yaml` glue file exists

4. **Infrastructure Kustomization Updated:**
   - `kubernetes/infrastructure/networking/kustomization.yaml` includes `spegel/ks.yaml`

5. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `kubectl --dry-run=client` validates manifests
   - Output shows Spegel resources for both clusters

**Deferred to Story 45 (Deployment & Validation):**
- ❌ Spegel DaemonSet running on all nodes
- ❌ Containerd registry config created at `/etc/cri/conf.d/hosts`
- ❌ Image pull performance improvement verified
- ❌ Cache hit metrics available
- ❌ ServiceMonitor scraping metrics

---

## Dependencies

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium CNI manifests created)
- Story 04 (STORY-DNS-COREDNS-BASE) complete (CoreDNS manifests created)
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ VictoriaMetrics deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  ```

- [ ] Verify Story 04 complete (CoreDNS manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/coredns/helmrelease.yaml
  ```

---

### T2: Create Spegel Manifests

- [ ] Create directory structure:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/spegel/app
  ```

- [ ] Create `helmrelease.yaml`:
  ```yaml
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: OCIRepository
  metadata:
    name: spegel
    namespace: kube-system
  spec:
    interval: 15m
    layerSelector:
      mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
      operation: copy
    ref:
      tag: v0.0.28
    url: oci://ghcr.io/spegel-org/helm-charts/spegel
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: spegel
    namespace: kube-system
  spec:
    chartRef:
      kind: OCIRepository
      name: spegel
      namespace: kube-system
    interval: 1h
    install:
      remediation:
        retries: 2
      createNamespace: false  # kube-system already exists
    upgrade:
      remediation:
        retries: 2
        strategy: rollback
      cleanupOnFail: true
    rollback:
      recreate: true
      cleanupOnFail: true
    values:
      fullnameOverride: spegel

      # Talos Linux compatibility
      spegel:
        containerdRegistryConfigPath: /etc/cri/conf.d/hosts

      # Host networking for registry endpoint
      service:
        registry:
          hostPort: 29999

      # Observability
      serviceMonitor:
        enabled: true
        namespace: kube-system

      grafanaDashboard:
        enabled: true
        namespace: kube-system
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: spegel
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/spegel/app
    prune: true
    wait: true
    dependsOn:
      - name: coredns
    targetNamespace: kube-system
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: spegel
        namespace: kube-system
      - apiVersion: apps/v1
        kind: DaemonSet
        name: spegel
        namespace: kube-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/spegel/app/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/spegel/app
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "spegel")'

  # Apps cluster
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "spegel")'
  ```

- [ ] Verify Talos-specific configuration:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "spegel") | .spec.values.spegel.containerdRegistryConfigPath'
  # Expected: /etc/cri/conf.d/hosts
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/networking/kustomization.yaml`:
  ```yaml
  resources:
    - cilium/kustomization.yaml
    - coredns/ks.yaml
    - spegel/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/spegel/
  git commit -m "feat(networking): add Spegel registry mirror manifests

  - Create HelmRelease for Spegel v0.0.28
  - Configure Talos-specific containerd registry config path
  - Enable ServiceMonitor and Grafana dashboard
  - Configure hostPort 29999 for registry endpoint
  - Add dependency on CoreDNS
  - Enable P2P distributed image caching

  Part of Story 11 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy Spegel (Story 45 only)
flux reconcile kustomization spegel --with-source

# Verify DaemonSet
kubectl -n kube-system get ds spegel -o wide
kubectl -n kube-system rollout status ds/spegel --timeout=5m

# Verify pods running on all nodes
kubectl -n kube-system get pods -l app.kubernetes.io/name=spegel -o wide
# Expected: One pod per node in Running state

# Verify containerd registry config
kubectl -n kube-system exec -it ds/spegel -- ls -la /etc/cri/conf.d/hosts
# Expected: Registry configuration files present

# Verify hostPort configuration
kubectl -n kube-system get svc spegel-registry -o jsonpath='{.spec.ports[?(@.name=="registry")].hostPort}'
# Expected: 29999

# Test image pull performance (cache hit)
# First pull (upstream registry)
time kubectl run test-pull-1 --image=nginx:alpine --rm -it --restart=Never -- true
# Record time

# Second pull (should use Spegel cache)
time kubectl run test-pull-2 --image=nginx:alpine --rm -it --restart=Never -- true
# Record time - should be significantly faster

# Delete and pull again to verify persistent cache
kubectl delete pod test-pull-2 --force --grace-period=0 2>/dev/null || true
time kubectl run test-pull-3 --image=nginx:alpine --rm -it --restart=Never -- true
# Should still be fast (cache hit)

# Verify metrics
kubectl -n kube-system port-forward ds/spegel 8080:8080 &
sleep 2
curl http://localhost:8080/metrics | grep -E "spegel_(image_|registry_)"
# Expected metrics:
# - spegel_image_pull_total
# - spegel_registry_request_total
# - spegel_registry_request_duration_seconds

# Verify ServiceMonitor
kubectl -n kube-system get servicemonitor spegel
kubectl -n kube-system get servicemonitor spegel -o jsonpath='{.spec.selector.matchLabels}'

# Check Prometheus targets (if VictoriaMetrics deployed)
kubectl -n observability port-forward svc/victoria-metrics-stack-victoria-metrics 8428:8428 &
sleep 2
curl -s http://localhost:8428/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="spegel")'
# Expected: Spegel endpoints UP

# Verify cache hit rate after several pulls
for i in {1..5}; do
  kubectl run test-pull-$i --image=nginx:alpine --rm --restart=Never -- true
  sleep 1
done

curl http://localhost:8080/metrics | grep spegel_image_pull_total
# Verify counter increased

# Cleanup port-forwards
pkill -f "port-forward.*spegel"
pkill -f "port-forward.*victoria-metrics"

# Test with different image
time kubectl run test-alpine-1 --image=alpine:latest --rm -it --restart=Never -- true
time kubectl run test-alpine-2 --image=alpine:latest --rm -it --restart=Never -- true
# Second pull should be faster

# Verify Grafana dashboard (if Grafana deployed)
kubectl -n observability get configmap spegel-dashboard
# Expected: Grafana dashboard ConfigMap exists
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/networking/spegel/app/`
- [ ] HelmRelease manifest created with:
  - [ ] Spegel version v0.0.28
  - [ ] Talos containerd registry config path
  - [ ] HostPort 29999 configured
  - [ ] ServiceMonitor enabled
  - [ ] Grafana dashboard enabled
- [ ] OCIRepository manifest created
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with dependencies and health checks
- [ ] Infrastructure networking kustomization updated to include Spegel
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows Spegel resources for both clusters
  - [ ] Talos-specific config verified in output
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ Spegel DaemonSet running on all nodes
- ❌ Containerd registry config created at `/etc/cri/conf.d/hosts`
- ❌ Image pull performance improvement verified
- ❌ Cache hit metrics available
- ❌ ServiceMonitor scraping metrics
- ❌ Grafana dashboard populated with data
- ❌ P2P image distribution working across nodes

---

## Dev Notes

### Spegel Architecture

Spegel provides cluster-local OCI image mirroring via P2P distribution:
- **First Pull**: Image pulled from upstream registry (ghcr.io, docker.io, etc.)
- **Spegel Cache**: Image cached on the node that pulled it
- **Subsequent Pulls**: Other nodes pull from local Spegel mirror (P2P), not upstream
- **Performance**: ~10x faster for cached images (local network vs internet)

### Talos Linux Compatibility

Talos configuration is handled automatically via:
- **Containerd CRI**: Standard Kubernetes CRI interface
- **Registry Config Path**: `/etc/cri/conf.d/hosts` (dynamic, no machine config changes)
- **Spegel DaemonSet**: Creates per-node registry configurations automatically
- **Host Networking**: HostPort 29999 provides local registry endpoint

### Bootstrap Integration

Spegel is deployed via Flux but can optionally be included in bootstrap for faster initial cluster setup. The manifests created in this story provide the single source of truth for both Flux and bootstrap deployments.

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T6 focusing on local validation only. Added comprehensive image caching and performance testing in runtime validation section. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
