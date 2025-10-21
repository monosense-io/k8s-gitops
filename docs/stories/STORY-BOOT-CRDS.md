# STORY-BOOT-CRDS — Phase 0 CRD Bootstrap (infra + apps)

Status: Draft
Owner: Scrum Master → Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §11.2, bootstrap/helmfile.d/00-crds.yaml

## Story
Install and validate all required CustomResourceDefinitions (CRDs) on both clusters (infra, apps) using the Phase 0 Helmfile pipeline. Ensure cert-manager, external-secrets, victoria‑metrics‑operator CRDs (bundle, incl. PrometheusRule compatibility), prometheus‑operator CRDs, and Gateway API CRDs are established before any workloads that depend on them. This guarantees PrometheusRule/ServiceMonitor/VM* resources and External Secrets can reconcile cleanly during Phase 1 and subsequent Flux syncs.

## Why / Outcome
- Prevents race conditions during initial reconciliation.
- Ensures observability leaf on apps (vmagent, ServiceMonitor/PodMonitor usage) and infra Global VM stack can safely apply manifests.
- Aligns bootstrap flow with documented architecture and 1Password‑only secrets approach.

## Scope
Clusters: infra, apps
CRDs (exact versions per bootstrap/helmfile.d/00-crds.yaml):
- cert-manager (v1.19.0) — Certificate, Issuer, ClusterIssuer, etc.
- external-secrets (0.20.3) — ExternalSecret, (Cluster)SecretStore, etc.
- victoria‑metrics‑operator CRD bundle (0.5.1) — VMAgent, VMRule, VMServiceScrape, VMPodScrape, VMProbe, VMNodeScrape, VMStaticScrape, VMAuth, VMUser, VMAlertmanagerConfig, VLAgent, VLSingle, VLCluster, etc.
- prometheus‑operator CRDs (24.0.1) — PrometheusRule, ServiceMonitor, PodMonitor, Probe
- Gateway API CRDs (v1.4.0) — GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant

Namespaces to exist (both clusters):
- external-secrets, cert-manager, observability, cnpg-system

## Non-Goals
- Installing operators/controllers (Phase 1). No changes to Flux Kustomizations or workloads.
- Any data-plane or app deployment.

## Acceptance Criteria
1) CRDs are applied and established on both clusters (infra, apps):
   - kubectl get crd | grep -E 'external-secrets|cert-manager|victoria|monitoring.coreos.com|gateway.networking.k8s.io'
   - Condition Established=True for all CRDs in the explicit wait set (see QA Test Design / GVR list).
2) Namespaces exist and are Active: external-secrets, cert-manager, observability, cnpg-system.
3) Phase isolation: only CRDs were applied in this phase (yq filter enforced; audit shows zero non‑CRDs).
4) PrometheusRule, ServiceMonitor, PodMonitor, VM* CRDs present; kustomize build + kubeconform on infra/apps shows no missing type errors.
5) Commands/logs and CRD group counts are captured in Dev Notes.

## Dependencies / Inputs
- KUBECONFIG contexts for infra and apps set (docs/architecture.md §7).
- bootstrap/helmfile.d/00-crds.yaml present and version‑pinned.
- Internet egress to chart registries permitted.

## Tasks / Subtasks (Taskfile is canonical)
- T0 — Preflight
  - `task bootstrap:phase:0 CLUSTER=infra` (applies prerequisites) — repeat for apps
  - `task bootstrap:phase:1 CLUSTER=infra` (installs CRDs) — repeat for apps
- T1 — Establishment checks
  - `task bootstrap:validate:crds CONTEXT=infra` — repeat for apps
  - `task bootstrap:list-crds CONTEXT=infra` — repeat for apps
- T2 — Dry‑run verification (both)
  - `kustomize build kubernetes/clusters/infra | kubeconform -strict -ignore-missing-schemas`
  - Repeat for apps

### Appendix: Underlying raw commands (reference only)
- Infra CRDs apply
  - `helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | yq ea 'select(.kind == "CustomResourceDefinition")' | kubectl --context=infra apply --server-side --force-conflicts -f -`
  - `kubectl --context=infra apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml`
