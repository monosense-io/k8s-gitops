# 29 — STORY-OBS-VM-STACK-IMPLEMENT — Implement Global Metrics Stack

Sequence: 29/30 | Prev: STORY-OBS-VM-STACK.md | Next: STORY-OBS-VICTORIA-LOGS-IMPLEMENT.md
Sprint: 4 | Lane: Observability
Global Sequence: 20/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/victoria-metrics-global; kubernetes/bases/victoria-metrics-stack; kubernetes/components/networkpolicy/monitoring; kubernetes/components/pdb/victoria-metrics-pdb; docs/architecture.md §B.4

## Story
Apply and validate the global VictoriaMetrics stack on infra and the vmagent-only stack on apps, using existing bases and cluster-settings. No design changes; this executes the plan.

## Acceptance Criteria
1) Infra: `victoria-metrics-global` HelmRelease reconciles; vmcluster, vmauth, vmalert, alertmanager Ready; storage bound to `${OBSERVABILITY_BLOCK_SC}`.
2) Apps: `victoria-metrics` HelmRelease reconciles; vmagent Ready with remote write to `${GLOBAL_VM_INSERT_ENDPOINT}` (2xx).
3) NetworkPolicies and PDBs applied; Grafana accessible with admin from `${OBSERVABILITY_GRAFANA_SECRET_PATH}`.
4) At least one dashboard shows live cluster metrics; sample alert fires and reaches Alertmanager.

## Tasks / Subtasks
- [ ] Include `kubernetes/bases/victoria-metrics-global/helmrelease.yaml` in infra Kustomization (if not already).
- [ ] Include `kubernetes/bases/victoria-metrics-stack/helmrelease.yaml` in apps Kustomization (if not already).
- [ ] Apply `kubernetes/components/networkpolicy/monitoring/networkpolicy.yaml` and `kubernetes/components/pdb/victoria-metrics-pdb.yaml` on infra.
- [ ] Ensure ExternalSecret for Grafana admin at `${OBSERVABILITY_GRAFANA_SECRET_PATH}` exists; Secret name `grafana-admin-new` with keys `admin-user`, `admin-password`.
- [ ] Validate vmagent remote write logs and vmcluster health.

## Validation Steps
- flux -n flux-system --context=infra reconcile ks infra-infrastructure --with-source
- flux -n flux-system --context=apps reconcile ks apps-infrastructure --with-source
- kubectl --context=infra -n observability get deploy,sts | rg "vmauth|vmalert|vm(select|insert|storage)"
- kubectl --context=apps -n observability logs deploy/victoria-metrics-vmagent | rg "remote write"
- Port-forward vmselect and query labels; log into Grafana and verify dashboard data.

## Definition of Done
- ACs met; evidence recorded.
