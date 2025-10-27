# Risk Profile: STORY-DNS-COREDNS-BASE — Create CoreDNS GitOps Manifests

Date: 2025-10-27
Reviewer: Quinn (Test Architect)

## Executive Summary

- Total Risks Identified: 6
- Critical Risks: 1
- High Risks: 2
- Medium Risks: 2
- Low Risks: 1
- Risk Score: 48/100 (calculated)

## Risk Matrix

| Risk ID            | Description                                                                 | Probability | Impact   | Score | Priority |
|--------------------|-----------------------------------------------------------------------------|-------------|----------|-------|----------|
| TECH-001-OCI-URL   | OCIRepository URL placeholder not set; HelmRelease cannot fetch chart       | High (3)    | High (3) | 9     | Critical |
| OPS-001-SM-CRDS    | ServiceMonitor/PrometheusRule CRDs absent when CoreDNS first reconciles     | Medium (2)  | High (3) | 6     | High     |
| OPS-002-SUBSTITUTION| postBuild substitutions fail (missing/wrong `cluster-settings` wiring)      | Medium (2)  | High (3) | 6     | High     |
| PERF-001-REPLICAS  | Under-provisioned replicas cause DNS latency/outage during drain/updates    | Medium (2)  | Medium(2)| 4     | Medium   |
| TECH-002-TSC-LABEL | TopologySpreadConstraints label mismatch reduces HA distribution            | Medium (2)  | Medium(2)| 4     | Medium   |
| OPS-003-CLUSTERIP  | ClusterIP out of Service CIDR or collides with existing service             | Low (1)     | High (3) | 3     | Low      |

## Critical Risks Requiring Immediate Attention

### TECH-001-OCI-URL: OCIRepository URL placeholder not set

Score: 9 (Critical)

- Probability: High — The story currently uses a placeholder (`<SET_ME>`) for the OCI chart URL.
- Impact: High — Helm controller cannot pull the chart; CoreDNS install will fail when reconciled.
- Mitigation (preventive):
  - Set approved OCI registry URL for the CoreDNS chart (e.g., organization mirror) and pin `ref.semver: "1.38.0"`.
  - Preflight: `flux reconcile source oci coredns-charts --with-source` or `helm show chart oci://…` locally.
  - CI check: verify `spec.url` is non-placeholder and reachable.
- Testing Focus: Add CI probe step to fetch chart metadata from the configured OCI URL.

## Risk Distribution

- By Category: Technical 2 (1 critical), Operational 3 (1 high, 1 low), Performance 1 (medium)
- By Component: Infrastructure (Flux/Helm) 4, DNS Workload 2

## Detailed Risk Register (Mitigation and Testing)

1) OPS-001-SM-CRDS (Score 6)
- Risk: Prometheus CRDs not present when HelmRelease renders ServiceMonitor; reconciliation fails.
- Mitigation: Either (a) disable `values.serviceMonitor.enabled` until observability CRDs are present; or (b) sequence deployment after observability story; or (c) separate ServiceMonitor into later story.
- Testing: Dry-run Helm template against a cluster with/without CRDs; verify failure mode. Add CI lint ensuring `ServiceMonitor` gated.

2) OPS-002-SUBSTITUTION (Score 6)
- Risk: Missing `postBuild.substituteFrom` or wrong key names prevent replica/IP substitution.
- Mitigation: Ensure cluster Kustomizations include `postBuild.substituteFrom: ConfigMap/cluster-settings`. Add CI assert to check rendered values via `flux build` or kustomize + yq cross-check.
- Testing: Render and assert `.spec.values.replicaCount` and `.spec.values.service.clusterIP` for both clusters.

3) PERF-001-REPLICAS (Score 4)
- Risk: Replica count set to 1 leads to DNS impact during node maintenance.
- Mitigation: Keep `COREDNS_REPLICAS: "2"` minimum; confirm PDB `minAvailable: 1`.
- Testing: Rolling restart in staging; ensure zero failed DNS lookups.

4) TECH-002-TSC-LABEL (Score 4)
- Risk: Label selector in `topologySpreadConstraints` (`k8s-app: kube-dns`) must match chart labels; mismatches reduce HA.
- Mitigation: Confirm chart labels for selected version; adjust selector if needed.
- Testing: Rendered Deployment label check; ensure pods schedule on distinct nodes.

5) OPS-003-CLUSTERIP (Score 3)
- Risk: ClusterIP outside Service CIDR or collision.
- Mitigation: Validate against cluster `SERVICE_CIDR`; reserve IPs. Keep `10.245.0.10` and `10.247.0.10` aligned with cluster-settings.
- Testing: CI script to assert IP ∈ CIDR; check duplication across services.

## Risk-Based Testing Strategy

- Priority 1 (Critical/High):
  - OCI URL reachability and chart metadata fetch
  - Substitution correctness (replicaCount, service.clusterIP) for both clusters
  - ServiceMonitor gating when CRDs absent
- Priority 2 (Medium):
  - Topology spread label verification; HA scheduling across nodes
  - Replica/PDB behavior under drain/rollout
- Priority 3 (Low):
  - ClusterIP-in-CIDR validation script in CI

## Risk Acceptance Criteria

- Must fix before deployment: All Critical (9) and High (6) risks above.
- Can proceed with mitigation: Medium risks with verifiable compensating controls.
- Accepted Risks: None at this time.

## Monitoring Requirements

- Add alerts for CoreDNSDown/CoreDNSHighErrorRate/CoreDNSLatencyHigh once observability is present.
- Validate ServiceMonitor targets and scrape success after CRDs exist.

## Risk Review Triggers

- Change of chart version or source
- Observability CRD installation timing changes
- Cluster CIDR refactors or IP plan changes

---

Risk profile generated by QA task `risk-profile`.

