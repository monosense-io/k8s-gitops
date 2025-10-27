# 22 — STORY-OBS-FLUENT-BIT-IMPLEMENT — Implement Cluster Log Shipping

Sequence: 22/50 | Prev: STORY-OBS-VICTORIA-LOGS-IMPLEMENT.md | Next: STORY-DB-CNPG-OPERATOR.md
Sprint: 4 | Lane: Observability
Global Sequence: 22/50

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/fluent-bit; kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml; docs/architecture.md §B.4

## Story
Apply and validate Fluent Bit DaemonSet on infra and apps, shipping logs to VictoriaLogs vmauth over HTTP JSON with multi-tenant headers.

## Acceptance Criteria
1) DaemonSet Ready across nodes on infra and apps.
2) HTTP output succeeds to `${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}${OBSERVABILITY_LOG_ENDPOINT_PATH}` with header `X-Scope-OrgID=${OBSERVABILITY_LOG_TENANT}`.
3) Optional audit pipeline ingests API server audit logs when enabled.

## Tasks / Subtasks
- [ ] Include `kubernetes/bases/fluent-bit/helmrelease.yaml` in infra/apps Kustomizations.
- [ ] Verify hostPath mounts exist for `/var/log`, `/var/lib/containerd/...`, and `/var/fluent-bit/state` on Talos.
- [ ] Confirm `[INPUT] tail`, `[FILTER] kubernetes`, `[FILTER] modify`, and `[OUTPUT] http` blocks match the plan.
- [ ] Optionally apply `kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml`.
- [ ] Send a synthetic log and verify its appearance via Victorialogs query.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks <ctx>-infrastructure --with-source
- kubectl --context=<ctx> -n observability get ds fluent-bit
- kubectl --context=<ctx> -n observability logs ds/fluent-bit | tail -n 50
- Synthetic POST to vmauth `/insert` path; confirm query result.

## Definition of Done
- ACs met; evidence recorded.
