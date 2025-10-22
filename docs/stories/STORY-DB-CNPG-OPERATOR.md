# 17 — STORY-DB-CNPG-OPERATOR — CloudNativePG Operator

Sequence: 17/26 | Prev: STORY-STO-ROOK-CEPH-CLUSTER.md | Next: STORY-DB-CNPG-SHARED-CLUSTER.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §10; docs/architecture.md §B.3 (CNPG Quick Guide); kubernetes/bases/cloudnative-pg/operator/helmrelease.yaml; kubernetes/bases/cloudnative-pg/operator/namespace.yaml; bootstrap/helmfile.d/00-crds.yaml; kubernetes/clusters/infra/cluster-settings.yaml

## Story
Deploy CloudNativePG (CNPG) operator via Flux to manage PostgreSQL clusters declaratively.

## Why / Outcome
- Reliable, operator‑managed Postgres with backups, monitoring, and poolers.

## Scope
- Clusters: infra (primary), apps optional for client CRDs only
- Resources: `bases/cloudnative-pg/operator` HelmRelease and PrometheusRule

## Acceptance Criteria
1) CNPG operator Available; CRDs registered and Established.
2) Operator runs with replicas ≥ 2 and a PDB with minAvailable: 1 in `cnpg-system`.
3) Namespace `cnpg-system` enforces PSA `restricted` (no privileged), pods run successfully.
4) Operator metrics PodMonitor enabled and scraped; `up{job="cnpg-system/cloudnative-pg-metrics"}` present in VictoriaMetrics.
5) CNPG CRD bundle and operator chart minor versions are aligned (choose 0.25.x or 0.26.x) and documented in this story’s Dev Notes; evidence of versions recorded in PR.
6) Watch scope decision documented (cluster‑wide vs namespace‑scoped) and configured in chart values; corresponding validation evidence recorded.

## Dependencies / Inputs
- Rook‑Ceph StorageClass available for PVCs.

## Tasks / Subtasks
- [ ] Reconcile operator; verify CRDs and controller health.
- [ ] Set operator HA (AC2)
  - [ ] Edit `kubernetes/bases/cloudnative-pg/operator/helmrelease.yaml` to ensure `values.replicaCount: 2` and a PDB with `minAvailable: 1` (or add a PDB manifest if chart lacks it).
- [ ] Enforce PSA restricted (AC3)
  - [ ] Edit `kubernetes/bases/cloudnative-pg/operator/namespace.yaml` to set:
        `pod-security.kubernetes.io/enforce: restricted`, `audit: restricted`, `warn: restricted`.
- [ ] Enable metrics PodMonitor (AC4)
  - [ ] In `kubernetes/bases/cloudnative-pg/operator/helmrelease.yaml`, enable PodMonitor via chart value (e.g., `monitoring.podMonitorEnabled: true` or chart-equivalent); align labels to VM operator selectors if needed.
- [ ] Align CRDs and chart minors (AC5)
  - [ ] Pin CNPG CRD bundle minor in `bootstrap/helmfile.d/00-crds.yaml` to match operator chart minor.
  - [ ] Set `CNPG_OPERATOR_VERSION` in `kubernetes/clusters/infra/cluster-settings.yaml` to the same minor.
- [ ] Decide and configure watch scope (AC6)
  - [ ] Document decision in this story and architecture B.3; configure via chart (e.g., `config.clusterWide: true|false`) instead of only env `WATCH_NAMESPACE`.
- [ ] Update references in docs/architecture.md if necessary (B.3 anchors, version table).

---

## Research — Operator Best Practices (Shared Cluster)

