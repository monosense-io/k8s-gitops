# 19 — STORY-OBS-VM-STACK — VictoriaMetrics K8s Stack (operator, Grafana, vmalert)

Sequence: 19/26 | Prev: STORY-DB-CNPG-SHARED-CLUSTER.md | Next: STORY-OBS-VICTORIA-LOGS.md
Sprint: 3 | Lane: Observability
Global Sequence: 17/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/bases/victoria-metrics-global; kubernetes/bases/victoria-metrics-stack; kubernetes/components/networkpolicy/monitoring; kubernetes/components/pdb/victoria-metrics-pdb; kubernetes/components/monitoring/business-metrics; bootstrap/helmfile.d/README.md (CRDs)

## Story
Deploy VictoriaMetrics k8s-stack with operator CRDs, a global vmcluster on infra (vmselect/vminsert/vmstorage) plus vmauth and vmalert, and per-cluster vmagent. Apps cluster scrapes locally and remote-writes to infra. Grafana runs in observability with admin secret, dashboards, and ServiceMonitors.

## Why / Outcome
- Centralized metrics storage with federated collection; unified dashboards/alerts.

## Scope
- Infra: `bases/victoria-metrics-global/helmrelease.yaml` (vmcluster, vmauth, vmalert, alertmanager)
- Apps: `bases/victoria-metrics-stack/helmrelease.yaml` (vmagent only; kube-state-metrics/node-exporter as needed)
- Shared: NetworkPolicies, PDBs, and business metrics rules under `kubernetes/components/`

## Acceptance Criteria
1) victoria-metrics-operator CRDs Established; operator pods Ready on infra.
2) Infra vmcluster Ready (vmselect/vminsert/vmstorage), vmauth and vmalert Available; Alertmanager Ready.
3) Apps vmagent remote-writes successfully (2xx) to `${GLOBAL_VM_INSERT_ENDPOINT}`; vmagent shows targets for kube-state-metrics, node-exporter, Cilium.
4) Grafana reachable at `victoria-metrics-grafana` Service with credentials from `${OBSERVABILITY_GRAFANA_SECRET_PATH}`; at least one dashboard renders with live data.
5) Business metrics rules loaded; firing test alerts reach Alertmanager.

## Dependencies / Inputs
- STORY-BOOT-CRDS; StorageClass `${OBSERVABILITY_BLOCK_SC}` present.
- `cluster-settings`: `${GLOBAL_VM_INSERT_ENDPOINT}`, `${GLOBAL_VM_SELECT_ENDPOINT}`, `${GLOBAL_ALERTMANAGER_ENDPOINT}`, `${OBSERVABILITY_GRAFANA_SECRET_PATH}`.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Infra cluster: ensure `kubernetes/bases/victoria-metrics-global/helmrelease.yaml` is included by infra Kustomization and substitutes `OBSERVABILITY_*` and `GLOBAL_*` values.
- [ ] Apps cluster: ensure `kubernetes/bases/victoria-metrics-stack/helmrelease.yaml` is included by apps Kustomization with `vmcluster.enabled=false` and `vmagent.enabled=true` (already set), external labels `cluster: ${CLUSTER}`.
- [ ] Grafana admin credentials: ExternalSecret path `${OBSERVABILITY_GRAFANA_SECRET_PATH}` mapped to `grafana-admin-new` Secret (user/password keys `admin-user`, `admin-password`).
- [ ] NetworkPolicies: apply `kubernetes/components/networkpolicy/monitoring/networkpolicy.yaml` to allow vm* components to communicate (vmselect↔vmstorage, vminsert↔vmstorage, vmauth↔vmselect, vmalert→alertmanager).
- [ ] PDBs: apply `kubernetes/components/pdb/victoria-metrics-pdb.yaml` to protect vmselect/vminsert/vmstorage disruptions.
- [ ] Business metrics: include `kubernetes/components/monitoring/business-metrics/*` (PrometheusRule/ConfigMap) so vmalert evaluates rules.
- [ ] Remote write: confirm apps vmagent `remoteWrite[0].url` points to `${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus/api/v1/write`.

## Validation Steps
- kubectl --context=infra -n observability get vmclusters.operator.victoriametrics.com
- kubectl --context=infra -n observability get deploy vmauth vmalert alertmanager
- kubectl --context=apps -n observability logs deploy/victoria-metrics-vmagent | rg "remote write" -n
- kubectl --context=infra -n observability port-forward svc/victoria-metrics-global-vmselect 8481 & curl -sf http://127.0.0.1:8481/select/0/prometheus/api/v1/labels
- Grafana: `kubectl --context=infra -n observability port-forward svc/victoria-metrics-grafana 3000:80` and login.

## Definition of Done
- ACs met; evidence captured.
