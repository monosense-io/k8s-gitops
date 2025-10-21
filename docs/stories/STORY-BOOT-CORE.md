# 03 — STORY-BOOT-CORE — Phase 1 Core Bootstrap (infra + apps)

Sequence: 03/22 | Prev: STORY-BOOT-CRDS.md | Next: STORY-NET-CILIUM-CORE-GITOPS.md

Status: Approved
Owner: Scrum Master → Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §6, §7, §4; docs/epics/EPIC-greenfield-multi-cluster-gitops.md §8; bootstrap/helmfile.d/00-crds.yaml; bootstrap/helmfile.d/01-core.yaml.gotmpl; bootstrap/helmfile.yaml; .taskfiles/bootstrap/Taskfile.yaml

## Story
As a Platform Engineer, I want to deploy the core infrastructure components to both clusters (infra, apps) using a GitOps‑first approach: perform a minimal one‑time bootstrap of the Cilium CNI, install Flux, and then let Flux reconcile all core components from `kubernetes/**` with deterministic ordering and health validation.

[Source: docs/architecture.md §6 (Bootstrap Architecture), §5 (Ordering/Health), §7 (Cluster Settings)]

## Why / Outcome
- Establish stable, minimal core needed for Flux to reconcile the repo end‑to‑end.
- Ensure CRDs were installed in Phase 0 and are not recreated here (crds disabled for charts).
- Keep one source of truth for chart values (bootstrap reads the same values used by Flux HelmReleases when possible).
- Confirm hand‑off criteria: flux‑operator/flux‑instance Ready; Git source connected; initial Kustomizations reconciling.

[Source: docs/architecture.md §6 — Handover to GitOps]

## Scope
Clusters: infra, apps
Components (managed by Flux under `kubernetes/**`; Cilium bootstrapped once via Helm CLI):
- Cilium (agent + operator) — GitOps HelmRelease at `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` (post‑bootstrap)
- CoreDNS — `kubernetes/infrastructure/networking/coredns/`
- cert‑manager — `kubernetes/infrastructure/security/cert-manager/`
- External Secrets — `kubernetes/infrastructure/security/external-secrets/`
- Flux (operator + instance) — `kubernetes/infrastructure/gitops/`

Namespaces expected/present prior to or during bootstrap:
- flux-system, external-secrets, cert-manager (others by chart defaults)

Non‑Goals
- Day‑2 features managed by Flux (e.g., Cilium BGP, Gateway, ClusterMesh secret), issuers, storage, observability — deferred to subsequent stories.

[Source: docs/architecture.md §6 (Phases), §9 (Networking day‑2), §8 (Secrets), §12 (CI/Policy)]

## Acceptance Criteria
1) Phase separation respected: Phase 0 installs CRDs; Phase 1 performs a one‑time imperative install of Cilium via Helm CLI, installs Flux, and then all components are reconciled via GitOps. No non‑GitOps controllers remain unmanaged after handover.
2) On both clusters, the following are Ready:
   - Control plane nodes (selector `node-role.kubernetes.io/control-plane`) are Ready (CNI operational).
   - Cilium DaemonSet and Operator (Ready/Available across all nodes).
   - CoreDNS Deployment replicas match `cluster-settings.yaml` (infra: 2; apps: 2) and are Available.
   - External Secrets controller Deployment Available in `external-secrets` namespace.
   - cert‑manager controller & webhook Deployments Available in `cert-manager` namespace.
3) Flux is operational on both clusters:
   - flux‑operator controllers running and Ready.
   - flux‑instance reports Ready; `flux get sources git flux-system` and `flux get kustomizations -A` return Ready for initial objects.
4) Handover criteria met (architecture §6): GitRepository connected; initial Kustomizations reconcile successfully; subsequent changes are applied by Flux.
5) All commands, outputs (key excerpts), and any deviations captured in Dev Notes.

6) All P0 test scenarios from docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md pass on both clusters (infra, apps); execution artifacts captured in Dev Notes. QA gate moves from CONCERNS to PASS or waivers are documented.
7) Cilium core is under GitOps control post‑bootstrap: `kubernetes/infrastructure/kustomization.yaml` includes `networking/cilium/core/ks.yaml`; a reconcile after uninstalling the Helm‑CLI release results in Flux re‑creating the Cilium resources.

[Source: docs/architecture.md §6 (Handover Criteria), §5 (Health/dependsOn), §4 (Repo Layout)]