- Scope and install methods: CNPG provides static manifests and a `kubectl cnpg` plugin that can generate operator manifests with overrides such as watch namespaces. Helm chart supports cluster‑wide or single‑namespace operation via `config.clusterWide`. For a shared cluster serving multiple namespaces, cluster‑wide is typical; for stronger isolation, run additional namespace‑scoped operators with care to avoid collisions. citeturn0search5turn0search7turn2search1
- Replicas and HA: Default deployment is a single replica; increase replicas and add a PDB for operator HA in production to avoid control‑plane single points of failure. This complements GitOps drift correction and webhook availability. citeturn2search8
- Pod security: CNPG explicitly does not require privileged containers and enforces read‑only root FS. Adopt Kubernetes Pod Security Standards at `restricted` where possible; no component requires root. citeturn0search4turn0search10
- CRDs alignment: Install CRDs before the operator and keep chart/CRD versions aligned per minor to avoid schema drift between webhook validation and reconciler logic. (Design inference; verify against your upgrade policy.) citeturn0search5
- Monitoring: Enable operator metrics via PodMonitor; Grafana dashboards are optional. Helm chart exposes `monitoring.podMonitorEnabled` and label hooks for Prometheus operators. citeturn2search1

## Gap Analysis — Repo vs Best Practices

- Namespace PSA: `cnpg-system` namespace is labeled `pod-security.kubernetes.io/enforce: privileged`. CNPG does not require privileged mode; move to `restricted` (or at least `baseline`). citeturn0search10
- Version skew: CRDs are pinned at `0.26.0` (bootstrap/helmfile) while the operator chart version is parameterized to `0.25.0`. Align CRD and chart minor versions to reduce incompatibility risk during validation/upgrades. (Best‑practice inference.) citeturn2search0
- Watch scope: Values set `WATCH_NAMESPACE: ""` (watch all). For multi‑tenant shared cluster this is acceptable; if you later restrict to namespace‑scoped operation, set `config.clusterWide=false` and ensure no collisions with any cluster‑wide operator. citeturn2search1

## Tasks / Subtasks — Operator Hardening & Hygiene

- [ ] Change `kubernetes/bases/cloudnative-pg/operator/namespace.yaml` PSA labels from `privileged`→`restricted`; verify operator pods start and webhooks admit Cluster/Pooler CRs. citeturn0search10
- [ ] Align CRDs and operator chart minors (e.g., use the same `0.25.x` or `0.26.x` for both). Update `bootstrap/helmfile.d/00-crds.yaml` and `CNPG_OPERATOR_VERSION` in `kubernetes/clusters/*/cluster-settings.yaml` together. (Version‑alignment best practice.)
- [ ] Keep operator HA: retain `replicaCount: 2`, PDB `minAvailable: 1`, and anti‑affinity across hosts; add a rollout check in CI. citeturn2search8
- [ ] Validate PodMonitor labels integration with VictoriaMetrics (job naming); keep our `PrometheusRule` alerts for operator health.
- [ ] Document watch scope decision (cluster‑wide vs namespace‑scoped) in architecture and enforce via chart (`config.clusterWide`) instead of only `WATCH_NAMESPACE`. citeturn2search1

## Validation Steps — Operator

- `kubectl --context=infra -n cnpg-system rollout status deploy/cloudnative-pg` and webhook readiness.
- `kubectl --context=infra api-resources | rg postgresql.cnpg.io` to confirm CRDs present.
- Confirm PSA: `kubectl --context=infra label ns cnpg-system pod-security.kubernetes.io/enforce=restricted --overwrite` in a test branch and reconcile.

### Additional Validation (AC2–AC6)
- Operator HA: `kubectl --context=infra -n cnpg-system get deploy cloudnative-pg -o jsonpath='{.spec.replicas}'` → `2`
- PDB: `kubectl --context=infra -n cnpg-system get pdb`
- PodMonitor: `kubectl --context=infra -n cnpg-system get podmonitor -A`; verify `up{job="cnpg-system/cloudnative-pg-metrics"}` exists in VM
- PSA labels: `kubectl --context=infra get ns cnpg-system -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'` → `restricted`
- Version alignment: capture CRD and chart versions from manifests/HelmRelease in PR description
- Watch scope: verify `config.clusterWide` (or equivalent) is set; confirm operator events show correct watch scope

