# 15 — STORY-STO-ROOK-CEPH-OPERATOR — Deploy Rook-Ceph Operator (infra)

Sequence: 15/22 | Prev: STORY-STO-OPENEBS-BASE.md | Next: STORY-STO-ROOK-CEPH-CLUSTER.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/rook-ceph/operator; kubernetes/clusters/infra/infrastructure.yaml

## Story
Deploy the Rook-Ceph operator on the infra cluster to manage Ceph clusters and provide durable distributed storage for platform services.

## Why / Outcome
- Operator lifecycle management for Ceph; enables resilient block storage (RBD) and object storage (RGW).

## Scope
- Cluster: infra only
- Resources: `kubernetes/infrastructure/storage/rook-ceph/operator/*` (bases/rook-ceph-operator HelmRelease + PrometheusRule)

## Acceptance Criteria
1) Rook-Ceph operator Deployment Available in `rook-ceph` namespace.
2) Operator metrics are scraped; PrometheusRules loaded.

## Dependencies / Inputs
- Node device plan documented (see architecture §10); monitors and OSD device classes planned.

## Tasks / Subtasks
- [ ] Reconcile operator Kustomization.
- [ ] Verify operator logs healthy; no CrashLoop or reconcile errors.

## Validation Steps
- flux -n flux-system --context=infra reconcile ks storage --with-source
- kubectl --context=infra -n rook-ceph get deploy rook-ceph-operator

## Definition of Done
- ACs met; evidence captured in Dev Notes.
