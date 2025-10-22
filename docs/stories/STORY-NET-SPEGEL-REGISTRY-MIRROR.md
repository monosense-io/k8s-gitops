# 21 — STORY-NET-SPEGEL-REGISTRY-MIRROR — Node-local OCI Registry Mirror (Flux-managed)

Sequence: 21/41 | Prev: STORY-NET-CILIUM-BGP-CP-IMPLEMENT.md | Next: STORY-DB-CNPG-OPERATOR.md
Sprint: 4 | Lane: Networking
Global Sequence: 21/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/infrastructure/networking/spegel; docs/architecture.md §9, §19

## Story
Deploy Spegel as a cluster-local OCI registry mirror via Flux to provide P2P distributed image caching, reducing external registry bandwidth and improving image pull performance across all nodes.

## Why / Outcome
- **Performance**: Faster image pulls via local mirror (subsequent pulls use cluster-local cache)
- **Resilience**: Cluster continues operating even if external registries are unreachable
- **Cost**: Reduced external registry bandwidth and egress costs
- **Observability**: Metrics and dashboards for cache hit rates and performance

## Scope
- Clusters: infra, apps (both clusters benefit from image caching)
- Location: `kubernetes/infrastructure/networking/spegel/`
- Management: Flux-managed HelmRelease (installed during bootstrap, managed by Flux post-handover)
- Bootstrap: Included in `bootstrap/helmfile.d/01-core.yaml.gotmpl` after CoreDNS

## Talos Compatibility
Spegel is fully compatible with Talos Linux via:
- **Containerd CRI**: Standard containerd runtime
- **Dynamic Registry Config**: `/etc/cri/conf.d/hosts` (Talos supports runtime registry configuration)
- **Host Networking**: HostPort `29999` for local registry endpoint
- **No Persistent Storage**: Stateless in-memory cache

## Acceptance Criteria
1) Spegel DaemonSet Ready on all nodes in both infra and apps clusters
2) OCIRepository + HelmRelease created in `kubernetes/infrastructure/networking/spegel/app/`
3) Flux Kustomization includes proper dependencies (after CoreDNS) and health checks
4) Talos-specific configuration present:
   - `containerdRegistryConfigPath: /etc/cri/conf.d/hosts`
   - `hostPort: 29999` for registry service
5) Observability enabled:
   - ServiceMonitor for Prometheus metrics
   - Grafana dashboard enabled
6) Bootstrap integration validated:
   - Spegel in `bootstrap/helmfile.d/01-core.yaml.gotmpl` after CoreDNS
   - Values template uses single source of truth from HelmRelease
7) Image pull verification:
   - First pull: upstream registry (normal speed)
   - Subsequent pulls: local mirror (faster, shown in containerd logs)
   - Cache hits visible in metrics

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (02): Cilium CNI operational
- STORY-DNS-COREDNS-BASE (05): CoreDNS for cluster DNS resolution
- STORY-OBS-VM-STACK-IMPLEMENT (16): Victoria Metrics for ServiceMonitor scraping

