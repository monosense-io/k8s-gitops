# Test Design: STORY-DB-DRAGONFLY-OPERATOR-CLUSTER — DragonflyDB Operator & Shared Cluster

Date: 2025-10-22
Designer: Quinn (Test Architect)
Story: docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
Related Risk Profile: docs/qa/assessments/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER-risk-20251022.md

## Test Strategy Overview
- Scope: Validate operator HA and CRDs, Dragonfly CR readiness/HA, cross‑cluster access via Cilium global Service, NetworkPolicy enforcement, observability/alerts, and tenancy guidance.
- Total test scenarios: 18
- By level: Unit 3, Integration 10, E2E 5
- By priority: P0 10, P1 6, P2 2
- Environments: Kubernetes contexts `infra` and `apps`; Prometheus/VictoriaMetrics access; temporary test pods for connectivity checks.

Notation: IDs use `DFLY-{LEVEL}-{SEQ}`. Replace `<CTX>` with `infra`/`apps`, and `<ns>` with `dragonfly-system`.

## Test Scenarios by Acceptance Criteria

### AC1: Operator Ready (replicas ≥2, PDB present); CRDs Established

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                               | Justification |
| --------------- | ----------- | -------- | --------------------------------------------------------------------------------------------------------------------- | ------------- |
| DFLY-UNIT-001   | Unit        | P0       | G: repo. W: `yq '.install.crds,.upgrade.crds,.values.replicaCount' helmrelease.yaml`. T: CreateReplace + replicas≥2. | Static guard. |
| DFLY-INT-001    | Integration | P0       | G: <CTX>=infra. W: `kubectl -n dragonfly-operator-system get deploy`. T: availableReplicas ≥2 within timeout.        | HA operator.  |
| DFLY-INT-002    | Integration | P0       | G: infra. W: `kubectl get crd | rg dragonflydb.io`. T: CRDs present/Established.                                     | CRD readiness.|
| DFLY-INT-003    | Integration | P1       | G: infra. W: `kubectl -n dragonfly-operator-system get pdb`. T: minAvailable ≥1.                                     | Disruption safety. |

### AC2: Dragonfly CR Ready (3 pods; PVCs Bound; metrics scraped)

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                                       | Justification |
| --------------- | ----------- | -------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DFLY-INT-004    | Integration | P0       | G: infra. W: `kubectl -n <ns> get dragonflies.dragonflydb.io dragonfly -o yaml`. T: status.phase Ready; replicas=3.         | CR readiness. |
| DFLY-INT-005    | Integration | P0       | G: infra. W: `kubectl -n <ns> get pods -l app.kubernetes.io/name=dragonfly`. T: 3 pods Ready.                               | Pod health.   |
| DFLY-INT-006    | Integration | P0       | G: infra. W: `kubectl -n <ns> get pvc`. T: PVCs Bound.                                                                        | Persistence.  |
| DFLY-INT-007    | Integration | P1       | G: infra. W: `kubectl -n <ns> get pod -l app.kubernetes.io/name=dragonfly -o wide`. T: pods spread across nodes.            | HA topology.  |
| DFLY-UNIT-002   | Unit        | P1       | G: repo. W: search CR for `topologySpreadConstraints|podAntiAffinity`. T: present.                                          | Spec presence.|
| DFLY-INT-008    | Integration | P1       | G: infra. W: `kubectl -n <ns> get servicemonitor,prometheusrule`. T: objects present and valid.                               | Observability wiring. |
| DFLY-E2E-001    | E2E         | P0       | G: PromQL. W: query `dragonfly_*` series. T: non‑empty in last 5m.                                                             | Scrape validated. |

### AC3: Global Service reachable from apps; GitLab connectivity

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification |
| --------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DFLY-E2E-002    | E2E         | P0       | G: CTX=apps. W: `nslookup dragonfly.dragonfly-system.svc.cluster.local`. T: resolves; `nc -vz ... 6379` succeeds.        | Cross‑cluster reachability. |
| DFLY-INT-009    | Integration | P1       | G: apps GitLab release values. W: check external Redis settings. T: points to Dragonfly global Service.                   | Config validation. |

