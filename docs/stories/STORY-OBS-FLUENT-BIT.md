# 21 — STORY-OBS-FLUENT-BIT — Cluster Log Shipping

Sequence: 21/22 | Prev: STORY-OBS-VICTORIA-LOGS.md | Next: STORY-NET-SPEGEL-REGISTRY-MIRROR.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/observability/fluent-bit; kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml

## Story
Deploy Fluent Bit on infra and apps to collect container logs and Kubernetes API audit logs (where available) and ship them to VictoriaLogs via vmauth.

## Why / Outcome
- Centralized logs with consistent schema, low overhead, and multi‑tenant routing.

## Scope
- Clusters: infra, apps
- Resources: `bases/fluent-bit` + audit ConfigMap for API server logs.

## Acceptance Criteria
1) Fluent Bit DaemonSet Ready across nodes; outputs healthy to vmauth.
2) Audit logs (if enabled) are parsed and indexed in VictoriaLogs.

## Dependencies / Inputs
- STORY-OBS-VICTORIA-LOGS; `OBSERVABILITY_LOG_*` settings in `cluster-settings`.

## Tasks / Subtasks
- [ ] Reconcile `observability/fluent-bit` on both clusters.
- [ ] Validate audit parser config and routing.

## Validation Steps
- kubectl --context=<ctx> -n observability get ds fluent-bit
- kubectl --context=<ctx> -n observability logs ds/fluent-bit | tail -n 50

## Definition of Done
- ACs met; evidence captured.
