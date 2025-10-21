# 12 — STORY-NET-CILIUM-CLUSTERMESH — Cross-Cluster Connectivity

Sequence: 12/22 | Prev: STORY-NET-CILIUM-BGP.md | Next: STORY-BOOT-AUTOMATION-ALIGN.md

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
1) ExternalSecret syncs clustermesh secret on both clusters.
2) `cilium clustermesh status --context apps` shows Connected to infra (and vice versa).

## Dependencies / Inputs
- STORY-SEC-EXTERNAL-SECRETS-BASE (ClusterSecretStore), STORY-NET-CILIUM-CORE-GITOPS.
- 1Password items exist per cluster path in `cluster-settings`.

## Tasks / Subtasks
- [ ] Confirm ExternalSecret template/population paths.
- [ ] Validate `cilium clustermesh status` both directions.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-clustermesh-secret --with-source
- cilium clustermesh status --context <ctx>

## Definition of Done
- ACs met; Dev Notes include command outputs.