## Validation Steps
- flux -n flux-system --context=infra reconcile ks cluster-infra-infrastructure --with-source
- kubectl --context=infra -n cnpg-system get deploy

## Definition of Done
- ACs met; evidence recorded in Dev Notes and `docs/qa/evidence/story-db-cnpg-operator/`.
- QA Gate decision file exists under `docs/qa/gates/` for this story with status PASS or PASS WITH CONCERNS, and risks acknowledged.
- All validation steps executed (including Additional Validation AC2–AC6) with artifacts attached.

---

## Dev Notes

- Target cluster: infra (`cnpg-system` namespace). Apps cluster consumes CRDs only when needed.
- Chosen CNPG minor (chart): 0.26.x (use `v0.26.0` as the starting pin); upstream operator app version paired with this chart is `v1.27.0` released 2025‑08‑12. Document any patch bumps within 0.26.x in PRs. 
- Operator HA: run with `replicaCount: 2` and protect with PDB `minAvailable: 1`.
- Pod Security Admission: enforce namespace labels to `restricted`; CNPG does not require privileged.
- Monitoring: enable PodMonitor via chart value; ensure labels match our VM operator selectors.
- Version alignment: choose one minor (0.25.x or 0.26.x) and keep CRDs bundle and operator chart on the same minor. Update `bootstrap/helmfile.d/00-crds.yaml` and `CNPG_OPERATOR_VERSION` in `kubernetes/clusters/infra/cluster-settings.yaml` together.
- Watch scope: default to cluster‑wide for shared infra; if switching to namespace‑scoped later, document and change `config.clusterWide` accordingly.
- File touch‑points:
  - `kubernetes/bases/cloudnative-pg/operator/helmrelease.yaml`
  - `kubernetes/bases/cloudnative-pg/operator/namespace.yaml`
  - `bootstrap/helmfile.d/00-crds.yaml`
  - `kubernetes/clusters/infra/cluster-settings.yaml`

## Rollout Plan (Short)

1) Stage
   - Pin chart to `0.26.0` and align CRD bundle minor to `0.26.x` in a feature branch.
   - Reconcile in staging/infra; confirm operator comes up with replicas=2, PDB in place, PSA restricted.
2) Validate
   - Verify PodMonitor discovery and VM series `up{job="cnpg-system/cloudnative-pg-metrics"}`.
   - Run QA Test Design T1.*–T6.* scenarios; attach evidence under `docs/qa/evidence/story-db-cnpg-operator/`.
3) Prod
   - Merge and reconcile on infra; monitor alerts for 24–48h and complete QA Gate.

## Testing

- Operator availability, replicas, and PDB present.
- PSA enforcement verified and pods stay Ready.
- PodMonitor resources created; time series visible in VictoriaMetrics (`up{job="cnpg-system/cloudnative-pg-metrics"}`).
- Version alignment validated by inspecting manifests and runtime image/chart metadata.
- Watch scope behaves as configured (cluster‑wide vs namespace‑scoped) — verify event logs and reconcile behavior.
 - Archive CLI outputs, screenshots, and queries under `docs/qa/evidence/story-db-cnpg-operator/` using test IDs from QA Test Design.

## Change Log

| Date       | Version | Description                                        | Author        |
|------------|---------|----------------------------------------------------|---------------|
| 2025-10-21 | 0.2     | PO correct‑course: ACs hardened; tasks explicit; Dev Notes/Testing added | PO (Sarah)    |
| 2025-10-21 | 0.3     | PO correct‑course: integrated QA Risk & Test Design; DoD requires QA Gate and evidence archive | PO (Sarah)    |

## Dev Agent Record

### Agent Model Used

_TBD during implementation_

### Debug Log References

_TBD during implementation_

### Completion Notes List

_TBD during implementation_

### File List

_TBD during implementation_

## QA Results

### Risk Profile (2025-10-21)

