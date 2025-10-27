# 44 — STORY-BOOT-CORE — Create Core Bootstrap Manifests & Configuration

Sequence: 44/50 | Prev: STORY-BOOT-CRDS.md | Next: STORY-VALIDATE-NETWORKING.md
Sprint: 7 | Lane: Bootstrap & Platform
Global Sequence: 44/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §6, §7, §4; bootstrap/helmfile.d/01-core.yaml.gotmpl; bootstrap/clusters/*/cilium-values.yaml

## Story
As a Platform Engineer, I want to create core bootstrap manifests and helmfile configuration for both clusters (infra, apps), including Cilium CNI, Flux, CoreDNS, cert-manager, and External Secrets, so that when Story 45 (VALIDATE-NETWORKING) deploys the bootstrap, all core components are ready for GitOps reconciliation.

This story creates the **helmfile configuration and bootstrap values** and validates they can template correctly. Actual deployment and validation happen in **Story 45 (VALIDATE-NETWORKING)**.

[Source: docs/architecture.md §6 (Bootstrap Architecture), §7 (Cluster Settings)]

## Why / Outcome
- Create helmfile configuration for core components (Cilium, Flux, CoreDNS, cert-manager, External Secrets)
- Prepare cluster-specific bootstrap values for infra and apps clusters
- Validate helmfile can template all core components correctly without cluster access
- Enable Story 45 to deploy and validate core bootstrap components
- Ensure one source of truth for chart values (values aligned with Flux HelmReleases)

[Source: docs/architecture.md §6 — Bootstrap Architecture]

## Scope

**This Story (Manifest Creation):**
- Create/update `bootstrap/helmfile.d/01-core.yaml.gotmpl` with core component configurations
- Create/update cluster-specific bootstrap values:
  - `bootstrap/clusters/infra/cilium-values.yaml`
  - `bootstrap/clusters/apps/cilium-values.yaml`
  - Other component-specific values as needed
- Configure core components for both clusters (infra, apps):
  - **Cilium** (agent + operator) — CNI with cluster-specific settings
  - **Flux** (operator + instance) — GitOps engine
  - **CoreDNS** — DNS resolution with custom clusterIP
  - **cert-manager** — TLS certificate management
  - **External Secrets** — 1Password integration
  - **Spegel** (optional) — Registry mirror
- Validate helmfile can template all components correctly (local validation only)
- Ensure CRDs are NOT included in core helmfile (CRDs handled in Story 43)
- Create prerequisite namespace manifests if not already in Story 43

**Deferred to Story 45 (VALIDATE-NETWORKING):**
- Deploying core components to clusters
- Cilium CNI operational validation
- Flux reconciliation testing
- Component health checks
- GitOps handover validation

**Non-Goals:**
- Day-2 features (Cilium BGP, Gateway API, ClusterMesh, storage, observability)
- SSL certificates and ClusterIssuers (covered in other stories)
- Application workloads

[Source: docs/architecture.md §6 (Bootstrap Phases), §7 (Cluster Settings)]

## Acceptance Criteria

**Manifest Creation (This Story):**

1) **Helmfile Configuration Exists**:
   - `bootstrap/helmfile.d/01-core.yaml.gotmpl` exists and is valid YAML
   - Contains all required core component releases: Cilium, Flux, CoreDNS, cert-manager, External Secrets
   - Includes both infra and apps environment configurations
   - CRD installation disabled for all charts (`installCRDs: false`)

2) **Helmfile Templates Successfully**:
   - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template` succeeds
   - `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e apps template` succeeds
   - Templated output contains NO CustomResourceDefinition kinds (validated with yq filter)

3) **Cluster-Specific Bootstrap Values Created**:
   - `bootstrap/clusters/infra/cilium-values.yaml` exists with cluster-specific settings
   - `bootstrap/clusters/apps/cilium-values.yaml` exists with cluster-specific settings
   - Values reference correct cluster settings (POD_CIDR, SERVICE_CIDR, clusterID, etc.)
   - Other component values files created as needed

4) **Component Configuration Validation**:
   - Cilium values include cluster-specific POD_CIDR and SERVICE_CIDR from architecture.md
   - CoreDNS values specify custom clusterIP (infra: 10.245.0.10, apps: 10.247.0.10)
   - Flux configuration includes correct git repository URL
   - External Secrets configuration includes 1Password ClusterSecretStore definition
   - cert-manager configured without CRD installation

5) **Version Consistency**:
   - All component chart versions match architecture.md specifications
   - Versions are identical between infra and apps environments (where applicable)
   - Chart sources (repositories) documented and accessible

6) **Template Output Quality**:
   - No CRDs in templated output (confirmed with `yq` filter)
   - All Kubernetes resources have valid apiVersion, kind, metadata, spec
   - Namespace references correct (flux-system, cert-manager, external-secrets, kube-system)

**Deferred to Story 45 (Deployment & Validation):**
- Components deployed to clusters
- Control plane nodes Ready (CNI operational)
- Cilium, CoreDNS, cert-manager, External Secrets controllers running
- Flux operational and reconciling
- GitOps handover validation
- P0 test execution
- Runtime health checks

[Source: docs/architecture.md §6 (Bootstrap Architecture), §7 (Cluster Settings)]

## Dependencies / Inputs

**Prerequisites (v3.0):**
- Story 42 (STORY-BOOT-TALOS) complete (documentation only, clusters NOT created yet)
- Story 43 (STORY-BOOT-CRDS) complete (CRD manifests created)
- Tools installed: helmfile, yq, kubectl
- Access to `docs/architecture.md` for cluster settings and component versions
- Access to existing bootstrap configuration (samples from old cluster)

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ KUBECONFIG contexts (not needed for templating)
- ❌ Running clusters (Story 45 handles deployment)

[Source: docs/architecture.md §6 (Bootstrap Architecture), §7 (Cluster Settings)]

## Tasks / Subtasks

**T0 — Review Existing Configuration**
- [ ] Review existing `bootstrap/helmfile.d/01-core.yaml.gotmpl` (sample from old cluster)
- [ ] Review existing Cilium values in `bootstrap/clusters/*/cilium-values.yaml`
- [ ] Identify which parts can be reused vs. need updates
- [ ] Document version changes needed (compare against architecture.md)

**T1 — Create/Update Helmfile Configuration** (AC: 1, 2)
- [ ] Update `bootstrap/helmfile.d/01-core.yaml.gotmpl` with core component releases
- [ ] Configure Cilium release (chart version, namespace: kube-system, `installCRDs: false`)
- [ ] Configure Flux operator + instance releases (chart versions, namespace: flux-system)
- [ ] Configure CoreDNS release (chart version, namespace: kube-system, custom clusterIP)
- [ ] Configure cert-manager release (chart version, namespace: cert-manager, `installCRDs: false`)
- [ ] Configure External Secrets release (chart version, namespace: external-secrets, `installCRDs: false`)
- [ ] (Optional) Configure Spegel release if enabled
- [ ] Ensure both infra and apps environments configured with appropriate values

**T2 — Create Cluster-Specific Bootstrap Values** (AC: 3, 4)
- [ ] Create/update `bootstrap/clusters/infra/cilium-values.yaml`:
  - [ ] Set POD_CIDR from architecture.md (infra cluster)
  - [ ] Set SERVICE_CIDR from architecture.md (infra cluster)
  - [ ] Set clusterID (unique for each cluster)
  - [ ] Configure CNI settings (tunnel mode, routing mode)
  - [ ] Disable CRD installation (`installCRDs: false`)
- [ ] Create/update `bootstrap/clusters/apps/cilium-values.yaml`:
  - [ ] Set POD_CIDR from architecture.md (apps cluster)
  - [ ] Set SERVICE_CIDR from architecture.md (apps cluster)
  - [ ] Set clusterID (different from infra)
  - [ ] Configure CNI settings (matching infra)
  - [ ] Disable CRD installation
- [ ] Create CoreDNS values (if needed):
  - [ ] Infra clusterIP: 10.245.0.10
  - [ ] Apps clusterIP: 10.247.0.10
- [ ] Create Flux values (if needed):
  - [ ] Git repository URL
  - [ ] Git branch (main)
  - [ ] Reconciliation interval
- [ ] Create External Secrets values:
  - [ ] 1Password ClusterSecretStore configuration
  - [ ] Connection settings for 1Password Connect

**T3 — Validate Helmfile Templates** (AC: 2, 6)
- [ ] Run `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template > /tmp/core-infra.yaml` (NO cluster needed)
- [ ] Run `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e apps template > /tmp/core-apps.yaml` (NO cluster needed)
- [ ] Verify both commands exit with status 0
- [ ] Count CRDs in output (should be 0):
  ```bash
  yq ea 'select(.kind == "CustomResourceDefinition")' /tmp/core-infra.yaml | wc -l  # expect 0
  yq ea 'select(.kind == "CustomResourceDefinition")' /tmp/core-apps.yaml | wc -l   # expect 0
  ```
- [ ] Verify all resource kinds are valid Kubernetes resources
- [ ] Verify namespace references are correct (flux-system, cert-manager, external-secrets, kube-system)

**T4 — Version Consistency Check** (AC: 5)
- [ ] Extract chart versions from helmfile.d/01-core.yaml.gotmpl
- [ ] Compare against versions in docs/architecture.md:
  - [ ] Cilium version
  - [ ] Flux version
  - [ ] CoreDNS version
  - [ ] cert-manager version
  - [ ] External Secrets version
  - [ ] Spegel version (if applicable)
- [ ] Verify infra and apps environments use identical chart versions
- [ ] Document any intentional version differences

**T5 — Configuration Validation** (AC: 4)
- [ ] Validate Cilium POD_CIDR matches architecture.md for each cluster
- [ ] Validate Cilium SERVICE_CIDR matches architecture.md for each cluster
- [ ] Validate CoreDNS clusterIP settings (infra: 10.245.0.10, apps: 10.247.0.10)
- [ ] Validate Flux git repository URL is correct
- [ ] Validate External Secrets 1Password configuration
- [ ] Validate all components have `installCRDs: false` set

**T6 — Create Prerequisite Manifests** (if not in Story 43)
- [ ] Create/verify `bootstrap/prerequisites/resources.yaml`:
  - [ ] Namespace: flux-system
  - [ ] Namespace: external-secrets
  - [ ] Namespace: cert-manager
  - [ ] (Optional) 1Password Connect bootstrap secret placeholder
- [ ] Validate with `kubectl --dry-run=client -f bootstrap/prerequisites/resources.yaml`

**T7 — Documentation**
- [ ] Update Dev Notes with template validation output
- [ ] Document chart versions for each component
- [ ] Document cluster-specific settings (POD_CIDR, SERVICE_CIDR, clusterIP)
- [ ] Note any deviations from old cluster configuration

## Validation Steps (Local - NO Cluster Access)

**Helmfile Template Validation:**
```bash
# Validate infra environment templates correctly
helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra template > /tmp/core-infra.yaml
echo "Infra template status: $?"  # Should be 0

