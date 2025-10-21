# Test Design: STORY-BOOT-CORE — Phase 1 Core Bootstrap (infra + apps)

Date: 2025-10-21
Designer: Quinn (Test Architect)
Story: docs/stories/STORY-BOOT-CORE.md
Related Risk Profile: docs/qa/assessments/STORY-BOOT-CORE-risk-20251021.md

## Test Strategy Overview
- Scope: Validate Phase 1 core bootstrap (no CRDs, controllers ready, Flux handover) on infra and apps clusters.
- Total test scenarios: 14
- By level: Unit 2, Integration 5, E2E 7
- By priority: P0 7, P1 5, P2 2
- Execution environment: local shell for unit (templating/static), Kubernetes contexts `infra` and `apps` for integration/E2E.

## Test Scenarios by Acceptance Criteria

Notation: IDs use `BOOT.CORE-{LEVEL}-{SEQ}` and are parameterized by `CTX ∈ {infra, apps}` where applicable.

### AC1: Phase separation — no CRDs emitted by 01-core template

| ID                     | Level | Priority | Test (Given/When/Then)                                                                                                  | Justification                        |
| ---------------------- | ----- | -------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ |
| BOOT.CORE-UNIT-001     | Unit  | P0       | G: repo synced; 01-core.yaml.gotmpl present. W: run `helmfile -f 01-core.yaml.gotmpl -e infra template | yq CRD`. T: count==0. | Pure static validation of manifests. |
| BOOT.CORE-UNIT-002     | Unit  | P0       | Same as above with `-e apps`.                                                                                            | Covers both envs.                    |

### AC2: Core components Ready (Cilium, CoreDNS, External Secrets, cert-manager)

| ID                     | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification                         |
| ---------------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| BOOT.CORE-E2E-001 (CTX)| E2E         | P0       | G: cluster CTX reachable. W: `kubectl -n kube-system rollout status ds/cilium`. T: success within 5m.                   | Platform CNI must be healthy.         |
| BOOT.CORE-E2E-002 (CTX)| E2E         | P0       | G: CTX. W: `kubectl -n kube-system rollout status deploy/cilium-operator`. T: success within 5m.                         | Operator readiness.                   |
| BOOT.CORE-E2E-003 (CTX)| E2E         | P0       | G: CTX and cluster-settings replicas. W: `kubectl -n kube-system rollout status deploy/coredns`. T: replicas match and available. | DNS must be healthy.           |
| BOOT.CORE-INT-001 (CTX)| Integration | P1       | G: CTX. W: `kubectl -n external-secrets rollout status deploy/external-secrets`. T: success within 5m.                   | Controller availability.              |
| BOOT.CORE-INT-002 (CTX)| Integration | P1       | G: CTX. W: `kubectl -n cert-manager rollout status deploy/cert-manager{,-webhook}`. T: both succeed.                     | Cert path readiness.                  |

### AC3: Flux operational (operator + instance Ready; sources/kustomizations Ready)

| ID                     | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification                         |
| ---------------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| BOOT.CORE-E2E-004 (CTX)| E2E         | P0       | G: CTX. W: `kubectl -n flux-system get pods`. T: flux-operator + flux-instance controllers Ready.                         | GitOps controllers required.          |
| BOOT.CORE-INT-003 (CTX)| Integration | P0       | G: CTX. W: `flux --context=CTX get sources git flux-system -n flux-system`. T: Ready.                                    | Git source connectivity.              |
| BOOT.CORE-E2E-005 (CTX)| E2E         | P0       | G: CTX. W: `flux --context=CTX get kustomizations -A`. T: initial Kustomizations Ready.                                   | Convergence proof.                    |

### AC4: Handover criteria — GitRepository connected, initial Kustomizations reconciled

| ID                     | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification                         |
| ---------------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| BOOT.CORE-E2E-006 (CTX)| E2E         | P1       | G: CTX and gotk-sync.yaml exists. W: postsync after flux-instance; or manual `kubectl apply -f gotk-sync.yaml`. T: GitRepository status shows Ready. | Validates handover wiring. |
| BOOT.CORE-INT-004 (CTX)| Integration | P1       | G: CTX. W: `kubectl -n flux-system get kustomization cluster-CTX-* -o yaml`. T: status.conditions Ready=True.             | Specific entry Kustomization check.   |

### AC5: Evidence captured (Dev Notes)

| ID                     | Level       | Priority | Test (Given/When/Then)                                                                                                   | Justification                         |
| ---------------------- | ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| BOOT.CORE-INT-005      | Integration | P2       | G: local run. W: archive command outputs for each step to a run log (timestamped). T: log exists and is linked in story Dev Notes. | Traceability requirement.      |

## Negative and Edge Case Tests
- BOOT.CORE-E2E-007 (CTX) — P1: Missing `onepassword-connect` Secret → External Secrets fails readiness; verify failure then apply Secret and re-check readiness.
- BOOT.CORE-E2E-008 (CTX) — P1: `helmfile -f 01-core.yaml.gotmpl template` temporarily emits a CRD (simulated by local edit) → guard detects count>0 and fails.

## Risk Coverage Mapping
- TECH-001 (score 6): Covered by BOOT.CORE-UNIT-001/002 and -E2E-006.
- OPS-002 (score 6): Covered by -E2E-004/005/006 and -INT-003/004.
- SEC-001 (score 6): Covered by -E2E-007 and -INT-001.
- SEC-002 (score 4): Covered by -INT-001 and rollout checks.
- OPS-003 (score 4): Add preflight curl/HEAD to registries and ONEPASSWORD_CONNECT_HOST before Phase 2 (advisory).

## Recommended Execution Order
1. P0 Unit (BOOT.CORE-UNIT-001/002)
2. P0 Integration (INT-003)
3. P0 E2E (E2E-001..005)
4. P1 Integration/E2E (INT-001/002/004; E2E-006/007/008)
5. P2 (INT-005)

## Gate YAML Block
```yaml
test_design:
  scenarios_total: 14
  by_level:
    unit: 2
    integration: 5
    e2e: 7
  by_priority:
    p0: 7
    p1: 5
    p2: 2
  coverage_gaps: []
```

## Notes
- Where possible, prefer non-destructive validations (rollout status, get conditions) and avoid cluster mutations beyond necessary bootstrap.
- For CI-only validation of AC1, no cluster access required.