- Apps CRDs apply
  - `helmfile -f bootstrap/helmfile.d/00-crds.yaml -e apps template | yq ea 'select(.kind == "CustomResourceDefinition")' | kubectl --context=apps apply --server-side --force-conflicts -f -`
  - `kubectl --context=apps apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml`
- Validation (manual alternative)
  - `kubectl --context=<ctx> wait --for=condition=Established crd/<name> --timeout=120s`

## Validation Steps (CLI)
- kubectl --context=infra get crd | grep victoriametrics
- kubectl --context=apps get crd | grep monitoring.coreos.com
- kubectl --context=infra get ns {external-secrets,cert-manager,observability,cnpg-system}
- kubectl --context=apps get ns {external-secrets,cert-manager,observability,cnpg-system}

## Rollback
- Not recommended to delete CRDs once applied (would orphan resources). If necessary in lab: kubectl delete crd <name> ...; ensure no dependent resources exist.

## Risks / Mitigations
- Network egress blocked → pre‑flight check, retry with mirror registries.
- Version skew between Phase 0 and phase 1 charts → align versions in 00‑crds.yaml and core helmfile.
- Long CRD establishment → increase timeouts; re‑apply.

## Definition of Done
- All Acceptance Criteria met on both clusters.
- Dev Notes include command logs and CRD counts.
- Architecture tracked versions match applied CRDs.

## Architect Handoff
- Architecture (docs/architecture.md)
  - Document Phase 0 as CRDs‑only with explicit kinds audit; point to `bootstrap/helmfile.d/00-crds.yaml` and Taskfile phases.
  - Specify explicit CRD wait set as normative (GVR list in this story / QA doc) and reference in Architecture.
- PRD (docs/prd.md)
  - Add NFRs: phase isolation (no controllers in Phase 0), idempotent CRD re‑apply, dry‑run validation with kubeconform before Phase 1.
  - Add acceptance: CI dry‑run step present (see Automation Align story) and passes.

## Dev Notes
(leave runtime logs, counts, and confirmations here)

*** End of Story ***

---

## PO Validation (docs/stories/STORY-BOOT-CRDS.md)

Status: PASS — Final, Ready for Dev
Date: 2025-10-21

Validation Summary
- Scope matches architecture (Section 11.2) and bootstrap plan (Phase 0). Versions pinned to 00-crds.yaml. Namespaces aligned (observability; cnpg-system). 1Password-only approach unaffected by CRDs.
- QA Test Design and Risk Assessment integrated; explicit GVR wait set defined; acceptance criteria reflect phase isolation and audit logging.

Minor Clarifications (addressed in this story)
- Pinned CRD versions to exact values from bootstrap/helmfile.d/00-crds.yaml to avoid drift.
- Added preferred Taskfile entrypoints.

Entry/Exit Criteria
- Entry: kube contexts available; network egress open; namespaces present or created.
- Exit: CRDs Established on both clusters; dry-run kustomize build has no missing types; Dev Notes include command logs and CRD counts.

Dependencies
- bootstrap/helmfile.d/00-crds.yaml present; yq + helmfile available.

Approval
- Approved for implementation in Sprint 0 as the first story. Proceed to Dev.

---

## PO Correct-Course Review

Critical
- Enforce explicit CRD wait set: list exact CRD names to `kubectl wait --for=condition=Established` (e.g., `prometheusrules.monitoring.coreos.com`, `servicemonitors.monitoring.coreos.com`, `podmonitors.monitoring.coreos.com`, `gateways.gateway.networking.k8s.io`, `gatewayclasses.gateway.networking.k8s.io`, `httproutes.gateway.networking.k8s.io`, key `operator.victoriametrics.com/*` CRDs, `externalsecrets.external-secrets.io`, `clustersecretstores.external-secrets.io`, `issuers.cert-manager.io`, `clusterissuers.cert-manager.io`, `certificates.cert-manager.io`). Avoid relying only on greps.
- Assert idempotency and phase isolation: this story must not apply any non‑CRD manifests; ensure Flux (if present) is paused for any Kustomizations that would otherwise fail on missing CRDs, or run this before Phase 1. Capture this in Preconditions.
- Namespaces pre-creation as a task, not a note: move “ensure namespaces exist” to an explicit task with concrete command and acceptance check (Status=Active) for external-secrets, cert‑manager, observability, cnpg-system.

