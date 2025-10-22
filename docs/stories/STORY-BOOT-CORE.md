# 40 — STORY-BOOT-CORE — Phase 1 Core Bootstrap (infra + apps)

Sequence: 40/41 | Prev: STORY-GITOPS-SELF-MGMT-FLUX.md | Next: STORY-BOOT-AUTOMATION-ALIGN.md
Sprint: 7 | Lane: Bootstrap & Platform
Global Sequence: 40/41

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

1) **Phase separation respected** (Tasks: T0.3, T6): Phase 0 installs CRDs; Phase 1 performs a one‑time imperative install of Cilium via Helm CLI, installs Flux, and then all components are reconciled via GitOps. No non‑GitOps controllers remain unmanaged after handover.

2) **Component deployment and configuration** (Tasks: T1, T2, T3, T4): On both clusters, the following are Ready:
   - Control plane nodes (selector `node-role.kubernetes.io/control-plane`) are Ready (CNI operational).
   - Cilium DaemonSet and Operator (Ready/Available across all nodes).
   - CoreDNS Deployment replicas match `cluster-settings.yaml` (infra: 2; apps: 2) and are Available.
   - CoreDNS Service clusterIP matches `cluster-settings.yaml` (infra: 10.245.0.10; apps: 10.247.0.10).
   - Spegel DaemonSet Ready (if enabled in bootstrap).
   - External Secrets controller Deployment Available in `external-secrets` namespace.
   - External Secrets ClusterSecretStore `onepassword` Ready and validated via smoke test.
   - cert‑manager controller & webhook Deployments Available in `cert-manager` namespace.

3) **Flux operational** (Tasks: T5.1, T5.2, T5.3, T5.4): Flux is operational on both clusters:
   - flux‑operator controllers running and Ready.
   - flux‑instance reports Ready; `flux get sources git flux-system` and `flux get kustomizations -A` return Ready for initial objects.

4) **Handover criteria met** (Tasks: T5.5): Architecture §6 requirements satisfied:
   - GitRepository connected; initial Kustomizations reconcile successfully.
   - Subsequent changes are applied by Flux (validated via dummy change test).

5) **Artifacts and documentation** (Tasks: T8): All commands, outputs (key excerpts), and any deviations captured in Dev Notes.

6) **P0 test execution** (Tasks: T7): All P0 test scenarios from docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md pass on both clusters (infra, apps); execution artifacts captured in Dev Notes. QA gate moves from CONCERNS to PASS or waivers are documented.

7) **Cilium GitOps transition** (Tasks: T6): Cilium core is under GitOps control post‑bootstrap:
   - `kubernetes/infrastructure/kustomization.yaml` includes `networking/cilium/core/ks.yaml`.
   - Flux HelmRelease for Cilium exists and is Ready.
   - (Optional/Advanced) A reconcile after uninstalling the Helm‑CLI release results in Flux re‑creating the Cilium resources.

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

### T0 — Preflight Validation (AC: 1 partial, Prerequisites)
- [ ] T0.1 — Verify Phase 0 CRDs established on both clusters
  - [ ] `kubectl --context=infra get crds | grep -E "(cilium|cert-manager|external-secrets|postgresql.cnpg.io)" | wc -l`  # expect > 0
  - [ ] `kubectl --context=apps get crds | grep -E "(cilium|cert-manager|external-secrets|postgresql.cnpg.io)" | wc -l`
- [ ] T0.2 — Verify KUBECONFIG contexts accessible
  - [ ] `kubectl --context=infra cluster-info`
  - [ ] `kubectl --context=apps cluster-info`
- [ ] T0.3 — Validate helmfile 01-core produces ZERO CRDs (AC1 phase guard)
  - [ ] `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l`  # expect 0
  - [ ] `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e apps template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l`  # expect 0
- [ ] T0.4 — Validate cluster-settings.yaml syntax
  - [ ] `yq eval kubernetes/clusters/infra/cluster-settings.yaml > /dev/null`
  - [ ] `yq eval kubernetes/clusters/apps/cluster-settings.yaml > /dev/null`

