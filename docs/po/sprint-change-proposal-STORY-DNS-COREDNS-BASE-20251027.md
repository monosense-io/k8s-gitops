# Sprint Change Proposal — STORY-DNS-COREDNS-BASE (2025-10-27)

Author: Sarah (Product Owner)
Mode: YOLO (batched corrections)

## Change Trigger

- QA risk profile (2025-10-27) identified Critical and High risks:
  - Critical: OCIRepository URL placeholder prevents chart fetch.
  - High: ServiceMonitor/Prometheus CRDs timing; substitution wiring risks.
- QA test design (2025-10-27) defined 14 P0/P1 integration tests for manifests and wiring.

## Analysis Summary

- Story structure mostly sound post v3.0, but acceptance and tasks needed adjustments to incorporate OCI preflight and to avoid early ServiceMonitor failures.
- Repo wiring pattern is cluster-level Kustomizations; story now aligns and avoids non-existent paths.

## Proposed/Applied Edits

1) Scope
- Add explicit requirement for OCI chart preflight during local validation.

2) Acceptance Criteria
- AC2 renamed to “OCIRepository Manifest Created (Preflighted)” — requires non-placeholder URL and basic preflight success.
- AC6 expanded: CIDR membership checks for ClusterIP; OCI preflight included.

3) Tasks / Subtasks
- T2 ocirepository.yaml: Require setting approved OCI URL (`oci://<SET_APPROVED_REGISTRY>/coredns`).
- T2 helmrelease.yaml: `serviceMonitor.enabled: false` by default with comment to enable when CRDs exist.
- T4 validation: Add CIDR membership checks and OCI preflight (`helm show chart` or `flux reconcile source oci`).
- T6 cluster-settings: Document optional `COREDNS_SERVICEMONITOR_ENABLED` for later enablement.

4) Definition of Done
- Add CIDR membership, OCI preflight success; clarify ServiceMonitor config present but default disabled.
- Update commit message note to reflect SM gating.

5) QA Results linkage
- Story now includes risk_summary and test_design summaries with links to QA artifacts.

## Impacted Artifacts

- Updated: `docs/stories/STORY-DNS-COREDNS-BASE.md` (Scope, AC2, AC6, T2, T4, T6, DoD, commit message note, QA Results remain).
- QA: No change to risk/test-design documents beyond reference.

## Gate Recommendation

- Gate: CONCERNS until:
  - OCI URL is set to an approved registry and preflight passes, and
  - ServiceMonitor remains disabled until Prometheus CRDs are present or observability story lands.
- After both are satisfied, set Gate: PASS and move Status → Approved.

## Next Steps

- Confirm approved OCI registry URL for CoreDNS chart and update ocirepository.yaml accordingly.
- Decide when to enable ServiceMonitor (either in observability story or via cluster-settings toggle).
- Run the P0 integration checks from the test design.

---

This proposal is applied to the story; please review and confirm.
