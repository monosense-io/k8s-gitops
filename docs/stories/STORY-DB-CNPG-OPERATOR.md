# 17 — STORY-DB-CNPG-OPERATOR — CloudNativePG Operator

Sequence: 17/22 | Prev: STORY-STO-ROOK-CEPH-CLUSTER.md | Next: STORY-DB-CNPG-SHARED-CLUSTER.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §10; kubernetes/bases/cloudnative-pg/operator; kubernetes/workloads/platform/databases/cloudnative-pg

## Story
Deploy CloudNativePG (CNPG) operator via Flux to manage PostgreSQL clusters declaratively.

## Why / Outcome
- Reliable, operator‑managed Postgres with backups, monitoring, and poolers.

## Scope
- Clusters: infra (primary), apps optional for client CRDs only
- Resources: `bases/cloudnative-pg/operator` HelmRelease and PrometheusRule

## Acceptance Criteria
1) CNPG operator Available; CRDs registered and Established.
2) PrometheusRules loaded; metrics for operator present.

## Dependencies / Inputs
- Rook‑Ceph StorageClass available for PVCs.

## Tasks / Subtasks
- [ ] Reconcile operator; verify CRDs and controller health.

## Validation Steps
- flux -n flux-system --context=infra reconcile ks cluster-infra-infrastructure --with-source
- kubectl --context=infra -n cnpg-system get deploy

## Definition of Done
- ACs met; evidence recorded in Dev Notes.