## Tasks / Subtasks
- [ ] T1 — Create Spegel manifests (AC: 2, 4)
  - [ ] Create `kubernetes/infrastructure/networking/spegel/app/helmrelease.yaml`
  - [ ] Create OCIRepository for Spegel Helm chart (oci://ghcr.io/spegel-org/helm-charts/spegel)
  - [ ] Configure Talos-specific settings (containerdRegistryConfigPath, hostPort)
  - [ ] Enable observability (ServiceMonitor, Grafana dashboard)
  - [ ] Create `kubernetes/infrastructure/networking/spegel/app/kustomization.yaml`
- [ ] T2 — Create Flux Kustomization (AC: 1, 3)
  - [ ] Create `kubernetes/infrastructure/networking/spegel/ks.yaml`
  - [ ] Add `dependsOn: cluster-infra-infrastructure-coredns`
  - [ ] Add DaemonSet health check
  - [ ] Add postBuild.substituteFrom for cluster-settings
- [ ] T3 — Update infrastructure Kustomization (AC: 3)
  - [ ] Add `./networking/spegel/ks.yaml` to `kubernetes/infrastructure/kustomization.yaml`
- [ ] T4 — Validate manifests (AC: 2, 3)
  - [ ] `flux build kustomization spegel --path ./kubernetes/infrastructure/networking/spegel`
  - [ ] `kustomize build kubernetes/infrastructure/networking/spegel/app`
  - [ ] `kubectl --dry-run=server apply -k kubernetes/infrastructure/networking/spegel/app`
- [ ] T5 — Deploy and verify (AC: 1, 7)
  - [ ] Deploy to infra cluster: `flux reconcile kustomization spegel --with-source`
  - [ ] Verify DaemonSet: `kubectl -n kube-system get ds spegel -o wide`
  - [ ] Check containerd registry config: `kubectl -n kube-system exec -it ds/spegel -- cat /etc/cri/conf.d/hosts`
  - [ ] Test image pull: pull same image twice, verify cache hit in metrics
  - [ ] Repeat for apps cluster
- [ ] T6 — Bootstrap integration (AC: 6)
  - [ ] Add Spegel to `bootstrap/helmfile.d/01-core.yaml.gotmpl` (after CoreDNS)
  - [ ] Verify values template extracts from HelmRelease
  - [ ] Validate: `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template | grep -A 20 "name: spegel"`

## Validation Steps (CLI)
- Manifest validation:
  - `flux build kustomization spegel --path ./kubernetes/infrastructure/networking/spegel` (no errors)
  - `kustomize build kubernetes/infrastructure/networking/spegel/app | kubectl apply --dry-run=server -f -`
- Deployment health:
  - `kubectl --context=infra -n kube-system rollout status ds/spegel --timeout=5m`
  - `kubectl --context=infra -n kube-system get pods -l app.kubernetes.io/name=spegel`
- Registry configuration:
  - `kubectl --context=infra -n kube-system exec ds/spegel -- ls -la /etc/cri/conf.d/hosts`
  - Verify hostPort: `kubectl --context=infra -n kube-system get svc spegel-registry -o jsonpath='{.spec.ports[?(@.name=="registry")].hostPort}'` (should be 29999)
- Image pull test:
  - Pull test image: `kubectl --context=infra run test-pull --image=nginx:latest --rm -it --restart=Never -- true`
  - Delete pod and re-pull (should be faster, cache hit)
  - Check metrics: `kubectl --context=infra -n kube-system port-forward ds/spegel 8080:8080` → curl localhost:8080/metrics | grep spegel_
- Observability:
  - Verify ServiceMonitor: `kubectl --context=infra -n kube-system get servicemonitor spegel`
  - Check Prometheus targets: Spegel endpoints should be UP
  - Grafana: Spegel dashboard available

## Rollback
- Suspend Kustomization: `flux suspend kustomization spegel`
- Remove from infrastructure kustomization: edit `kubernetes/infrastructure/kustomization.yaml`
- Delete DaemonSet: `kubectl -n kube-system delete ds spegel`
- Remove containerd registry config: automatic cleanup on DaemonSet deletion

## Definition of Done
- All Acceptance Criteria met on both infra and apps clusters
- Spegel DaemonSet running on all nodes
- Image pull performance improvement documented (first vs subsequent pull times)
- Metrics dashboard showing cache hit rate
- Dev Notes include cache hit rate and performance comparison

## Dev Notes
Spegel provides cluster-local OCI image mirroring via P2P distribution:
- **First Pull**: Image pulled from upstream registry (ghcr.io, docker.io, etc.)
- **Spegel Cache**: Image cached on the node that pulled it
- **Subsequent Pulls**: Other nodes pull from local Spegel mirror (P2P), not upstream
- **Performance**: ~10x faster for cached images (local network vs internet)

Talos configuration is handled automatically via:
- Containerd CRI: Standard Kubernetes CRI interface
- Registry config path: `/etc/cri/conf.d/hosts` (dynamic, no machine config changes)
- Spegel DaemonSet creates per-node registry configurations

Bootstrap integration ensures Spegel is operational before cert-manager and Flux install, improving bootstrap speed for all subsequent components.
