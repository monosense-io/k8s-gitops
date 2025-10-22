# 30 — STORY-STO-APPS-OPENEBS-BASE — OpenEBS LocalPV (apps)

Sequence: 30/41 | Prev: STORY-SEC-SPIRE-CILIUM-AUTH.md | Next: STORY-STO-APPS-ROOK-CEPH-OPERATOR.md
Sprint: 6 | Lane: Storage
Global Sequence: 30/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/clusters/apps/infrastructure.yaml; kubernetes/infrastructure/storage/openebs

## Story
Deploy OpenEBS LocalPV on the apps cluster to provide node-local storage for workloads and cache-like use cases, eliminating dependency on infra storage across a 1 Gbps L3 link.

## Acceptance Criteria
1) `openebs-localpv-provisioner` DaemonSet Ready in `openebs-system` on apps.
2) StorageClass `${OPENEBS_STORAGE_CLASS}` present; dynamic provisioning binds a test PVC/Pod.

## Dependencies
- Flux repositories synced; cluster settings populated with `OPENEBS_*` values.

## Tasks
- [ ] Reconcile `openebs` Kustomization defined in `kubernetes/clusters/apps/infrastructure.yaml`.
- [ ] Deploy a small PVC/Pod to validate provisioning.

## Validation Steps
- flux -n flux-system --context=apps reconcile kustomization openebs --with-source
- kubectl --context=apps -n openebs-system get ds openebs-localpv-provisioner
- kubectl --context=apps get sc | grep ${OPENEBS_STORAGE_CLASS}
