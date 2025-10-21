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

- Sprint 3 (Nov 24–Dec 05, 2025)
  - STORY-STO-OPENEBS-BASE (infra)
  - STORY-STO-ROOK-CEPH-OPERATOR (infra)

- Sprint 4 (Dec 08–Dec 19, 2025)
  - STORY-STO-ROOK-CEPH-CLUSTER (infra)
  - STORY-DB-CNPG-OPERATOR (infra)
  - STORY-DB-CNPG-SHARED-CLUSTER (infra)

- Sprint 5 (Jan 05–Jan 16, 2026)
  - STORY-OBS-VM-STACK (infra+apps)
  - STORY-OBS-VICTORIA-LOGS (infra)
  - STORY-OBS-FLUENT-BIT (infra+apps)

- Sprint 6 (Jan 19–Jan 30, 2026)
  - STORY-NET-SPEGEL-REGISTRY-MIRROR (after OpenEBS is available)

## Sequencing & Dependencies

- BOOT-CRDS → BOOT-CORE → CILIUM-CORE-GITOPS
- EXTERNAL-SECRETS-BASE → CERT-MANAGER-ISSUERS → (enables TLS for Gateway)
- CILIUM-CORE-GITOPS → (IPAM | Gateway | BGP | ClusterMesh)
- GITOPS-SELF-MGMT-FLUX can run alongside Sprint 1 items after BOOT-CORE
- Storage/DB: OPENEBS → ROOK-OP → ROOK-CLUSTER → CNPG-OP → CNPG-SHARED
- Observability: VM-STACK (operator/vmcluster/vmalert/grafana) → VICTORIA-LOGS → FLUENT-BIT

## Milestones

- M1 (End Sprint 0): Flux managing core on both clusters; Cilium under GitOps.
- M2 (End Sprint 1): Secrets/TLS/DNS foundations complete; Flux self‑managed.
- M3 (End Sprint 2): Networking day‑2 (IPAM, Gateway, BGP, Mesh) operational.
- M4 (End Sprint 4): Durable storage and shared Postgres available.
- M5 (End Sprint 5): Centralized metrics/logs with dashboards and alerts.