### T1 — Bootstrap Prerequisites (AC: 2 partial)
- [ ] T1.1 — Apply bootstrap resources to infra cluster
  - [ ] `kubectl --context=infra apply -f bootstrap/prerequisites/resources.yaml`
- [ ] T1.2 — Apply bootstrap resources to apps cluster
  - [ ] `kubectl --context=apps apply -f bootstrap/prerequisites/resources.yaml`
- [ ] T1.3 — Verify onepassword-connect Secret exists
  - [ ] `kubectl --context=infra -n external-secrets get secret onepassword-connect-token`
  - [ ] `kubectl --context=apps -n external-secrets get secret onepassword-connect-token`
- [ ] T1.4 — Verify required namespaces created
  - [ ] `kubectl --context=infra get ns flux-system external-secrets cert-manager`
  - [ ] `kubectl --context=apps get ns flux-system external-secrets cert-manager`

### T2 — Deploy Core Components (AC: 2)
- [ ] T2.1 — Deploy Phase 2 on infra cluster
  - [ ] `task :bootstrap:phase:2 CLUSTER=infra`  # Executes: Cilium via Helm CLI → Flux install → Flux reconcile
- [ ] T2.2 — Deploy Phase 2 on apps cluster
  - [ ] `task :bootstrap:phase:2 CLUSTER=apps`
- [ ] T2.3 — Wait for initial deployments to stabilize (5 minutes)

### T3 — Validate Component Deployment (AC: 2)
- [ ] T3.1 — Validate infra cluster components
  - [ ] Control plane nodes: `kubectl --context=infra get nodes -l node-role.kubernetes.io/control-plane`
  - [ ] Cilium DaemonSet: `kubectl --context=infra -n kube-system rollout status ds/cilium --timeout=5m`
  - [ ] Cilium Operator: `kubectl --context=infra -n kube-system rollout status deploy/cilium-operator --timeout=5m`
  - [ ] CoreDNS rollout: `kubectl --context=infra -n kube-system rollout status deploy/coredns --timeout=5m`
  - [ ] CoreDNS replicas: `kubectl --context=infra -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}'`  # expect 2
  - [ ] CoreDNS clusterIP: `kubectl --context=infra -n kube-system get svc coredns -o jsonpath='{.spec.clusterIP}'`  # expect 10.245.0.10
  - [ ] Spegel (if enabled): `kubectl --context=infra -n kube-system rollout status ds/spegel --timeout=5m || echo "Spegel not deployed"`
  - [ ] cert-manager: `kubectl --context=infra -n cert-manager rollout status deploy/cert-manager --timeout=5m`
  - [ ] cert-manager webhook: `kubectl --context=infra -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m`
  - [ ] External Secrets: `kubectl --context=infra -n external-secrets rollout status deploy/external-secrets --timeout=5m`
- [ ] T3.2 — Validate apps cluster components (same checks with apps context)
  - [ ] Control plane nodes: `kubectl --context=apps get nodes -l node-role.kubernetes.io/control-plane`
  - [ ] Cilium DaemonSet: `kubectl --context=apps -n kube-system rollout status ds/cilium --timeout=5m`
  - [ ] Cilium Operator: `kubectl --context=apps -n kube-system rollout status deploy/cilium-operator --timeout=5m`
  - [ ] CoreDNS rollout: `kubectl --context=apps -n kube-system rollout status deploy/coredns --timeout=5m`
  - [ ] CoreDNS replicas: `kubectl --context=apps -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}'`  # expect 2
  - [ ] CoreDNS clusterIP: `kubectl --context=apps -n kube-system get svc coredns -o jsonpath='{.spec.clusterIP}'`  # expect 10.247.0.10
  - [ ] Spegel (if enabled): `kubectl --context=apps -n kube-system rollout status ds/spegel --timeout=5m || echo "Spegel not deployed"`
  - [ ] cert-manager: `kubectl --context=apps -n cert-manager rollout status deploy/cert-manager --timeout=5m`
  - [ ] cert-manager webhook: `kubectl --context=apps -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m`
  - [ ] External Secrets: `kubectl --context=apps -n external-secrets rollout status deploy/external-secrets --timeout=5m`
- [ ] T3.3 — Run bootstrap status check
  - [ ] `task bootstrap:status CLUSTER=infra`
  - [ ] `task bootstrap:status CLUSTER=apps`

