# 22 — STORY-NET-SPEGEL-REGISTRY-MIRROR — Node-local OCI Registry Mirror (Flux-managed)

Sequence: 22/23 | Prev: STORY-OBS-FLUENT-BIT.md | Next: STORY-BACKUP-VOLSYNC-APPS.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/registry/spegel; kubernetes/bases/spegel; kubernetes/clusters/infra/spegel.yaml; docs/architecture.md §12

## Story
Deploy Spegel as a node‑local OCI registry mirror via Flux to reduce image pull latency and external bandwidth, with per‑node caching and metrics.

## Why / Outcome
- Faster, more reliable image pulls; resiliency during upstream outages; lower egress.

## Scope
- Clusters: infra (primary), apps (optional)
- Resources: `bases/spegel` HelmRelease; Kustomization `networking/spegel/ks.yaml` (GitOps‑managed)

## Acceptance Criteria
1) Spegel DaemonSet Ready across cluster nodes; ServiceMonitor enabled and scraping.
2) Pull‑through caching verified: repeated image pulls show cache hits; upstream fallbacks documented.
3) No bootstrap (Helmfile) install of Spegel; management is solely via Flux.

## Dependencies / Inputs
- Networking: Cilium CNI (Story 04) operational.
- Node image policies & containerd config compatible with Spegel mirror endpoints (document any required CRI settings). No PVCs required (stateless cache).

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/infrastructure/kustomization.yaml` and ensure `networking/spegel/ks.yaml` is included.
- [ ] Validate persistence and ServiceMonitor; tune cache size and eviction.
- [ ] Add basic docs on using Spegel endpoints in cluster image pull config (optional).

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks spegel --with-source
- kubectl --context=<ctx> -n kube-system get ds spegel
- Verify hostPort 29999 open on nodes; confirm `/etc/cri/conf.d/hosts` populated
- Observe cache hits via metrics/logs while pulling a common image repeatedly.

## Definition of Done
- ACs met; Dev Notes include metrics snapshots and pull timing comparison.
