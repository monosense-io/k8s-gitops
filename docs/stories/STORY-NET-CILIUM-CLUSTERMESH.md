# 12 — STORY-NET-CILIUM-CLUSTERMESH — Cross-Cluster Connectivity

Sequence: 12/26 | Prev: STORY-NET-CILIUM-BGP.md | Next: STORY-BOOT-AUTOMATION-ALIGN.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §20; kubernetes/infrastructure/networking/cilium/clustermesh; kubernetes/infrastructure/networking/cilium/ks.yaml

## Story
Enable Cilium ClusterMesh between infra and apps using a shared ExternalSecret for the clustermesh config, managed by Flux.

## Why / Outcome
- Cross-cluster service discovery and connectivity without sidecars.

## Scope
- Resources: `kubernetes/infrastructure/networking/cilium/clustermesh/*` (ExternalSecret + config), secrets from 1Password.

## Acceptance Criteria
1) ExternalSecret syncs clustermesh secret on both clusters using `${CILIUM_CLUSTERMESH_SECRET_PATH}`.
2) `cilium clustermesh status` shows Connected in both directions; cross‑cluster DNS/service discovery works.

## Dependencies / Inputs
- STORY-SEC-EXTERNAL-SECRETS-BASE (ClusterSecretStore), STORY-NET-CILIUM-CORE-GITOPS.
- 1Password items exist per cluster path in `cluster-settings`.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Author (later) under `kubernetes/infrastructure/networking/cilium/clustermesh/`:
  - `externalsecret.yaml` referencing `${CILIUM_CLUSTERMESH_SECRET_PATH}`.
  - `ks.yaml` entry is present and substitutes cluster-settings.
- [ ] Validation (later): `cilium clustermesh status`, and curl between namespaces across clusters using `cluster.local` names.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-clustermesh-secret --with-source
- cilium clustermesh status --context <ctx>

## Definition of Done
- ACs met; Dev Notes include command outputs.

---

## Design — ClusterMesh (Story‑Only)

- Enablement: Use Cilium 1.18.2 Helm values to enable clustermesh components; manage secrets via ExternalSecrets.
- Prereqs: Non‑overlapping PodCIDRs per cluster; consistent CNI settings; L3 reachability between mesh components.
- Validation: `cilium clustermesh status` shows Connected both ways.