### AC4: NetworkPolicy restricts access; monitoring egress allowed

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification |
| --------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DFLY-INT-010    | Integration | P0       | G: infra. W: `kubectl -n <ns> get networkpolicy`. T: NP exists with allowed ns list and metrics egress.                 | Policy present. |
| DFLY-E2E-003    | E2E         | P0       | G: test pods in allowed/disallowed namespaces. W: `redis-cli -h dragonfly... PING` (or `nc`). T: allowed=OK, denied=Fail. | Enforcement.    |

### AC5: PrometheusRule includes availability, memory/disk/command-rate, replication alerts

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                     | Justification |
| --------------- | ----------- | -------- | ----------------------------------------------------------------------------------------------------------- | ------------- |
| DFLY-UNIT-003   | Unit        | P1       | G: repo. W: search PrometheusRule expressions for named alerts. T: rules present (availability/mem/disk/cmd/replication). | Static content check. |
| DFLY-E2E-004    | E2E         | P1       | G: PromQL. W: evaluate alert expressions against current metrics. T: query returns valid vector (not error).             | Rule sanity. |

### AC6: Tenancy guidance documented; example per‑tenant CR stub (optional)

| ID              | Level | Priority | Test (Given/When/Then)                                                             | Justification           |
| --------------- | ----- | -------- | ----------------------------------------------------------------------------------- | ----------------------- |
| DFLY-INT-011    | Int   | P2       | G: repo. W: locate example CR stub if provided (e.g., docs/examples/dragonfly-gitlab.yaml). T: present or N/A documented. | Documentation presence. |

## Negative and Edge Case Tests

| ID              | Level       | Priority | Test (Given/When/Then)                                                                                           | Mitigates Risks                  |
| --------------- | ----------- | -------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| DFLY-E2E-005    | E2E         | P0       | G: non‑prod. W: simulate node drain or voluntary disruption. T: PDB prevents dropping below 2 available data pods. | OPS-001 (PDB).                   |
| DFLY-INT-012    | Integration | P2       | G: non‑prod. W: temporarily set wrong ExternalSecret path. T: ESO condition shows error; revert, sync recovers.     | OPS-002 (ESO path).              |

## Risk Coverage Mapping
- SEC-001 (NetworkPolicy) → DFLY-INT-010, DFLY-E2E-003
- OPS-001 (PDB data-plane) → DFLY-E2E-005, DFLY-INT-003
- TECH-001 (topology/anti‑affinity) → DFLY-UNIT-002, DFLY-INT-007
- OPS-002 (ESO mismatch) → DFLY-INT-012
- PERF-001 (cross‑cluster latency) → DFLY-E2E-002 (extend with p95 observation in run)
- TECH-002 (version alignment) → DFLY-UNIT-001 + post‑upgrade smoke (operator policy)
- MON-001 (metrics labels) → DFLY-INT-008, DFLY-E2E-001/004
- SEC-002 (no TLS) → Addressed by DFLY-INT-010/DFLY-E2E-003 policy tests

## Recommended Execution Order
1. P0 Unit: DFLY-UNIT-001
2. P0 Integration: DFLY-INT-001/002/004/005/006/010/008
3. P0 E2E: DFLY-E2E-001/002/003/005
4. P1 set: DFLY-INT-003/007/009, DFLY-UNIT-003, DFLY-E2E-004
5. P2 set: DFLY-INT-011/012

## Gate YAML Block
```yaml
test_design:
  scenarios_total: 18
  by_level:
    unit: 3
    integration: 10
    e2e: 5
  by_priority:
    p0: 10
    p1: 6
    p2: 2
  coverage_gaps: []
```

## Notes
- Use temporary busybox/alpine pods for `nc`/`redis-cli` tests; clean up after.
- Keep E2E disruptive checks (node drain) to non‑production and outside change windows.
- If operator chart exposes readiness/liveness for data pods, enable them to improve failure detection.

