# Risk Profile — STORY-DB-DRAGONFLY-OPERATOR-CLUSTER (DragonflyDB Operator & Shared Cluster)

Date: 2025-10-22
Reviewer: Quinn (Test Architect)
Story: docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
Related: kubernetes/bases/dragonfly-operator/operator/**, kubernetes/infrastructure/repositories/oci/dragonfly-operator.yaml, kubernetes/workloads/platform/databases/dragonfly/**, docs/architecture.md §B.9

---

## Gate Snippet (risk_summary)

```yaml
risk_summary:
  totals:
    critical: 0
    high: 2
    medium: 6
    low: 2
  highest:
    id: SEC-001
    score: 6
    title: 'No NetworkPolicy → cache exposed beyond intended clients'
  recommendations:
    must_fix:
      - 'Add NetworkPolicy to allow only gitlab-system/harbor/selected apps + observability metrics egress'
      - 'Add PodDisruptionBudget (minAvailable: 2) for Dragonfly data pods'
    should_fix:
      - 'Add pod anti-affinity and/or topologySpreadConstraints for 3 pods'
      - 'Confirm ExternalSecret path and alert on sync failures'
      - 'Validate cross-cluster latency SLOs for GitLab and other clients'
      - 'Plan operator/CR version alignment and image upgrade test'
  suggested_gate: CONCERNS
```

- Overall Risk Rating: High
- Overall Story Risk Score: ~54/100 (aggregate)

---

## Risk Matrix

| Risk ID   | Category | Description                                                                 | Prob | Impact | Score | Priority |
| --------- | -------- | --------------------------------------------------------------------------- | ---- | ------ | ----- | -------- |
| SEC-001   | Security | No NetworkPolicy currently limits Dragonfly access                          | 2    | 3      | 6     | P1       |
| OPS-001   | Ops      | No PDB for Dragonfly data-plane; voluntary disruptions can drop quorum      | 2    | 3      | 6     | P1       |
| TECH-001  | Tech     | No anti-affinity/topology spread → co-scheduling risk                       | 2    | 2      | 4     | P2       |
| OPS-002   | Ops      | ExternalSecret path/key mismatch can block auth                             | 2    | 2      | 4     | P2       |
| PERF-001  | Perf     | Cross-cluster latency via Global Service affects GitLab/clients             | 2    | 2      | 4     | P2       |
| TECH-002  | Tech     | Operator/CR/image version alignment not validated after bump                | 2    | 2      | 4     | P2       |
| MON-001   | Ops      | Metrics wiring label mismatch risk (ServiceMonitor vs labels)               | 1    | 2      | 2     | P3       |
| SEC-002   | Security | No TLS on Redis protocol; relies on cluster network boundaries              | 1    | 2      | 2     | P3       |

Legend: Probability (1–3), Impact (1–3), Score = Prob×Impact

---

## Evidence (Repo)

- Operator PDB present (good): `kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml` → `.values.podDisruptionBudget.enabled: true`, `minAvailable: 1`.
- Dragonfly CR present with 3 replicas, PVCs, metrics, and global Service: `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml`.
- No NetworkPolicy defined under `kubernetes/workloads/platform/databases/dragonfly/`.
- ExternalSecret configured via path var: `kubernetes/workloads/platform/databases/dragonfly/externalsecret.yaml`.

---

## Detailed Risk Register with Mitigations

### SEC-001 — No NetworkPolicy limits (Score 6)
- Risk: Cache reachable from unintended namespaces; lateral movement.
- Mitigation: Add `NetworkPolicy` allowing ingress from `gitlab-system`, `harbor`, selected apps; allow `observability` to scrape metrics; default deny others.
- Testing: From disallowed ns, `nc` to 6379 should fail; from allowed, succeed.

### OPS-001 — No PDB for data-plane (Score 6)
- Risk: Evictions/maintenance can drop below quorum;
- Mitigation: Add PDB `minAvailable: 2` targeting Dragonfly pods; verify voluntary disruption safety.
- Testing: `kubectl -n dragonfly-system get pdb` and simulate drain in non-prod.

### TECH-001 — No anti-affinity/topology spread (Score 4)
- Risk: HA reduced if pods co-locate.
- Mitigation: Add `podAntiAffinity` or `topologySpreadConstraints` for 3 pods across nodes.
- Testing: After rollout, `kubectl -n dragonfly-system get pods -o wide` shows distinct nodes.

### OPS-002 — ExternalSecret mismatch (Score 4)
- Risk: Auth secret missing → service down.
- Mitigation: Validate path `${DRAGONFLY_AUTH_SECRET_PATH}`; alert on ESO condition errors.
- Testing: Observe `.status.conditions` on ExternalSecret; negative test with bad path in non-prod.

### PERF-001 — Cross-cluster latency (Score 4)
- Risk: Higher request latency for GitLab/others.
- Mitigation: Keep cache near heavy writers when needed; add SLOs; monitor p95/99 latency.
- Testing: Synthetic GET/SET from apps cluster; alert on p95 above target.

### TECH-002 — Version alignment (Score 4)
- Risk: Operator vs CR behavior drift after image bump.
- Mitigation: Pin tested Dragonfly image with notes; dry-run and rollout in staging first.
- Testing: Functional smoke and failover after upgrade.

### MON-001 — Metrics labels mismatch (Score 2)
- Risk: No scrape / wrong labels.
- Mitigation: Verify ServiceMonitor selects pods; confirm `dragonfly_*` series in VictoriaMetrics.
- Testing: PromQL `dragonfly_*` non-empty; alert sample fires.

### SEC-002 — No TLS for Redis protocol (Score 2)
- Risk: Intra-cluster plaintext.
- Mitigation: Enforce NetworkPolicy boundaries; consider Cilium wireguard/mTLS if required.
- Testing: N/A (policy-level enforcement).

---

## Risk-Based Testing Strategy

### Priority 1 (address before moving on)
- Implement and verify NetworkPolicy (SEC-001).
- Add data-plane PDB and validate disruption behavior (OPS-001).

### Priority 2
- Add anti-affinity/topology spread and verify node distribution (TECH-001).
- Validate ExternalSecret sync and alerting; add negative test (OPS-002).
- Measure cross-cluster latency and set SLO alarms (PERF-001).
- Confirm operator/CR upgrade path with smoke/failover tests (TECH-002).

### Priority 3
- Verify metrics label selection and dashboard panels (MON-001).
- Document accepted risk of non-TLS Redis within cluster boundaries (SEC-002).

---

## Risk Acceptance Criteria
- Must Fix before production: all score 6 risks (SEC-001, OPS-001).
- Acceptable with monitoring: score 4 risks once mitigations and tests pass.
- Residual low risks: documented with periodic revalidation.

