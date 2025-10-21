# Risk Profile: STORY-BOOT-TALOS — Phase −1 Talos Bring‑Up

Date: 2025-10-21
Reviewer: Quinn (Test Architect)
Story: docs/stories/STORY-BOOT-TALOS.md
Related: docs/architecture.md §6, .taskfiles/cluster/Taskfile.yaml, .taskfiles/bootstrap/Taskfile.yaml, talos/**

---

## Gate Snippet (risk_summary)

```yaml
risk_summary:
  totals:
    critical: 0
    high: 4
    medium: 4
    low: 2
  highest:
    id: TECH-001
    score: 6
    title: 'Safe-detector absent could trigger double bootstrap'
  recommendations:
    must_fix:
      - 'Add/verify safe-detector behavior in :cluster:layer:1-talos (skip bootstrap when CP healthy)'
      - 'Pre-validate 1Password Connect Secret before Phase 2 (ESO/controller rollout)'
      - 'Enforce Phase 0 CRDs-only guard (kinds audit)'
      - 'Pin/align CRD and controller versions between Phase 0 and Phase 2'
    monitor:
      - 'Track control-plane resource pressure; validate tolerations/nodeSelectors for platform controllers'
      - 'Add CI dry-run for helmfile/template drift (non-blocking initially)'
```

---

## Executive Summary

- Total Risks Identified: 10
- Critical Risks (score 9): 0
- High Risks (score 6): 4
- Medium Risks (score 4): 4
- Low Risks (score 2–3): 2
- Overall Risk Rating: High (aggregate score ≈ 56/100)

Primary drivers: lack of safe-detector (double bootstrap risk), secrets bootstrap dependency (ESO/1Password), version skew between Phase 0 CRDs and Phase 2 controllers, and control‑plane‑only scheduling pressure.

---

## Risk Matrix

| Risk ID  | Description                                                     | Prob | Impact | Score | Priority |
|----------|-----------------------------------------------------------------|------|--------|-------|----------|
| TECH-001 | Safe-detector absent could double-bootstrap etcd/CP             | Med  | High   | 6     | High     |
| SEC-001  | 1Password token/Secret missing → ESO/secret-dependent steps fail| Med  | High   | 6     | High     |
| TECH-002 | Version skew: Phase 0 CRDs vs Phase 2 controllers               | Med  | High   | 6     | High     |
| OPS-001  | Control-plane-only scheduling resource pressure/taints          | Med  | High   | 6     | High     |
| OPS-002  | Helmfile vs Flux values/template drift                          | Med  | Med    | 4     | Medium   |
| OPS-003  | Kubeconfig generation wrong context/path                         | Low  | Med    | 2     | Low      |
| TECH-003 | Phase 0 pipeline emits non-CRDs accidentally                    | Low  | Med    | 2     | Low      |
| OPS-004  | Registry/network egress flakiness during bootstrap               | Med  | Med    | 4     | Medium   |
| PERF-001 | API server load spikes when core controllers start together      | Low  | Med    | 2     | Low      |
| DATA-001 | Misapplied CRDs lead to orphan types/validation confusion        | Med  | Med    | 4     | Medium   |

Notes: Probability/Impact scale — Low=1, Medium=2, High=3. Score = P×I.

---

## Detailed Risk Register with Mitigations

### TECH-001 — Safe-detector absent could double-bootstrap etcd/CP (Score 6)
- Probability: Medium — re-runs are common; detector is a new requirement.
- Impact: High — double-bootstrap can destabilize control-plane.
- Mitigation (preventive):
  - Implement detector: in `:cluster:layer:1-talos`, if `talosctl get machineconfig` AND `etcd status` are healthy on first CP, skip `talosctl bootstrap`.
  - Add DRY_RUN plan print.
- Testing Focus:
  - Simulate healthy CP and verify skip.
  - Re-run create path; ensure no destructive calls.

### SEC-001 — 1Password token/Secret missing (Score 6)
- Probability: Medium — bootstrap timing and secret population are error-prone.
- Impact: High — ESO/Webhooks/controllers fail; downstream secrets absent.
- Mitigation (preventive/detective):
  - Preflight check for `external-secrets/onepassword-connect-token` before Phase 2.
  - Document op inject path; verify at least one ExternalSecret can sync post-Phase 2.
- Testing Focus: Smoke ExternalSecret after Phase 2.

### TECH-002 — Version skew CRDs vs controllers (Score 6)
- Probability: Medium — frequent upstream bumps.
- Impact: High — controllers may reject/expect different schemas.
- Mitigation: Pin and align versions in `00-crds.yaml` and `01-core.yaml.gotmpl`; add CI dry-run to detect mismatch.
- Testing: kubeconform strict after Phase 0; `helmfile template` kinds audit for Phase 1/2.

### OPS-001 — CP-only scheduling resource pressure (Score 6)
- Probability: Medium — all workloads run on CPs.
- Impact: High — degraded stability, scheduling timeouts.
- Mitigation: Keep taints; ensure platform controllers have appropriate tolerations/requests/limits; monitor with `kubectl top` and alerts.
- Testing: Validate readiness under load; check quotas.

### OPS-002 — Helmfile vs Flux drift (Score 4)
- Probability: Medium; Impact: Medium.
- Mitigation: Ensure bootstrap values derive from the same source as HelmReleases; run `flux build/diff` in CI; document single source of truth.
- Testing: Compare values; reconcile dry runs.

### OPS-003 — Kubeconfig wrong context/path (Score 2)
- Mitigation: Verify `task :talos:generate-kubeconfig` writes to `kubernetes/kubeconfig`; check contexts `infra|apps` exist.
- Testing: `kubectl --context=<ctx> get nodes` sanity.

### TECH-003 — Phase 0 emits non-CRDs (Score 2)
- Mitigation: Enforce yq kinds filter; audit counts.
- Testing: Automated kinds diff in dry-run.

### OPS-004 — Network/registry flakiness (Score 4)
- Mitigation: Retries/backoff; mirror registries if available; pre-pull for test environments.
- Testing: Simulate intermittent failures; ensure idempotency.

### PERF-001 — API server load spikes (Score 2)
- Mitigation: Stagger core controller sync if needed; validate resource requests.
- Testing: Observe API metrics during Phase 2.

### DATA-001 — CRD misapplication leads to confusion (Score 4)
- Mitigation: Keep Phase 0 CRDs-only invariant; dry-run kubeconform before Phase 2.
- Testing: Verify API discovery lists required groups in both clusters.

---

## Risk-Based Testing Strategy

### Priority 1 (address before moving on)
- Safe-detector skip logic and re-run idempotency (TECH-001).
- Secret bootstrap presence + ExternalSecret smoke test (SEC-001).
- Phase 0 CRDs-only guard + kubeconform after Phase 0 (TECH-002/TECH-003).

### Priority 2
- Drift detection (OPS-002) via dry-run and `flux build/diff`.
- CP resource pressure checks (OPS-001) with `kubectl top` and readiness under load.

### Priority 3
- Network/registry resiliency (OPS-004), API load observation (PERF-001), kubeconfig sanity (OPS-003).

---

## Risk Acceptance Criteria
- Must Fix before production: All score 6 risks with security/CP stability impact (TECH-001, SEC-001, TECH-002, OPS-001).
- Acceptable with monitoring: Score 4 risks if mitigations in place and tests pass.
- Residual low risks: Documented and tracked.

