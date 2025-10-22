# 15 — STORY-OBS-FLUENT-BIT — Cluster Log Shipping

Sequence: 15/41 | Prev: STORY-OBS-VICTORIA-LOGS.md | Next: STORY-OBS-VM-STACK-IMPLEMENT.md
Sprint: 3 | Lane: Observability
Global Sequence: 15/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/fluent-bit; kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml

## Story
Deploy Fluent Bit on infra and apps to collect container logs and Kubernetes API audit logs (where available) and ship them to VictoriaLogs via vmauth.

## Why / Outcome
- Centralized logs with consistent schema, low overhead, and multi‑tenant routing.

## Scope
- Clusters: infra, apps
- Resources: `kubernetes/bases/fluent-bit/helmrelease.yaml` (DaemonSet) + optional audit ConfigMap for API server logs.

## Acceptance Criteria
1) Fluent Bit DaemonSet Ready across nodes; HTTP output to `${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}${OBSERVABILITY_LOG_ENDPOINT_PATH}` returns 2xx; tenant header `${OBSERVABILITY_LOG_TENANT}` is set.
2) Parsers enrich records with cluster label `${CLUSTER}` and Kubernetes metadata; audit logs (if enabled) are parsed and indexed in VictoriaLogs.

## Dependencies / Inputs
- STORY-OBS-VICTORIA-LOGS; `OBSERVABILITY_LOG_*` settings in `cluster-settings`.
- Container runtime paths: `/var/lib/containerd/io.containerd.runtime.v2.task/k8s.io`, `/var/log/containers`, and position DB `/var/fluent-bit/state`.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Ensure `kubernetes/bases/fluent-bit/helmrelease.yaml` is included by infra and apps Kustomizations; verify values substitute `OBSERVABILITY_LOG_*`.
- [ ] Confirm DaemonSet volumes: hostPath mounts for `/var/log`, `/var/lib/containerd/...`, and `/var/fluent-bit/state`.
- [ ] Confirm config sections align with repo base:
  - `[INPUT] tail` on `/var/log/containers/*.log` with docker parser.
  - `[FILTER] kubernetes` (Merge_Log On) and `[FILTER] modify` to add `cluster=${CLUSTER}`.
  - `[OUTPUT] http` to VictoriaLogs vmauth with `Format json`, date keys, TLS Off (per settings) and `Header X-Scope-OrgID ${OBSERVABILITY_LOG_TENANT}`.
- [ ] Optional: Apply audit log input/filter chain using `kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml` when API audit logs are available.

## Validation Steps
- kubectl --context=<ctx> -n observability get ds fluent-bit
- kubectl --context=<ctx> -n observability logs ds/fluent-bit | tail -n 50
- Send a synthetic log using a debug pod and confirm it appears when querying via VictoriaLogs vmselect.

## Definition of Done
- ACs met; evidence captured.
