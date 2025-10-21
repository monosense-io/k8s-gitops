# Test Design: Story STORY-BOOT-TALOS — Phase −1 Talos Bring‑Up

Date: 2025-10-21
Designer: Quinn (Test Architect)

## Test Strategy Overview

- Total test scenarios: 10
- By level: Unit 0 • Integration 3 • E2E 7
- Priority distribution: P0 5 • P1 4 • P2 1
- Environments: kube contexts `infra`, `apps`
- Tooling: talosctl, kubectl, flux, helmfile, minijinja-cli, op, jq, yq

## Preconditions
- `talos/<cluster>/*.yaml` present; `talos/machineconfig.yaml.j2` available
- Network egress to registries available

## Test Scenarios by Acceptance Criteria

### AC1 — Tasks-only flow (no manual commands)

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-E2E-001     | E2E         | P0       | Run `task cluster:create-<cluster>` end‑to‑end               | Primary user journey                   |
| BOOT-TALOS-E2E-002     | E2E         | P1       | Run `task bootstrap:talos` → phases 0..3 sequentially        | Alternate canonical path               |

### AC2 — Kubeconfig exported; CP nodes Ready

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-INT-003     | Integration | P0       | Validate kubeconfig path/contexts exist                      | Config/interface contract              |
| BOOT-TALOS-E2E-004     | E2E         | P0       | `kubectl --context=<cluster> get nodes` shows CP Ready       | End‑state readiness check              |

### AC3 — Health gate via `task cluster:health`

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-E2E-005     | E2E         | P0       | Run `task cluster:health` (Talos/K8s/CRDs/Flux)              | Composite health contract              |

### AC4 — Idempotency (re‑run safety)

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-E2E-006     | E2E         | P1       | Re-run `task bootstrap:talos` on healthy CP                  | Safe no‑op requirement                 |
| BOOT-TALOS-E2E-007     | E2E         | P1       | Re-run phases 0/1                                            | Safe re‑apply CRDs/prereqs             |

### AC5 — Role‑aware ordering (optional, future)

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-INT-008     | Integration | P2       | If `worker/*.yaml` present, apply workers after API ready    | Future‑proof behavior                  |

### AC6 — Safe detector (skip bootstrap on healthy CP; dry‑run plan)

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-E2E-009     | E2E         | P0       | Simulate healthy CP; rerun create to verify bootstrap skip   | Prevent double bootstrap               |
| BOOT-TALOS-E2E-010     | E2E         | P1       | DRY_RUN=true prints node/action plan                         | Operator safety                        |

### AC7 — Dev Notes artifacts present

| ID                     | Level       | Priority | Test                                                         | Justification                         |
|------------------------|-------------|----------|--------------------------------------------------------------|---------------------------------------|
| BOOT-TALOS-INT-011     | Integration | P1       | Verify Dev Notes include timestamps and key outputs          | Evidence and traceability              |

## Risk Coverage Mapping
- TECH-001 (safe‑detector) → BOOT‑TALOS‑E2E‑009/010
- SEC-001 (1Password Secret) → BOOT‑TALOS‑E2E‑005 (health) plus preflight checks
- TECH-002/TECH-003 (CRD align/CRDs‑only) → BOOT‑TALOS‑E2E‑007 and kubeconform in AC3 path
- OPS-001 (CP‑only pressure) → Observe in BOOT‑TALOS‑E2E‑005 health; add monitoring notes
- OPS-002 (drift) → Covered by “tasks only” + later CI dry‑run (docs requirement)

## Recommended Execution Order
1. P0 Integration: BOOT‑TALOS‑INT‑003 (kubeconfig)
2. P0 E2E: BOOT‑TALOS‑E2E‑001/002/004/005
3. P1 E2E: BOOT‑TALOS‑E2E‑006/007/010; P1 Integration: BOOT‑TALOS‑INT‑011
4. P2 Integration: BOOT‑TALOS‑INT‑008 (only if workers exist)

## Gate YAML Block

```yaml
test_design:
  scenarios_total: 10
  by_level:
    unit: 0
    integration: 3
    e2e: 7
  by_priority:
    p0: 5
    p1: 4
    p2: 1
  coverage_gaps: []
```

## Notes
- Capture timings and transient retries; attach key command excerpts in Dev Notes.
- Skip AC5 scenario when no `worker/*.yaml` is present.
