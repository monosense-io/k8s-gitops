# 18 — STORY-DB-CNPG-SHARED-CLUSTER — Multi‑Tenant Postgres Cluster

Sequence: 18/21 | Prev: STORY-DB-CNPG-OPERATOR.md | Next: STORY-OBS-VM-STACK.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster; kubernetes/workloads/platform/databases/cloudnative-pg/poolers

## Story
Provision a shared CNPG PostgreSQL cluster on infra with scheduled backups, monitoring, and PgBouncer poolers for platform apps.

## Why / Outcome
- Consolidated database service with operational guardrails.

## Scope
- Resources: `shared-cluster/*`, `poolers/*`, ExternalSecrets for credentials

## Acceptance Criteria
1) CNPG cluster pods Ready; primary elected; Service endpoints available.
2) Scheduled backups succeed (S3 RGW or external S3 per settings).
3) PrometheusRules firing correctly on failures; dashboards available.

## Dependencies / Inputs
- STORY-DB-CNPG-OPERATOR; StorageClass `${CEPH_BLOCK_STORAGE_CLASS}`; S3 credentials in secrets.

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/workloads/platform/databases/cloudnative-pg`.
- [ ] Validate backup job success and restore probe (optional).

## Validation Steps
- kubectl --context=infra -n databases get clusters.postgresql.cnpg.io -A
- kubectl --context=infra -n databases get scheduledbackups.postgresql.cnpg.io -A

## Definition of Done
- ACs met with evidence.

