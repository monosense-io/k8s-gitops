# Test Design: STORY-DNS-COREDNS-BASE — Create CoreDNS GitOps Manifests

Date: 2025-10-27
Designer: Quinn (Test Architect)

## Test Strategy Overview

- Total test scenarios: 14
- Unit tests: 0 (0%)
- Integration tests: 14 (100%)
- E2E tests: 0 (0%) — deferred to Story 45
- Priority distribution: P0: 7, P1: 5, P2: 2

Rationale: This story is manifest authoring and wiring; tests operate at repository/Flux integration level. Runtime E2E validation is explicitly deferred to Story 45.

## Test Scenarios by Acceptance Criteria

### AC1: HelmRelease manifest exists with pinned version and required values

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC1-INT-001           | Integration | P0       | File `kubernetes/infrastructure/networking/coredns/helmrelease.yaml` exists           | AC existence  |
| 04-AC1-INT-002           | Integration | P0       | `.spec.chart.spec.chart == "coredns"` and `.spec.chart.spec.version == "1.38.0"`     | Version pin   |
| 04-AC1-INT-003           | Integration | P0       | `.spec.chart.spec.sourceRef.kind == "OCIRepository"` and `name == "coredns-charts"`  | Source align  |
| 04-AC1-INT-004           | Integration | P1       | `.spec.values.replicaCount == ${COREDNS_REPLICAS}` (placeholder present)              | Substitution  |
| 04-AC1-INT-005           | Integration | P1       | `.spec.values.service.clusterIP == ${COREDNS_CLUSTER_IP}` (placeholder present)       | Substitution  |
| 04-AC1-INT-006           | Integration | P1       | PDB enabled: `.spec.values.podDisruptionBudget.minAvailable == 1`                     | Availability  |
| 04-AC1-INT-007           | Integration | P1       | Security context hardened (non-root, read-only, drop ALL)                             | Security      |
| 04-AC1-INT-008           | Integration | P2       | Probes configured on 8080/8181; metrics port 9153 annotations present                 | Observability |
| 04-AC1-INT-009           | Integration | P2       | TopologySpreadConstraints selector matches chart labels (`k8s-app: kube-dns`)         | HA spread     |

Validation: `yq` queries against `kustomize build kubernetes/infrastructure/networking/coredns` output.

### AC2: OCIRepository manifest exists and references chart version 1.38.0

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC2-INT-001           | Integration | P0       | File `kubernetes/infrastructure/networking/coredns/ocirepository.yaml` exists         | AC existence  |
| 04-AC2-INT-002           | Integration | P0       | `.spec.ref.semver == "1.38.0"`                                                        | Version pin   |
| 04-AC2-INT-003           | Integration | P0       | `.spec.url` is not a placeholder (`!contains("<SET_ME>")`) and is reachable (preflight)| Fetchability  |

Preflight (where possible): `helm show chart oci://...` or `flux reconcile source oci coredns-charts --with-source` in a safe sandbox.

### AC3: PrometheusRule manifest exists with required alerts

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC3-INT-001           | Integration | P1       | File `kubernetes/infrastructure/networking/coredns/prometheusrule.yaml` exists        | AC existence  |
| 04-AC3-INT-002           | Integration | P1       | Contains rules: CoreDNSAbsent, CoreDNSDown, CoreDNSHighErrorRate, CoreDNSLatencyHigh | Coverage      |

Note: Runtime evaluation of these alerts occurs in Story 45.

### AC4: Kustomization glue and cluster wiring

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC4-INT-001           | Integration | P0       | `kubernetes/infrastructure/networking/coredns/kustomization.yaml` lists hr and rules  | Glue exists   |
| 04-AC4-INT-002           | Integration | P0       | `kubernetes/clusters/infra/infrastructure.yaml` includes Kustomization `coredns`      | Wiring infra  |
| 04-AC4-INT-003           | Integration | P0       | `kubernetes/clusters/apps/infrastructure.yaml` includes Kustomization `coredns`       | Wiring apps   |
| 04-AC4-INT-004           | Integration | P0       | Each Kustomization has `dependsOn: cilium-core` and `postBuild.substituteFrom` set    | Ordering/subs |
| 04-AC4-INT-005           | Integration | P1       | Each has healthCheck for HelmRelease/coredns in kube-system                           | Health gate   |

### AC5: Cluster settings alignment

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC5-INT-001           | Integration | P0       | `cluster-settings.yaml` (infra) contains `COREDNS_REPLICAS: "2"` and correct ClusterIP| Values exist  |
| 04-AC5-INT-002           | Integration | P0       | `cluster-settings.yaml` (apps) contains `COREDNS_REPLICAS: "2"` and correct ClusterIP | Values exist  |
| 04-AC5-INT-003           | Integration | P1       | ClusterIP ∈ Service CIDR for each cluster (CIDR from settings)                        | IP validity   |

### AC6: Local validation passes

| ID                       | Level       | Priority | Test                                                                                  | Justification |
|--------------------------|-------------|----------|---------------------------------------------------------------------------------------|---------------|
| 04-AC6-INT-001           | Integration | P0       | `kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/` succeeds | Syntax        |
| 04-AC6-INT-002           | Integration | P0       | `kustomize build` succeeds and renders HelmRelease with expected fields               | Render ok     |
| 04-AC6-INT-003           | Integration | P0       | Substitutions verified via `flux build` or yq cross-check vs cluster-settings         | Substitution  |

## Risk Coverage

- TECH-001-OCI-URL → 04-AC2-INT-003 (P0)
- OPS-001-SM-CRDS → 04-AC4-INT-001/005 (P1), plus gating note in story
- OPS-002-SUBSTITUTION → 04-AC4-INT-004 (P0), 04-AC6-INT-003 (P0)
- PERF-001-REPLICAS → 04-AC5-INT-001/002 (P0)
- TECH-002-TSC-LABEL → 04-AC1-INT-009 (P2)
- OPS-003-CLUSTERIP → 04-AC5-INT-003 (P1)

## Recommended Execution Order

1. P0 integration: AC2 (OCI URL fetchability), AC4 wiring/substitutions, AC6 render/substitution checks
2. P0 integration: AC1 version pin and critical values, AC5 cluster-settings presence
3. P1 integration: HealthChecks, PrometheusRule presence, IP-in-CIDR validation
4. P2 integration: Probes/annotations and topology spread selector

## Execution Snippets

- Syntax checks:
```bash
kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/
```
- Render and inspect:
```bash
kustomize build kubernetes/infrastructure/networking/coredns | \
  yq 'select(.kind=="HelmRelease" and .metadata.name=="coredns") | .spec.values'
```
- Substitution cross-checks (offline-friendly):
```bash
yq '.data.COREDNS_CLUSTER_IP' kubernetes/clusters/infra/cluster-settings.yaml
yq '.data.COREDNS_CLUSTER_IP' kubernetes/clusters/apps/cluster-settings.yaml
```
- Optional flux build (if supported offline):
```bash
flux build kustomization coredns --path ./kubernetes/infrastructure/networking/coredns | \
  yq 'select(.kind=="HelmRelease" and .metadata.name=="coredns") | {replicaCount: .spec.values.replicaCount, clusterIP: .spec.values.service.clusterIP}'
```

## Test Design Summary (for gate)

```yaml
test_design:
  scenarios_total: 14
  by_level: { unit: 0, integration: 14, e2e: 0 }
  by_priority: { p0: 7, p1: 5, p2: 2 }
  coverage_gaps: []
```

---

This test design focuses on manifest integrity and Flux wiring; runtime DNS verification is explicitly deferred to Story 45 (VALIDATE-NETWORKING).

