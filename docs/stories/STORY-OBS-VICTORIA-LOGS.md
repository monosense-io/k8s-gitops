# 20 — STORY-OBS-VICTORIA-LOGS — VictoriaLogs (infra) + vmauth

Sequence: 20/26 | Prev: STORY-OBS-VM-STACK.md | Next: STORY-OBS-FLUENT-BIT.md
Sprint: 3 | Lane: Observability
Global Sequence: 18/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/victoria-logs; kubernetes/components/networkpolicy/monitoring

## Story
Deploy VictoriaLogs on infra with vmauth endpoints for write/read, to serve as the centralized log store.

## Why / Outcome
- Durable, scalable logs storage integrated with metrics stack and Grafana.

## Scope
- Infra: `bases/victoria-logs/helmrelease.yaml` (vmstorage/vminsert/vmselect) with vmauth; ServiceMonitor enabled.
- Ingest: Fluent Bit sends HTTP JSON to vmauth `/insert`, tenant set via `X-Scope-OrgID`.

## Acceptance Criteria
1) VictoriaLogs pods Ready; vminsert/vmselect/vmstorage replicas match desired; vmauth Available.
2) Retention `${OBSERVABILITY_LOGS_RETENTION}` and storageClass `${OBSERVABILITY_BLOCK_SC}` applied.
3) ServiceMonitor scrapes Victorialogs metrics; Grafana can query via Prometheus datasource.

## Dependencies / Inputs
- StorageClass `${OBSERVABILITY_BLOCK_SC}`.
- `cluster-settings`: `${OBSERVABILITY_LOG_ENDPOINT_HOST}`, `${OBSERVABILITY_LOG_ENDPOINT_PORT}`, `${OBSERVABILITY_LOG_ENDPOINT_PATH}`, `${OBSERVABILITY_LOG_TENANT}`.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Ensure `kubernetes/bases/victoria-logs/helmrelease.yaml` is included by infra Kustomization; confirm values substitute retention, storage class.
- [ ] Verify vmauth has no public ingress; internal Service only. Optionally expose via vmauth with auth headers if needed.
- [ ] Validate endpoints for Fluent Bit: `http://${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}${OBSERVABILITY_LOG_ENDPOINT_PATH}`.
- [ ] Apply monitoring networkpolicy from `kubernetes/components/networkpolicy/monitoring/networkpolicy.yaml` to allow scrapes and internal traffic between components.

## Validation Steps
- kubectl --context=infra -n observability get deploy,sts | rg "victoria|vminsert|vmselect|vmstorage|vmauth"
- curl -sf http://${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}/health | grep OK
- From a worker node or debug pod, send a test log line via HTTP POST and confirm it appears in queries via vmselect.

## Definition of Done
- ACs met; evidence captured.
