# 19 — STORY-OBS-VM-STACK — VictoriaMetrics K8s Stack (operator, Grafana, vmalert)

Sequence: 19/22 | Prev: STORY-DB-CNPG-SHARED-CLUSTER.md | Next: STORY-OBS-VICTORIA-LOGS.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/observability/multi-cluster; kubernetes/workloads/platform/observability/victoria-metrics; kubernetes/workloads/platform/observability/externalsecrets

## Story
Deploy the VictoriaMetrics operator and a multi‑cluster stack: infra runs a `vmcluster` (global) with vmauth and vmalert; apps runs `vmagent`/exporters that remote write to infra; Grafana is configured with admin secret and dashboards.

## Why / Outcome
- Centralized metrics storage with federated collection; unified dashboards/alerts.

## Scope
- Infra: `victoria-metrics-global` (vmcluster, vminsert, vmselect, vmstorage), vmauth, vmalert
- Apps: `vmagent` remote‑writing to infra
- Grafana admin secret and dashboards via Kustomization

## Acceptance Criteria
1) Operator CRDs present and controllers running.
2) Infra vmcluster Ready; apps vmagent remote write 2xx; scraping kube/node/cilium metrics.
3) vmalert running with rules; Grafana reachable with admin from ExternalSecret; sample dashboard renders.

## Dependencies / Inputs
- STORY-BOOT-CRDS; StorageClass `${OBSERVABILITY_BLOCK_SC}`; ExternalSecret `grafana-admin` set.

## Tasks / Subtasks
- [ ] Reconcile `observability/multi-cluster` on infra and `observability/victoria-metrics` on apps.
- [ ] Validate remote write and rule evaluations.

## Validation Steps
- kubectl --context=infra -n observability get vmclusters.operator.victoriametrics.com
- kubectl --context=apps -n observability logs deploy/vmagent-multi-cluster | grep "remote write"
- kubectl --context=infra -n observability get deploy vmalert

## Definition of Done
- ACs met; evidence captured.
