# 12 — STORY-STO-ROOK-CEPH-CLUSTER — Ceph Cluster (infra)

Sequence: 12/41 | Prev: STORY-STO-ROOK-CEPH-OPERATOR.md | Next: STORY-OBS-VM-STACK.md
Sprint: 3 | Lane: Storage
Global Sequence: 12/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/rook-ceph/cluster; kubernetes/infrastructure/storage/rook-ceph/BACKUP_DISASTER_RECOVERY.md

## Story
Deploy the Rook-Ceph cluster on the infra nodes with the desired MON/MGR/OSD topology and expose a default RBD StorageClass for platform use.

## Why / Outcome
- Highly available, durable storage backend for databases and observability.

## Scope
- Cluster: infra
- Resources: `kubernetes/infrastructure/storage/rook-ceph/cluster/*` (bases/rook-ceph-cluster) + PrometheusRules

## Acceptance Criteria
1) `ceph -s` shows HEALTH_OK (or WARN with documented waiver during initial rebalance).
2) StorageClass `${CEPH_BLOCK_STORAGE_CLASS}` exists and binds PVCs.
3) Toolbox Pod operational for inspection.
4) Backup/DR document `BACKUP_DISASTER_RECOVERY.md` referenced in Dev Notes.

## Dependencies / Inputs
- STORY-STO-ROOK-CEPH-OPERATOR; devices prepared per node; `${ROOK_CEPH_*}` settings in `cluster-settings`.

## Tasks / Subtasks
- [ ] Reconcile cluster manifests; monitor rollout.
- [ ] Validate PV provisioning and Ceph status.

## Validation Steps
- kubectl --context=infra -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
- kubectl --context=infra get sc | grep ${CEPH_BLOCK_STORAGE_CLASS}

## Definition of Done
- ACs met with logs/commands stored in Dev Notes.