### T4 — External Secrets Smoke Test (AC: 2 partial)
- [ ] T4.1 — Verify ClusterSecretStore Ready on infra
  - [ ] `kubectl --context=infra -n external-secrets get clustersecretstore onepassword -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'`  # expect True
- [ ] T4.2 — Verify ClusterSecretStore Ready on apps
  - [ ] `kubectl --context=apps -n external-secrets get clustersecretstore onepassword -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'`  # expect True
- [ ] T4.3 — Create test ExternalSecret on infra (smoke test)
  - [ ] Create test ExternalSecret pointing to valid 1Password path
  - [ ] Verify Secret gets created and populated
  - [ ] Delete test resources after validation
- [ ] T4.4 — Create test ExternalSecret on apps (smoke test)

### T5 — Flux Handover Validation (AC: 3, 4)
- [ ] T5.1 — Verify Flux operator Ready on both clusters
  - [ ] `kubectl --context=infra -n flux-system get pods -l app=flux-operator`
  - [ ] `kubectl --context=apps -n flux-system get pods -l app=flux-operator`
- [ ] T5.2 — Verify flux-instance Ready on both clusters
  - [ ] `kubectl --context=infra -n flux-system get fluxinstance flux-system`
  - [ ] `kubectl --context=apps -n flux-system get fluxinstance flux-system`
- [ ] T5.3 — Verify GitRepository source connected
  - [ ] `flux --context=infra get sources git flux-system -n flux-system`
  - [ ] `flux --context=apps get sources git flux-system -n flux-system`
- [ ] T5.4 — Verify initial Kustomizations reconciling
  - [ ] `flux --context=infra get kustomizations -A`
  - [ ] `flux --context=apps get kustomizations -A`
- [ ] T5.5 — Test Flux change detection (AC4 validation)
  - [ ] Make dummy change to `kubernetes/clusters/<cluster>/` (e.g., add comment)
  - [ ] Commit and push change
  - [ ] Verify Flux picks up and applies change within 1 minute
  - [ ] Revert change

### T6 — Cilium GitOps Transition Validation (AC: 7)
- [ ] T6.1 — Verify Cilium core included in infrastructure kustomization
  - [ ] `grep "networking/cilium/core/ks.yaml" kubernetes/infrastructure/kustomization.yaml`
- [ ] T6.2 — Verify Flux HelmRelease for Cilium exists and is Ready
  - [ ] `kubectl --context=infra get helmrelease -A | grep cilium`
  - [ ] `kubectl --context=apps get helmrelease -A | grep cilium`
  - [ ] `flux --context=infra get helmreleases -A | grep cilium`
  - [ ] `flux --context=apps get helmreleases -A | grep cilium`
- [ ] T6.3 — [ADVANCED/OPTIONAL] Simulate GitOps takeover (lab environment only)
  - [ ] CAUTION: This validates Flux can recreate Cilium but causes brief network disruption
  - [ ] Identify Helm CLI release: `helm --kube-context=infra list -A | grep cilium`
  - [ ] Uninstall Helm CLI release: `helm --kube-context=infra uninstall cilium -n kube-system`
  - [ ] Trigger Flux reconcile: `flux --context=infra reconcile kustomization cluster-infra-infrastructure --with-source`
  - [ ] Verify Flux recreates Cilium: `kubectl --context=infra -n kube-system rollout status ds/cilium --timeout=5m`
  - [ ] Repeat for apps cluster if desired

### T7 — Execute P0 Test Scenarios (AC: 6)
- [ ] T7.1 — Execute P0 Unit tests on infra cluster
  - [ ] BOOT.CORE-UNIT-001: Phase guard validation
  - [ ] BOOT.CORE-UNIT-002: CRD absence check
  - [ ] Document results: PASS/FAIL
- [ ] T7.2 — Execute P0 Unit tests on apps cluster
  - [ ] Same scenarios as T7.1, apps context
- [ ] T7.3 — Execute P0 Integration tests on infra cluster
  - [ ] BOOT.CORE-INT-003: Component dependency chain
  - [ ] Document results: PASS/FAIL
