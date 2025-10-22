# 26 — STORY-STO-APPS-ROOK-CEPH-CLUSTER — Ceph Cluster (apps)

Sequence: 26/26 | Prev: STORY-STO-APPS-ROOK-CEPH-OPERATOR.md
Sprint: 6 | Lane: Storage
Global Sequence: 36/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/clusters/apps/infrastructure.yaml; kubernetes/infrastructure/storage/rook-ceph/cluster; kubernetes/bases/rook-ceph-cluster/cephcluster.yaml

## Story
Deploy a local Rook-Ceph cluster on apps nodes (apps-01..03) with device-by-id NVMe configuration to avoid L3 traffic through a 1 Gbps router.

## Acceptance Criteria
1) `CephCluster` HEALTH_OK (or WARN with documented rebalancing waiver), MON/MGR Ready.
2) StorageClass `${CEPH_BLOCK_STORAGE_CLASS}` present; PVC provisioning works on apps.
3) Toolbox pod operational for diagnostics; PrometheusRules loaded.

## Dependencies
- STORY-STO-APPS-ROOK-CEPH-OPERATOR; device IDs in cluster patch validated against hosts.

## Tasks
- [ ] Reconcile `rook-ceph-cluster` Kustomization in apps infrastructure.
- [ ] Validate PVC provisioning and Ceph status.

## Validation Steps
- kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
- kubectl --context=apps get sc | grep ${CEPH_BLOCK_STORAGE_CLASS}