# Validate apps environment templates correctly
helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e apps template > /tmp/core-apps.yaml
echo "Apps template status: $?"  # Should be 0

# Verify NO CRDs in output (AC: 2)
yq ea 'select(.kind == "CustomResourceDefinition")' /tmp/core-infra.yaml | wc -l  # Should be 0
yq ea 'select(.kind == "CustomResourceDefinition")' /tmp/core-apps.yaml | wc -l   # Should be 0

# List all resource kinds (should be valid K8s resources)
yq ea '.kind' /tmp/core-infra.yaml | sort -u

# Verify namespace references
yq ea 'select(.metadata.namespace != null) | .metadata.namespace' /tmp/core-infra.yaml | sort -u
# Expected: cert-manager, external-secrets, flux-system, kube-system
```

**Values File Validation:**
```bash
# Validate Cilium values syntax
yq eval bootstrap/clusters/infra/cilium-values.yaml > /dev/null
yq eval bootstrap/clusters/apps/cilium-values.yaml > /dev/null

# Extract and verify POD_CIDR settings
yq '.ipam.operator.clusterPoolIPv4PodCIDRList[0]' bootstrap/clusters/infra/cilium-values.yaml
# Expected: value from architecture.md (infra POD_CIDR)

yq '.ipam.operator.clusterPoolIPv4PodCIDRList[0]' bootstrap/clusters/apps/cilium-values.yaml
# Expected: value from architecture.md (apps POD_CIDR)
```

**Prerequisite Manifest Validation:**
```bash
# Validate prerequisite resources (NO cluster access)
kubectl --dry-run=client -f bootstrap/prerequisites/resources.yaml
```

**Runtime Validation (MOVED TO STORY 45)**:
```bash
# These commands execute in Story 45, NOT this story:
# - Component rollout status checks
# - Flux handover validation
# - GitOps reconciliation testing
# - P0 test execution
```

**Success Criteria (v3.0 - Manifest Creation):**
- Helmfile templates successfully for both environments
- No CRDs in templated output
- All values files have valid YAML syntax
- Cluster-specific settings correctly configured
- Manifests committed to git

## Rollback

**v3.0 Note**: N/A - This story only creates manifests (no deployment).

Deployment rollback procedures are in Story 45 (VALIDATE-NETWORKING).

## Risks / Mitigations

**Manifest Creation Risks (This Story)**:
- **Helmfile Template Failure**: Mitigation: Validate YAML syntax before templating; use pinned chart versions
- **Version Mismatch**: Mitigation: Cross-reference all versions with architecture.md
- **CRDs Accidentally Included**: Mitigation: Use `yq` filter to verify ONLY non-CRD resources; set `installCRDs: false`
- **Invalid Cluster Settings**: Mitigation: Validate POD_CIDR, SERVICE_CIDR against architecture.md
- **Git Commit Issues**: Mitigation: Explicit commit task; verify files in remote

**Deployment Risks (MOVED TO STORY 45)**:
- Missing bootstrap Secret → Story 45
- Network constraints (egress) → Story 45
- Component startup failures → Story 45
- Flux handover issues → Story 45

## Definition of Done

**Manifest Creation Complete:**
- [ ] `bootstrap/helmfile.d/01-core.yaml.gotmpl` created/updated with all core components
- [ ] Helmfile templates successfully for both infra and apps environments
- [ ] Cluster-specific bootstrap values created:
  - [ ] `bootstrap/clusters/infra/cilium-values.yaml`
  - [ ] `bootstrap/clusters/apps/cilium-values.yaml`
  - [ ] Other component values as needed
- [ ] All values files validated with `yq`
- [ ] Helmfile template output contains ZERO CRDs
- [ ] All chart versions match architecture.md specifications
- [ ] Cluster-specific settings validated (POD_CIDR, SERVICE_CIDR, clusterIP)
- [ ] Prerequisite manifests created (if not in Story 43)
- [ ] Manifests committed to git
- [ ] Story 45 (VALIDATE-NETWORKING) can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ Components deployed to clusters
- ❌ Cilium CNI operational
- ❌ Flux reconciling
- ❌ Runtime validation
- ❌ P0 test execution
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
| 2025-10-26 | 2.0     | **v3.0 Refinement**: Separated manifest creation from deployment. Deployment moved to Story 45. Updated header, story, scope, AC, dependencies, tasks, validation, rollback, risks, DoD for manifests-first approach. | Winston |

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
