# Sprint Change Proposal — STORY-DB-DRAGONFLY-OPERATOR-CLUSTER (QA Integration) — 2025-10-22

Owner: Product Owner (Sarah)
Contributors: QA (Quinn), Scrum Master (Bob)
Related Story: docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
Related QA Artifacts:
- Risk Profile: docs/qa/assessments/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER-risk-20251022.md
- Test Design: docs/qa/assessments/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER-test-design-20251022.md

## 1) Analysis Summary
- Trigger: QA risk profile flags two high risks: missing NetworkPolicy (SEC-001) and missing data‑plane PDB (OPS-001); several medium risks: anti‑affinity/topology spread, ExternalSecret path validation/alerting, cross‑cluster latency SLOs, version alignment.
- Impact: Cache may be reachable by unintended workloads; voluntary disruptions can reduce availability; co‑scheduling reduces HA; miswired secrets can block access.
- Path Forward: Add NetworkPolicy and PDB; add anti‑affinity/topology spread; keep ESO preflight/alerting and latency observation in story validation; leave per‑tenant examples as docs only.

## 2) Proposed Edits (for approval)

### A. Story — docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
1. Links — add NetworkPolicy and PDB files when created:
   - `kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml`
   - `kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml`
2. Validation — already includes PDB checks and topology check. Add explicit NP enforcement note: run allow/deny `nc` from allowed/disallowed namespaces (mapped in QA test design IDs DFLY‑E2E‑003/DFLY‑INT‑010).

### B. Manifests — Minimal, Safe Fixes
1. NetworkPolicy (critical)
   - File: `kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml` (new)
   - Policy: default‑deny ingress; allow TCP/6379 from `gitlab-system`, `harbor`, and a short allowlist of app namespaces; allow `observability` to TCP/8080 for metrics; allow DNS egress if required by operator sidecars.

2. Data‑plane PDB (critical)
   - File: `kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml` (new)
   - Spec: `policy/v1` PDB with `minAvailable: 2` selecting Dragonfly data pods.
   - Add to `kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml`.

3. Topology spread / Anti‑affinity (should‑fix)
   - File: `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml`
   - Add either `topologySpreadConstraints` across `kubernetes.io/hostname` with `maxSkew: 1` or `podAntiAffinity` (preferred) to distribute 3 pods across nodes.

4. SecurityContext hardening (should‑fix)
   - File: `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml`
   - Under `podTemplate.spec` add: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, and drop all capabilities (if operator supports container securityContext passthrough).

5. Operator PDB (confirm)
   - `kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml` already has PDB enabled with `minAvailable: 1` — no change unless we see gaps.

### C. Documentation
- Add a short NetworkPolicy example snippet to story Dev Notes once merged.
- (Optional) Add `docs/examples/dragonfly-gitlab.yaml` per‑tenant CR stub referenced by the story (no rollout).

## 3) Mapping to QA Artifacts
- Risks mitigated: SEC‑001 (NP), OPS‑001 (PDB), TECH‑001 (spread/anti‑affinity), OPS‑002 (ESO preflight), PERF‑001 (latency observation/SLO).
- Test design coverage: P0 scenarios DFLY‑UNIT‑001, DFLY‑INT‑001/002/004/005/006/010/008, DFLY‑E2E‑001/002/003/005.

## 4) Decisions Required
- Allowed namespaces for NP ingress (defaults): `gitlab-system`, `harbor`; list additional app namespaces if any.
- Spread strategy: `podAntiAffinity` vs `topologySpreadConstraints` (recommend podAntiAffinity).
- Security context: confirm operator CR supports container/pod security context passthrough; otherwise document limitation.
- Latency SLO targets (e.g., p95 < 10ms intra‑cluster, < 20ms cross‑cluster) — advisory only.

## 5) Gate Suggestion
- Maintain QA gate as CONCERNS until NetworkPolicy + data‑plane PDB are merged and P0 tests pass.

## 6) Implementation Plan (once approved)
- Commit in order: NetworkPolicy → PDB → CR spread/anti‑affinity → securityContext → docs updates.
- Run P0 tests from test design and attach evidence under `docs/qa/evidence/`.

## 7) Approval Checklist
- [ ] Approve NP allowed namespaces list
- [ ] Approve adding PDB for data plane (minAvailable: 2)
- [ ] Choose spread strategy: anti‑affinity or topology spread
- [ ] Approve securityContext hardening (if supported)
- [ ] Approve story validation note for NP enforcement

---

If approved, I will apply the changes and notify QA to re‑run P0 scenarios.