Should‑Fix
- Prefer Taskfile shims for repeatability: document that `task bootstrap:infra-crds` and `task bootstrap:apps-crds` are the canonical entrypoints (wrap the helmfile+yq pipeline). Keep raw commands as fallback.
- Gateway API CRDs check-before-apply: add a short-circuit (skip apply if CRDs already present) to reduce churn on re-runs.
- Version lock note: state that any version bump in `bootstrap/helmfile.d/00-crds.yaml` requires updating this story’s version bullets and running in both clusters.
- Validation depth: add `kubectl api-resources | grep -E 'monitoring.coreos.com|operator.victoriametrics.com|gateway.networking.k8s.io'` to confirm API discovery, and run `kubeconform` against `kubernetes/clusters/{infra,apps}` as part of the acceptance.

Nice‑to‑Have
- Record metrics: capture counts per CRD group before/after (for audit) and attach to Dev Notes.
- Add CI job stub: define a lightweight CI check to assert CRDs presence (non-blocking until infra is ready).
- Include rollback note per CRD group: links to vendor docs warning against deleting CRDs with extant resources.

---

## QA Risk Assessment (concise)

- R1 — Version skew (Phase 0 vs Phase 1): Prob=Medium, Impact=High. Mitigation: Pin versions (done), align core helmfile, run kubeconform dry‑run.
- R2 — Partial CRD application: Prob=Medium, Impact=High. Mitigation: Explicit Established waits for enumerated GVRs, re‑apply idempotently.
- R3 — API discovery lag: Prob=Medium, Impact=Medium. Mitigation: brief retry before validation; `api-resources` checks.
- R4 — Missing namespaces: Prob=Low, Impact=Medium. Mitigation: T1 creates + waits Active.
- R5 — Gateway API mismatch: Prob=Low, Impact=Medium. Mitigation: pin v1.4.0; short‑circuit if present.
- R6 — Egress/outage during template: Prob=Medium, Impact=Medium. Mitigation: retry/backoff; use mirrors if needed.
- R7 — Non‑CRDs applied accidentally: Prob=Low, Impact=High. Mitigation: mandatory yq filter; kinds audit.

---

## QA Test Design — STORY-BOOT-CRDS

Scope
- Validate Phase 0 CRD bootstrap on both clusters (infra, apps) yields only CRDs, establishes them reliably, and enables downstream manifests to validate (kubeconform).

Environments
- kube contexts: `infra`, `apps` (pointing to the respective clusters).

Test Data (versions pinned)
- cert-manager v1.19.0, external-secrets 0.20.3, victoria-metrics-operator CRDs 0.5.1, prometheus-operator CRDs 24.0.1, Gateway API CRDs v1.4.0.

Preconditions
- Tools: kubectl, helmfile, yq, kustomize, kubeconform available.
- Network egress to chart registries.
- Namespaces exist or will be created: external-secrets, cert-manager, observability, cnpg-system.

Explicit CRD Wait Set (GVRs)
- monitoring.coreos.com: prometheusrules, servicemonitors, podmonitors, probes
- operator.victoriametrics.com: vmagents, vmrules, vmservicescrapes, vmpodscrapes, vmprobes, vmnodescrapes, vmstaticscrapes, vmauths, vmusers, vmalertmanagerconfigs, vlsingles, vlclusters, vlagents (exact names per chart)
- external-secrets.io: externalsecrets, secretstores, clustersecretstores
- cert-manager.io: issuers, clusterissuers, certificates, certificaterequests, challenges, orders
- gateway.networking.k8s.io: gatewayclasses, gateways, httproutes, grpcroutes, referencegrants

