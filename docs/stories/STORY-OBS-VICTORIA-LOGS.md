# 20 — STORY-OBS-VICTORIA-LOGS — VictoriaLogs (infra) + vmauth

Sequence: 20/26 | Prev: STORY-OBS-VM-STACK.md | Next: STORY-OBS-FLUENT-BIT.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/observability/victoria-logs; kubernetes/workloads/platform/observability/externalsecrets

## Story
Deploy VictoriaLogs on infra with vmauth endpoints for write/read, to serve as the centralized log store.

## Why / Outcome
- Durable, scalable logs storage integrated with metrics stack and Grafana.

## Scope
- Infra: `victoria-logs` helm values via base; vmauth routes for tenants.

## Acceptance Criteria
1) VictoriaLogs pods Ready; write/read endpoints exposed through vmauth.
2) Index retention and storage configuration applied; metrics present.

## Dependencies / Inputs
- StorageClass `${OBSERVABILITY_BLOCK_SC}`; ExternalSecrets for credentials if required.

## Tasks / Subtasks
- [ ] Reconcile `observability/victoria-logs` on infra.
- [ ] Confirm connectivity from Fluent Bit and log ingestion.

## Validation Steps
- kubectl --context=infra -n observability get deploy,sts | grep victoria
- curl -sf http://victorialogs-vmauth.observability.svc.cluster.local:9428/health | grep OK

## Definition of Done
- ACs met; evidence captured.
