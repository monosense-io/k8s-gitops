# 04 — STORY-NET-CILIUM-CORE-GITOPS — Put Cilium Core under GitOps Control

Sequence: 04/21 | Prev: STORY-BOOT-CORE.md | Next: STORY-SEC-EXTERNAL-SECRETS-BASE.md

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
2) Per‑cluster settings are substituted from `cluster-settings` (`CLUSTER`, `CLUSTER_ID`, `POD_CIDR_STRING`, etc.).
3) After initial bootstrap, uninstalling the imperatively installed Cilium release and reconciling Flux recreates Cilium and the operator (proves Git is canonical).
4) Health checks: Flux Kustomization shows Ready; `kubectl -n kube-system get ds/dep` for Cilium and operator report ready across nodes.

## Tasks / Subtasks
- [ ] Create HelmRelease (`core/helmrelease.yaml`) using `chartRef: cilium-charts` and cluster‑scoped values.
- [ ] Create Kustomization (`core/ks.yaml`) with health checks on DaemonSet and operator Deployment.
- [ ] Add `networking/cilium/core/ks.yaml` to `kubernetes/infrastructure/kustomization.yaml` before day‑2 features.
- [ ] Validate on infra and apps: Flux reconciles and Cilium stays healthy.

## Validation Steps
- flux --context=<ctx> reconcile kustomization cilium-core -n flux-system --with-source
- kubectl --context=<ctx> -n kube-system rollout status daemonset/cilium --timeout=5m
- kubectl --context=<ctx> -n kube-system rollout status deploy/cilium-operator --timeout=5m

## Dev Notes
- Initial bootstrap of Cilium is still required to allow Flux controllers to start; see `.taskfiles/bootstrap/Taskfile.yaml` `core:gitops`.
- `kubernetes/infrastructure/cilium/ocirepository.yaml` semver aligned to 1.18.x for parity with bootstrap values.