Traceability (Acceptance → Tests)
- A1 (CRDs applied/established) → TCRD-003/004/005/006
- A2 (Namespaces exist) → TCRD-001
- A3 (CRDs only in Phase 0) → TCRD-002
- A4 (Downstream types present; dry-run OK) → TCRD-007/008
- A5 (Command logs) → TCRD-012

Test Cases
- TCRD-001 — Namespace pre-creation
  - Steps: kubectl --context=<ctx> get ns; if missing, kubectl create ns; wait for Active.
  - Expected: external-secrets, cert-manager, observability, cnpg-system are Active.

- TCRD-002 — Helmfile template emits only CRDs
  - Steps: helmfile -f bootstrap/helmfile.d/00-crds.yaml -e <ctx> template | yq ea 'select(.kind == "CustomResourceDefinition")' > /tmp/crds.yaml; diff against unfiltered output kinds.
  - Expected: No kinds other than CustomResourceDefinition; non-CRD kinds count = 0.

- TCRD-003 — Apply CRDs (infra)
  - Steps: Apply filtered CRDs; apply Gateway API CRDs v1.4.0 if not present.
  - Expected: kubectl apply success; no conflicts; server-side apply accepted.

- TCRD-004 — Wait Established (infra, explicit list)
  - Steps: For each GVR in wait set, kubectl --context=infra wait --for=condition=Established crd/<gvr> --timeout=120s.
  - Expected: All return success; failures logged.

- TCRD-005 — Apply CRDs (apps)
  - Steps: Same as TCRD-003 for apps cluster.
  - Expected: Success.

- TCRD-006 — Wait Established (apps, explicit list)
  - Steps: Same as TCRD-004 for apps cluster.
  - Expected: All return success; failures logged.

- TCRD-007 — API discovery checks
  - Steps: kubectl --context=<ctx> api-resources | grep -E 'monitoring.coreos.com|operator.victoriametrics.com|gateway.networking.k8s.io'
  - Expected: Groups and resources are listed for both clusters.

- TCRD-008 — Dry-run compile and schema check
  - Steps: kustomize build kubernetes/clusters/<ctx> | kubeconform -strict -ignore-missing-schemas
  - Expected: No "unknown type" or schema errors due to missing CRDs.

- TCRD-009 — Idempotency re-run
  - Steps: Re-run TCRD-003/005 (apply) and waits.
  - Expected: No changes; apply is idempotent; waits succeed quickly.

- TCRD-010 — Partial failure recovery (simulated)
  - Steps: Temporarily delete one non-critical CRD (in a lab) and re-apply Phase 0; DO NOT perform in shared env.
  - Expected: CRD restored; Established condition returns.

- TCRD-011 — Gateway API present short-circuit
  - Steps: If crd/gatewayclasses.gateway.networking.k8s.io exists, skip re-applying standard-install.yaml.
  - Expected: No re-apply churn; test passes; documented.

- TCRD-012 — Artifacts capture
  - Steps: Record `kubectl get crd -A | wc -l`, grouped counts per API group; store in Dev Notes.
  - Expected: Counts recorded and attached.

Negative Tests
- NGT-001 — Non-CRD detection
  - Steps: Intentionally inspect unfiltered helmfile output and ensure the pipeline’s yq filter blocks non‑CRDs.
  - Expected: Guard works; only CRDs proceed.

- NGT-002 — Missing namespaces
  - Steps: Run apply without namespaces then re-run after creating them.
  - Expected: First run warns/fails on namespace checks; second run succeeds.

- NGT-003 — Version skew
  - Steps: Build core helmfile with mismatched CRD versions in a dry-run env.
  - Expected: Validation fails; mitigation path: align versions and re-run Phase 0.

Go/No‑Go
- GO: All waits succeed and dry-run checks pass on infra and apps.
- NO-GO: Any CRD wait fails or dry-run shows missing types; investigate and fix before Phase 1.
