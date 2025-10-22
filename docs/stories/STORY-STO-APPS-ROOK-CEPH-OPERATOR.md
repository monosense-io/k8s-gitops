# 25 — STORY-STO-APPS-ROOK-CEPH-OPERATOR — Rook-Ceph Operator (apps)

Sequence: 25/26 | Prev: STORY-STO-APPS-OPENEBS-BASE.md | Next: STORY-STO-APPS-ROOK-CEPH-CLUSTER.md
Sprint: 6 | Lane: Storage
Global Sequence: 35/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/clusters/apps/infrastructure.yaml; kubernetes/infrastructure/storage/rook-ceph/operator

## Story
Deploy the Rook-Ceph operator on the apps cluster to manage a local Ceph cluster for high-performance app storage.

## Acceptance Criteria
1) `rook-ceph-operator` Deployment Available in `rook-ceph` namespace on apps.
2) Operator metrics exposed and scraped; no CrashLoopBackoffs.

## Dependencies
- OpenEBS not strictly required; ensure node disks available and cluster settings `ROOK_CEPH_*` set.

## Tasks
- [ ] Reconcile `rook-ceph-operator` Kustomization in apps infrastructure.
- [ ] Verify logs/health and readiness.

## Validation Steps
- flux -n flux-system --context=apps reconcile kustomization rook-ceph-operator --with-source
- kubectl --context=apps -n rook-ceph get deploy rook-ceph-operator
