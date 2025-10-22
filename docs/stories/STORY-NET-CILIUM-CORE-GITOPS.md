# 04 — STORY-NET-CILIUM-CORE-GITOPS — Put Cilium Core under GitOps Control

Sequence: 04/26 | Prev: STORY-BOOT-CORE.md | Next: STORY-SEC-EXTERNAL-SECRETS-BASE.md
Sprint: 2 | Lane: Networking
Global Sequence: 8/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/core; .taskfiles/bootstrap/Taskfile.yaml

## Story
As a platform team, we want Cilium (CNI + operator) to be managed declaratively by Flux so that desired state for the network layer is versioned, auditable, and consistent across clusters. We will perform a one‑time imperative install of Cilium during cluster bring‑up, then hand control to Flux HelmRelease.

## Acceptance Criteria
1) GitOps resources exist and are wired:
   - `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` references `OCIRepository cilium-charts`.
   - `kubernetes/infrastructure/networking/cilium/core/ks.yaml` is included by `kubernetes/infrastructure/kustomization.yaml`.
2) Per‑cluster settings are substituted from `cluster-settings` (`CLUSTER`, `CLUSTER_ID`, `POD_CIDR_STRING`, etc.). Chart version pinned to Cilium 1.18.2 across clusters.
3) After initial bootstrap, uninstalling the imperatively installed Cilium release and reconciling Flux recreates Cilium and the operator (proves Git is canonical).
4) Health checks: Flux Kustomization shows Ready; `kubectl -n kube-system get ds/dep` for Cilium and operator report ready across nodes.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Author HelmRelease (`kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`) pinned to `1.18.2` with:
  - `kubeProxyReplacement: "true"`, `gatewayAPI.enabled: true`, `bgpControlPlane.enabled: true`, `prometheus.serviceMonitor.enabled: true`.
  - Per‑cluster `ipv4NativeRoutingCIDR`, `cluster.id/name` from cluster-settings.
- [ ] Author Kustomization (`kubernetes/infrastructure/networking/cilium/core/ks.yaml`) with health checks on `DaemonSet/cilium` and `Deployment/cilium-operator`.
- [ ] Ensure infra‑level `kubernetes/infrastructure/kustomization.yaml` includes `networking/cilium/core/ks.yaml` before IPAM/Gateway/BGP/ClusterMesh Kustomizations.
- [ ] Validate (later) on infra and apps that Flux reconciles and Cilium stays healthy.

## Validation Steps
- flux --context=<ctx> reconcile kustomization cilium-core -n flux-system --with-source
- kubectl --context=<ctx> -n kube-system rollout status daemonset/cilium --timeout=5m
- kubectl --context=<ctx> -n kube-system rollout status deploy/cilium-operator --timeout=5m

## Dev Notes
- Initial bootstrap of Cilium is still required to allow Flux controllers to start; see `.taskfiles/bootstrap/Taskfile.yaml` `core:gitops`.
- `kubernetes/infrastructure/cilium/ocirepository.yaml` semver aligned to 1.18.2 for parity with bootstrap values.

---

## Design — Core (Story‑Only)

- Install: Bootstrap Cilium, then hand over to Flux HelmRelease. Keep immutable OS defaults; leverage eBPF and kube‑proxy replacement.
- Feature flags: kube‑proxy replacement (strict), Hubble, Gateway API, BGP Control Plane, LB IPAM; enable per cluster as needed.