## Dependencies / Inputs
- STORY‑BOOT‑CRDS completed and validated (CRDs Established on both clusters).
- KUBECONFIG contexts `infra`, `apps` configured and working.
- bootstrap resources prepared:
  - `bootstrap/prerequisites/resources.yaml` applies namespaces and the 1Password Connect bootstrap Secret (`external-secrets/onepassword-connect`).
- Taskfile automation available in `.taskfiles/bootstrap/Taskfile.yaml` (phase:2 now calls `core:gitops`).
- Cilium values for imperative bootstrap present in `bootstrap/clusters/<cluster>/cilium-values.yaml`.

[Source: docs/epics/EPIC-greenfield-multi-cluster-gitops.md §8; docs/architecture.md §6]

## Tasks / Subtasks (Taskfile is canonical)
- [ ] T0 — Preflight (AC: —)
  - [ ] `task :bootstrap:phase:0 CLUSTER=infra` and `task :bootstrap:phase:0 CLUSTER=apps`
- [ ] T1 — Deploy core (Phase 2) (AC: 2)
  - [ ] `task :bootstrap:phase:2 CLUSTER=infra` and `task :bootstrap:phase:2 CLUSTER=apps` (uses `core:gitops` → Cilium via Helm CLI → Flux install → Flux reconcile)
- [ ] T2 — Validate (Phase 3) (AC: 2)
  - [ ] `task :bootstrap:phase:3 CLUSTER=infra` and `task :bootstrap:phase:3 CLUSTER=apps`
  - [ ] `task bootstrap:status CLUSTER=infra` and `task bootstrap:status CLUSTER=apps`
- [ ] T3 — Flux handover checks (AC: 3, 4)
  - [ ] `flux --context=<ctx> get sources git flux-system -n flux-system`
  - [ ] `flux --context=<ctx> get kustomizations -A`
- [ ] T4 — Record artifacts (AC: 5)
  - [ ] Capture key `kubectl`/`flux` outputs in Dev Notes; note any deviations.

- [ ] T5 — Execute P0 tests (AC: 6)
  - [ ] Run all P0 scenarios from docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md for infra and apps.
  - [ ] Archive command outputs/logs and link them in Dev Notes.

- [ ] T6 — Negative tests (optional) (AC: —)
  - [ ] Simulate missing `onepassword-connect` Secret (lab only) to observe External Secrets failure, then restore and confirm recovery.
  - [ ] Verify CRD guard detects any accidental CRDs emitted by 01-core template (local dry-run).

### Appendix: Underlying raw commands (reference only)
- `kubectl --context=<ctx> apply -f bootstrap/prerequisites/resources.yaml`
- `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <ctx> sync`

[Source: docs/architecture.md §6; bootstrap/helmfile.d/README.md]

