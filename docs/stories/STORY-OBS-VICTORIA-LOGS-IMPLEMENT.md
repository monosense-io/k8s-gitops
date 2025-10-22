# 30 — STORY-OBS-VICTORIA-LOGS-IMPLEMENT — Implement Logs Stack

Sequence: 30/30 | Prev: STORY-OBS-VM-STACK-IMPLEMENT.md | Next: STORY-OBS-FLUENT-BIT-IMPLEMENT.md
Sprint: 4 | Lane: Observability
Global Sequence: 21/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/victoria-logs; kubernetes/components/networkpolicy/monitoring; docs/architecture.md §B.4

## Story
Apply and validate the VictoriaLogs cluster with vmauth on infra per the architecture plan.

## Acceptance Criteria
1) `victoria-logs` HelmRelease reconciles; vmstorage/vminsert/vmselect and vmauth Ready.
2) Retention `${OBSERVABILITY_LOGS_RETENTION}` and storage class `${OBSERVABILITY_BLOCK_SC}` in effect.
3) ServiceMonitor scrapes Victorialogs; health endpoint returns OK.

## Tasks / Subtasks
- [ ] Ensure bases/victoria-logs HelmRelease included in infra Kustomization.
- [ ] Verify cluster-settings values for logs endpoint host/port/path/TLS/tenant.
- [ ] Apply monitoring network policies for victorialogs.
- [ ] Smoke-test ingestion: POST a JSON record to vmauth `/insert` and query it via vmselect.

## Validation Steps
- flux -n flux-system --context=infra reconcile ks infra-infrastructure --with-source
- kubectl --context=infra -n observability get deploy,sts | rg "victoria|vmauth|vminsert|vmselect|vmstorage"
- curl -sf http://${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}/health | grep OK
- Use a debug pod to POST a sample log; confirm retrieval.

## Definition of Done
- ACs met; evidence recorded.