- Method: Probability × Impact with qualitative tiers; focus on operator HA, PSA, monitoring, version alignment, and watch-scope configuration.

Risk Matrix
- R1 — CRD/Chart Minor Version Skew
  - Probability: Medium | Impact: High | Priority: High
  - Evidence: CRDs 0.26.0 vs operator chart 0.25.0 (current repo findings)
  - Mitigation: Align bundle and chart minors; pin `CNPG_OPERATOR_VERSION` and CRD bundle together; validate in infra first.
  - Verification: kubernetes manifest review + `helm list`/controller logs; record versions in PR.

- R2 — PSA Enforcement Change Blocks Pods
  - Probability: Medium | Impact: High | Priority: High
  - Mitigation: Apply PSA `restricted` in a branch, reconcile, confirm Deploy Ready before merge.
  - Verification: `kubectl get ns cnpg-system -o jsonpath` shows `restricted`; operator pods Ready.

- R3 — Operator Not HA (replicas<2) or Missing PDB
  - Probability: Medium | Impact: High | Priority: High
  - Mitigation: Set `replicaCount: 2`; add PDB `minAvailable: 1`; anti‑affinity.
  - Verification: `kubectl -n cnpg-system get deploy cloudnative-pg -o jsonpath='{.spec.replicas}'`, `get pdb`.

- R4 — PodMonitor/Labels Mismatch → No Metrics
  - Probability: Medium | Impact: Medium | Priority: Medium
  - Mitigation: Enable PodMonitor via chart; ensure labels match VM operator selector; confirm series appear.
  - Verification: `kubectl -n cnpg-system get podmonitor -A`; VM query `up{job="cnpg-system/cloudnative-pg-metrics"}`.

- R5 — Watch Scope Misconfigured (too broad/narrow)
  - Probability: Medium | Impact: Medium‑High | Priority: Medium‑High
  - Mitigation: Decide cluster‑wide vs namespace‑scoped; configure via `config.clusterWide`; document; check reconcile events.
  - Verification: Operator logs/events show expected watched namespaces; functional CRUD tests of Cluster/Pooler.

- R6 — CRD Ordering/Timing Issues During Bootstrap
  - Probability: Low‑Medium | Impact: High | Priority: Medium
  - Mitigation: Keep CRD‑only phase (helmfile 00‑crds), then operator; CI kubeconform/kustomize/`flux build` checks.

- R7 — Resource Limits Too Low (throttle/OOM)
  - Probability: Medium | Impact: Medium | Priority: Medium
  - Mitigation: Start with sane requests/limits; watch container memory working set; alert at 90% of limit.

- R8 — RBAC/Webhook Admission Constraints
  - Probability: Low‑Medium | Impact: Medium‑High | Priority: Medium
  - Mitigation: Validate ClusterRoles/Bindings with chart defaults; confirm webhook service health before CRs.

Test Focus & Evidence Mapping
- AC2 (HA/PDB): Replica=2; PDB present; anti‑affinity verified.
- AC3 (PSA restricted): Namespace labels applied; pods Ready post‑change.
- AC4 (Metrics): PodMonitor exists; VM time series present; dashboard panel shows operator metrics.
- AC5 (Version alignment): Manifest/values show same minor; versions captured in PR.
- AC6 (Watch scope): `config.clusterWide` state verified; reconcile behavior tested.

Gate Suggestion
- Decision: PASS WITH CONCERNS
- Rationale: Story is implementable with added ACs and tasks; ensure version alignment decision (0.25.x vs 0.26.x) is explicitly picked before merge.

### Test Design (2025-10-21)

Scope
- Validate Acceptance Criteria AC1–AC6 for CNPG operator installation and hardening on infra cluster.

Prerequisites
- Flux healthy on infra; External Secrets operational; cluster-settings applied.
- `cnpg-system` namespace exists; operator HelmRelease present in Git.