## Validation Steps (CLI)
- Phase separation (AC: 1)
  - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <ctx> template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l`  # Expect 0
- Cilium
  - `kubectl --context=<ctx> -n kube-system rollout status ds/cilium --timeout=5m`
  - `kubectl --context=<ctx> -n kube-system rollout status deploy/cilium-operator --timeout=5m`
- CoreDNS
  - `kubectl --context=<ctx> -n kube-system rollout status deploy/coredns --timeout=5m`
- External Secrets
  - `kubectl --context=<ctx> -n external-secrets rollout status deploy/external-secrets --timeout=5m`
- cert‑manager
  - `kubectl --context=<ctx> -n cert-manager rollout status deploy/cert-manager --timeout=5m`
  - `kubectl --context=<ctx> -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m`
- Flux
  - `kubectl --context=<ctx> -n flux-system get pods`
  - `flux --context=<ctx> get sources git flux-system -n flux-system`
  - `flux --context=<ctx> get kustomizations -A`

- P0 Test Execution (AC: 6)
  - Follow docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md (IDs: BOOT.CORE-UNIT-001/002; INT-003; E2E-001..005) on both clusters and capture results.
  - Optional negative: BOOT.CORE-E2E-007/008 per design doc (lab only).

Success criteria: all rollouts complete; Flux source and initial Kustomizations Ready.

## Rollback
- Use `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <ctx> destroy` for targeted rollback if needed.
- If only specific components need re-apply, use chart-specific `helmfile -l name=<release> sync`.
- For Flux issues, suspend Kustomizations as needed; do not remove CRDs.

Risks / Mitigations
- Missing bootstrap Secret → External Secrets controller starts but cannot sync; ensure `onepassword-connect` Secret present and valid.
- Version mismatch vs. CRD bundle → align chart versions between 00‑crds and 01‑core.
- Network constraints (egress) → pre‑flight checks; retries; use mirrors.

## Definition of Done
- All Acceptance Criteria met on both clusters.
- Hand‑off to Flux verified; initial Kustomizations green.
- Dev Notes include commands and excerpts.
- All P0 test scenarios pass and QA gate recorded as PASS (or explicit waivers documented in QA Results).

## Dev Notes
Relevant architecture extracts (summarized):
- Phases: Phase 0 installs CRDs only via `00-crds.yaml` (with yq CRD filter). Phase 1 installs core controllers with CRDs disabled (Cilium → CoreDNS → Spegel → cert‑manager → External Secrets → Flux). [Source: docs/architecture.md §6]
- Repo entrypoints: each cluster has `flux-system/kustomization.yaml` that reconciles `cluster-settings.yaml`, `infrastructure.yaml`, `workloads.yaml` with `prune`, `wait`, `timeout`, `healthChecks`, and `postBuild.substituteFrom` (ConfigMap `cluster-settings`). [Source: docs/architecture.md §5]
- Handover criteria: flux‑operator Ready → flux‑instance Ready → GitRepository connected → initial Kustomizations reconciling. [Source: docs/architecture.md §6]
- Directory alignment: keep `kubernetes/clusters/<cluster>/*` and bootstrap files in `bootstrap/helmfile.d/*.yaml`. [Source: docs/architecture.md §4]

File/Path pointers for this story:
- `bootstrap/helmfile.d/00-crds.yaml` (completed in STORY‑BOOT‑CRDS)
- `bootstrap/helmfile.d/01-core.yaml.gotmpl` (this story)
- `.taskfiles/bootstrap/Taskfile.yaml` (phase:2 core if using Task)
- `kubernetes/clusters/<cluster>/flux-system/*` (Flux entry + settings)
 - `kubernetes/clusters/infra/flux-system/gotk-sync.yaml`, `kubernetes/clusters/apps/flux-system/gotk-sync.yaml`

### Testing
- Preferred: use `kubectl rollout status` and `flux get` commands in Validation Steps.
- CI (separate story): kubeconform, `kustomize build`, `flux build` to ensure manifests converge.

### Refactor Notes (Option A — GitOps‑first)
- Deprecated: Helmfile `01-core.yaml.gotmpl` for ongoing management; retained for historical reference only.
- New GitOps resources:
  - `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`
  - `kubernetes/infrastructure/networking/cilium/core/ks.yaml`
  - `kubernetes/infrastructure/kustomization.yaml` now includes `networking/cilium/core/ks.yaml`

## Change Log
| Date       | Version | Description                                   | Author |
|------------|---------|-----------------------------------------------|--------|
| 2025-10-21 | 1.0     | Initial draft created                         | SM     |
| 2025-10-21 | 1.1     | PO correct-course: critical/should/nice fixes | PO     |

## Dev Agent Record
### Agent Model Used
<fill by Dev Agent>

### Debug Log References
<fill by Dev Agent>

### Completion Notes List
<fill by Dev Agent>

### File List
<fill by Dev Agent>

## QA Results
QA Risk Profile (2025-10-21)

- Overall Risk Rating: Moderate
- Overall Story Risk Score: 51/100
- Suggested Gate Decision: CONCERNS (presence of multiple High=6 risks)

Top Risks
- TECH-001 (6): Phase ordering broken (CRDs missing or inline CRDs in core).
- OPS-002 (6): Flux postsync fails; GitOps handover blocked.
- SEC-001 (6): 1Password Connect bootstrap token invalid → External Secrets cannot sync.

Key Mitigations (excerpt)
- Enforce phase guard in CI (zero CRDs from 01-core template).
- Pre-validate gotk-sync presence; verify postsync logs; manual apply fallback.
- Verify `external-secrets/onepassword-connect` Secret present; smoke-test an ExternalSecret.

Risk-Based Testing Focus
- Priority 1: Phase-guard check; Flux source/Kustomizations Ready; ExternalSecret smoke.
- Priority 2: Egress checks to registries/1Password; monitor controller restarts.
- Priority 3: CoreDNS clusterIP check; cert-manager webhook readiness; `cilium status`.

Artifacts
- Full assessment: docs/qa/assessments/STORY-BOOT-CORE-risk-20251021.md

QA Test Design (2025-10-21)
- Test design doc: docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md
- Scenarios: 14 total (Unit 2, Integration 5, E2E 7). P0: 7, P1: 5, P2: 2.
- Coverage: All ACs covered; risk mapping aligned to TECH-001/OPS-002/SEC-001.

## *** End of Story ***


## PO Validation (docs/stories/STORY-BOOT-CORE.md)

Status: NO-GO — Needs Revision (see issues below)
Date: 2025-10-21

Validation Summary
- Overall: Strong draft with clear AC and validation steps; blocked by a few path mismatches and missing template sections needed by Dev/QA agents.
- Implementation Readiness Score: 8/10
- Confidence (post-fix): High

Template Compliance Issues
- Missing required template sections for agent workflows:
  - Dev Agent Record (and subsections: Agent Model Used, Debug Log References, Completion Notes, File List)
  - Change Log
  - QA Results
- Tasks/Subtasks are not in checkbox form (expected `- [ ]` items) for Dev Agent progress tracking.

Critical Issues (Must Fix)
1) Wrong file path in Tasks/Dependencies: `bootstrap/resources.yaml` → actual path is `bootstrap/prerequisites/resources.yaml`.
2) Helmfile path mismatch: story references `bootstrap/helmfile.d/01-core.yaml`, but repo uses `bootstrap/helmfile.d/01-core.yaml.gotmpl` (and the top-level `bootstrap/helmfile.yaml` imports `helmfile.d/01-core.yaml`).
   - Fix commands to use `-f bootstrap/helmfile.d/01-core.yaml.gotmpl` (as in `.taskfiles/bootstrap/Taskfile.yaml`) or instruct using the orchestrator `bootstrap/helmfile.yaml`.
3) Add the missing template sections so Dev and QA agents can update the story per BMAD rules.

Should-Fix (Quality Improvements)
- Map each task to Acceptance Criteria numbers (e.g., T2 → AC2, T4 → AC3/AC4).
- Under Validation Steps, include the explicit CRD absence check for AC1:
  - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <ctx> template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l  # expect 0`
- Align core-config with current docs layout to reduce confusion:
  - `.bmad-core/core-config.yaml` currently has `prdSharded: true` and `architectureSharded: true`, but this repo uses monolithic `docs/prd.md` and `docs/architecture.md`.

Nice-to-Have
- Add quick links to `kubernetes/clusters/<cluster>/flux-system/gotk-sync.yaml` referenced by the postsync hook.
- Note that Spegel is intentionally disabled during bootstrap (Talos rootfs), consistent with 01-core gotmpl.

Anti‑Hallucination Findings
- All cited components/flows match `docs/architecture.md` §4/§5/§6 and `bootstrap/helmfile.d/01-core.yaml.gotmpl`.
- No invented libraries/patterns detected; references are accurate and present in the repo.

Final Assessment
- Decision: NO-GO until Critical Issues are addressed.
- After fixes, update top `Status: Approved` and proceed.

---

## PO Validation (v2) — Post Correct-Course (docs/stories/STORY-BOOT-CORE.md)

Status: GO — Approved
Date: 2025-10-21

Validation Summary
- All critical fixes applied (paths, helmfile refs), should-fix improvements added (task→AC mapping, CRD absence check), nice-to-haves included (gotk-sync links); agent sections added.
- Implementation Readiness Score: 9/10
- Confidence: High

Notes
- Core-config alignment to monolithic docs remains as a follow-up outside this story.

Decision
- GO — Ready for Dev implementation.

## PO Validation (v3) — Final Pre‑Dev (docs/stories/STORY-BOOT-CORE.md)

Status: GO — Approved
Date: 2025-10-21

Validation Summary
- Template: Required sections present (Status, Story, Acceptance Criteria, Tasks/Subtasks, Dev Notes, Change Log, Dev Agent Record, QA Results). A standalone “Testing” section exists and is acceptable; future stories should prefer it nested under Dev Notes per template.
- AC Coverage: AC1–AC6 are clear and testable. Tasks map to ACs; validation steps include AC1 CRD‑guard and AC6 P0 execution.
- References: Paths verified (01-core.yaml.gotmpl; prerequisites/resources.yaml; gotk-sync.yaml links). Architecture/epic alignment OK.
- QA Integration: Risk profile and test design linked; DoD updated to require P0 pass or waivers.

Issues/Notes
- None blocking. Core-config shard flags review remains outside this story.

Decision
- GO — Proceed to Dev.
