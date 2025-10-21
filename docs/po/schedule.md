# PO Schedule — Bootstrap to Day‑2 (Option A GitOps‑First)

Status: Planned
Owner: Product Owner
Date: 2025-10-21

## Sprint Plan

- Sprint 0 (Oct 21–Oct 24, 2025)
  - STORY-BOOT-CRDS — PASS (done)
  - STORY-BOOT-CORE — Phase 1 GitOps handover (Cilium bootstrap + Flux install)
  - STORY-NET-CILIUM-CORE-GITOPS — Put Cilium under GitOps control

- Sprint 1 (Oct 27–Nov 07, 2025)
  - STORY-SEC-EXTERNAL-SECRETS-BASE
  - STORY-SEC-CERT-MANAGER-ISSUERS
  - STORY-DNS-COREDNS-BASE
  - STORY-GITOPS-SELF-MGMT-FLUX

- Sprint 2 (Nov 10–Nov 21, 2025)
  - STORY-NET-CILIUM-IPAM
  - STORY-NET-CILIUM-GATEWAY
  - STORY-NET-CILIUM-BGP
  - STORY-NET-CILIUM-CLUSTERMESH

## Sequencing & Dependencies

- BOOT-CRDS → BOOT-CORE → CILIUM-CORE-GITOPS
- EXTERNAL-SECRETS-BASE → CERT-MANAGER-ISSUERS → (enables TLS for Gateway)
- CILIUM-CORE-GITOPS → (IPAM | Gateway | BGP | ClusterMesh)
- GITOPS-SELF-MGMT-FLUX can run alongside Sprint 1 items after BOOT-CORE

## Milestones

- M1 (End Sprint 0): Flux managing core on both clusters; Cilium under GitOps.
- M2 (End Sprint 1): Secrets/TLS/DNS foundations complete; Flux self‑managed.
- M3 (End Sprint 2): Networking day‑2 (IPAM, Gateway, BGP, Mesh) operational.