Traceability
| AC | Test IDs |
|----|----------|
| AC1 | T1.1–T1.3 |
| AC2 | T2.1–T2.3 |
| AC3 | T3.1–T3.3 |
| AC4 | T4.1–T4.3 |
| AC5 | T5.1–T5.3 |
| AC6 | T6.1–T6.3 |

Scenarios (Given/When/Then)
- T1.1 — Operator Deployment Ready
  - Given Flux reconciles infra
  - When I check `deploy/cloudnative-pg` in `cnpg-system`
  - Then the deployment is Available and Ready ≥ desired replicas

- T1.2 — CRDs Established
  - Given the cluster API resources
  - When I list `postgresql.cnpg.io` and other CNPG CRDs
  - Then their Established condition is True

- T1.3 — Webhooks Healthy
  - Given the operator webhook service
  - When I create a dry-run CNPG `Cluster` manifest
  - Then the admission passes without errors

- T2.1 — HA Replicas
  - Given `spec.replicas` is set to 2 in HelmRelease values
  - When I query the deployment
  - Then `.spec.replicas == 2` and `.status.availableReplicas == 2`

- T2.2 — PDB Present
  - Given PDB is applied for operator
  - When I list PDBs in `cnpg-system`
  - Then a PDB with `minAvailable: 1` exists for the operator selector

- T2.3 — Disruption Tolerance (Simulated)
  - Given two operator pods on distinct nodes
  - When I cordon+drain one node (simulation in staging)
  - Then at least one operator pod remains available throughout

- T3.1 — PSA Labels Enforced
  - Given namespace labels set to `restricted`
  - When I get the namespace labels
  - Then `pod-security.kubernetes.io/enforce=restricted`

- T3.2 — Operator Starts Under PSA
  - Given PSA restricted is enforced
  - When I reconcile the operator
  - Then operator pods reach Ready (no PSP/privileged violations)

- T3.3 — Privileged Pod Denied (Negative)
  - Given PSA restricted in `cnpg-system`
  - When I attempt to run a privileged pod in that namespace
  - Then admission denies the request

- T4.1 — PodMonitor Exists
  - Given Helm values enable PodMonitor
  - When I list PodMonitors in `cnpg-system`
  - Then the CNPG operator PodMonitor is present

- T4.2 — Metrics Scraped
  - Given vmagent is configured to scrape
  - When I query `up{job="cnpg-system/cloudnative-pg-metrics"}` in VM
  - Then at least one series is 1 over a 5‑minute window

- T4.3 — Alert Validity (Smoke)
  - Given `cloudnative-pg-operator` PrometheusRule
  - When I temporarily scale the operator to 0 in a test env
  - Then the “operator down” alert fires in vmalert (observability env only)

- T5.1 — Version Pins in Git
  - Given repo manifests
  - When I inspect `bootstrap/helmfile.d/00-crds.yaml` and `CNPG_OPERATOR_VERSION` in cluster-settings
  - Then both are set to the same minor (0.25.x or 0.26.x)

- T5.2 — Runtime Versions
  - Given the reconciled resources
  - When I check CRD versions and HelmRelease resolved chart version
  - Then minor versions match the chosen pin

- T5.3 — Upgrade Dry-Run (Optional)
  - Given staging environment
  - When I trial a patch bump within the chosen minor
  - Then no validation or webhook errors occur

- T6.1 — Watch Scope Configured
  - Given a value for `config.clusterWide`
  - When I check the operator ConfigMap/args
  - Then it reflects the chosen watch scope

- T6.2 — Reconcile Within Scope
  - Given a namespaced CNPG `Cluster` in an in-scope namespace
  - When I apply the CR
  - Then the operator reconciles it (events show progress)

- T6.3 — Out-of-Scope Isolation (If namespace-scoped)
  - Given a CR in an out-of-scope namespace
  - When I apply it
  - Then the operator ignores it; no reconcile events from operator

Artifacts & Evidence
- Store output from kubectl/flux/VM queries in QA evidence: `docs/qa/evidence/` with test IDs.
