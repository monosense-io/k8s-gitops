# 14 — STORY-STO-OPENEBS-BASE — OpenEBS LocalPV (infra)

Sequence: 14/26 | Prev: STORY-BOOT-AUTOMATION-ALIGN.md | Next: STORY-STO-ROOK-CEPH-OPERATOR.md
Sprint: 3 | Lane: Storage
Global Sequence: 16/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/openebs; kubernetes/clusters/infra/infrastructure.yaml

## Story
Deploy OpenEBS LocalPV on the infra cluster to provide simple local storage classes for stateful components (e.g., logs, caches, CI runners) where node‑local disks are appropriate.

## Why / Outcome
- Fast local storage with straightforward lifecycle and minimal overhead.

## Scope
- Cluster: infra only (apps optional/disabled per architecture)
- Resources: `kubernetes/infrastructure/storage/openebs/*` (bases/openebs HelmRelease + PrometheusRule)

## Acceptance Criteria
1) OpenEBS controller/Daemons are running on infra; default LocalPV StorageClass `${OPENEBS_STORAGE_CLASS}` present.
2) A PVC bound using `${OPENEBS_STORAGE_CLASS}` succeeds; dynamic provisioning works.
3) PrometheusRule loaded; metrics present for OpenEBS.

## Dependencies / Inputs
- Phase 1 complete; Flux managing infrastructure.
- Node paths and basepath `${OPENEBS_BASEPATH}` validated for Talos.

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/clusters/infra/infrastructure.yaml` target that includes storage/openebs.
- [ ] Deploy a sample Pod with a PVC using `${OPENEBS_STORAGE_CLASS}` and verify bound/Ready.

## Validation Steps
- flux -n flux-system --context=infra reconcile ks storage --with-source
- kubectl --context=infra get sc | grep ${OPENEBS_STORAGE_CLASS}
- kubectl --context=infra get pods -n openebs-system

## Definition of Done
- ACs met on infra; Dev Notes include sample PVC/POD YAML and status outputs.