- [ ] T7.4 — Execute P0 Integration tests on apps cluster
- [ ] T7.5 — Execute P0 E2E tests on infra cluster
  - [ ] BOOT.CORE-E2E-001: Full bootstrap workflow
  - [ ] BOOT.CORE-E2E-002: Flux handover
  - [ ] BOOT.CORE-E2E-003: GitOps reconciliation
  - [ ] BOOT.CORE-E2E-004: External Secrets integration
  - [ ] BOOT.CORE-E2E-005: Multi-component health
  - [ ] Document results: PASS/FAIL
- [ ] T7.6 — Execute P0 E2E tests on apps cluster
- [ ] T7.7 — Capture all test artifacts and results
  - [ ] Link outputs in Dev Notes
  - [ ] Update QA Results section with PASS/CONCERNS/FAIL gate decision

### T8 — Record Artifacts and Dev Notes (AC: 5)
- [ ] T8.1 — Capture all command outputs in Dev Notes
  - [ ] Include key excerpts from T0-T7
  - [ ] Document execution timestamps
- [ ] T8.2 — Document any deviations from expected behavior
  - [ ] Configuration mismatches
  - [ ] Failed validations and resolutions
  - [ ] Workarounds applied
- [ ] T8.3 — Update Dev Agent Record sections
  - [ ] Agent Model Used
  - [ ] Debug Log References
  - [ ] Completion Notes List
  - [ ] File List
- [ ] T8.4 — Update QA Results section
  - [ ] Test execution summary
  - [ ] Gate decision: PASS/CONCERNS/FAIL
  - [ ] Risk mitigation status

### T9 — Negative Testing (Optional) (AC: —)
- [ ] T9.1 — Simulate missing `onepassword-connect` Secret (lab only)
  - [ ] Observe External Secrets failure
  - [ ] Restore Secret and confirm recovery
- [ ] T9.2 — Verify CRD guard detects accidental CRDs
  - [ ] Local dry-run of helmfile template
  - [ ] Confirm zero CRDs emitted

### Appendix: Underlying raw commands (reference only)
- `kubectl --context=<ctx> apply -f bootstrap/prerequisites/resources.yaml`
- `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <ctx> sync`

[Source: docs/architecture.md §6; bootstrap/helmfile.d/README.md]

## Validation Steps (CLI)

### Phase 0 Prerequisites (AC: 1)
- Verify Phase 0 CRDs present:
  - `kubectl --context=infra get crds | grep -E "(cilium|cert-manager|external-secrets|postgresql.cnpg.io)" | wc -l`  # Expect > 0
  - `kubectl --context=apps get crds | grep -E "(cilium|cert-manager|external-secrets|postgresql.cnpg.io)" | wc -l`
- Phase separation guard (AC: 1):
  - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l`  # Expect 0
  - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e apps template | yq ea 'select(.kind == "CustomResourceDefinition")' | wc -l`  # Expect 0

### Component Rollout Status (AC: 2)
- Cilium:
  - `kubectl --context=<ctx> -n kube-system rollout status ds/cilium --timeout=5m`
  - `kubectl --context=<ctx> -n kube-system rollout status deploy/cilium-operator --timeout=5m`
- CoreDNS (with cluster-specific validation):
  - `kubectl --context=<ctx> -n kube-system rollout status deploy/coredns --timeout=5m`
  - **NEW:** `kubectl --context=infra -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}'`  # Expect 2
  - **NEW:** `kubectl --context=apps -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}'`  # Expect 2
  - **NEW:** `kubectl --context=infra -n kube-system get svc coredns -o jsonpath='{.spec.clusterIP}'`  # Expect 10.245.0.10
  - **NEW:** `kubectl --context=apps -n kube-system get svc coredns -o jsonpath='{.spec.clusterIP}'`  # Expect 10.247.0.10
- Spegel (if enabled):
  - **NEW:** `kubectl --context=<ctx> -n kube-system rollout status ds/spegel --timeout=5m || echo "Spegel not deployed"`
- cert‑manager:
  - `kubectl --context=<ctx> -n cert-manager rollout status deploy/cert-manager --timeout=5m`
  - `kubectl --context=<ctx> -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m`
- External Secrets:
  - `kubectl --context=<ctx> -n external-secrets rollout status deploy/external-secrets --timeout=5m`
  - **NEW:** `kubectl --context=<ctx> -n external-secrets get clustersecretstore onepassword -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'`  # Expect True

### Flux Handover (AC: 3, 4)
- Flux operator and instance:
  - `kubectl --context=<ctx> -n flux-system get pods`
  - `kubectl --context=<ctx> -n flux-system get fluxinstance flux-system`
- GitRepository source:
  - `flux --context=<ctx> get sources git flux-system -n flux-system`
- Kustomizations:
  - `flux --context=<ctx> get kustomizations -A`

### Cilium GitOps Transition (AC: 7)
- **NEW:** Verify Cilium included in infrastructure kustomization:
  - `grep "networking/cilium/core/ks.yaml" kubernetes/infrastructure/kustomization.yaml`
- **NEW:** Verify Flux HelmRelease for Cilium:
  - `kubectl --context=<ctx> get helmrelease -A | grep cilium`
  - `flux --context=<ctx> get helmreleases -A | grep cilium`
- **NEW (OPTIONAL/ADVANCED):** GitOps takeover test:
  - `helm --kube-context=<ctx> list -A | grep cilium`  # Identify Helm CLI release
  - `helm --kube-context=<ctx> uninstall cilium -n kube-system`  # Remove imperative release
  - `flux --context=<ctx> reconcile kustomization cluster-<cluster>-infrastructure --with-source`  # Trigger Flux
  - `kubectl --context=<ctx> -n kube-system rollout status ds/cilium --timeout=5m`  # Verify recreation

### P0 Test Execution (AC: 6)
- Follow docs/qa/assessments/STORY-BOOT-CORE-test-design-20251021.md (IDs: BOOT.CORE-UNIT-001/002; INT-003; E2E-001..005) on both clusters:
  - Execute Unit tests (UNIT-001, UNIT-002) on infra and apps
  - Execute Integration tests (INT-003) on infra and apps
  - Execute E2E tests (E2E-001..005) on infra and apps
  - Document results: PASS/FAIL for each scenario
- Optional negative: BOOT.CORE-E2E-007/008 per design doc (lab only)

### Success Criteria
- All rollouts complete on both clusters
- Flux source and initial Kustomizations Ready
- CoreDNS clusterIP matches cluster-settings.yaml (10.245.0.10 infra, 10.247.0.10 apps)
- CoreDNS replicas = 2 on both clusters
- External Secrets ClusterSecretStore Ready
- Cilium HelmRelease exists and Ready (GitOps control established)

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

### v1.2 Refinement Summary (2025-10-22 by Winston/Architect)
**Critical enhancements for greenfield deployment:**
- **9-task structure** (was 6): Added T1 (Bootstrap Prerequisites), T4 (External Secrets Smoke Test), T6 (Cilium GitOps Transition)
- **AC7 coverage**: Added T6 to validate Cilium under GitOps control (previously had ZERO task coverage)
- **Cluster-specific validation**: Added CoreDNS clusterIP (10.245.0.10 infra, 10.247.0.10 apps), replica count verification
- **External Secrets end-to-end validation**: Smoke test to ensure 1Password connectivity works before dependent components
- **Explicit AC mapping**: All ACs now have task references (e.g., AC2 → T1, T2, T3, T4)
- **Enhanced validation steps**: Added 15+ new validation commands for cluster-specific configurations
- **Per-cluster test breakdown**: T7 now separates Unit/Integration/E2E tests for infra and apps clusters

**Key additions:**
- T0.3: Helmfile CRD guard validation
- T1: Bootstrap prerequisites (namespaces + 1Password secret)
- T3: CoreDNS clusterIP and replica validation
- T4: ClusterSecretStore Ready check + ExternalSecret smoke test
- T5.5: Flux change detection test (AC4 validation)
- T6: Cilium GitOps transition validation (AC7)
- T7: Granular test execution breakdown per cluster

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
| 2025-10-22 | 1.2     | Architect refinement: 9-task structure with explicit AC mapping, cluster-specific validation, AC7 coverage | Winston (Architect) |

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
