# Sprint Change Proposal — STORY-SEC-CERT-MANAGER-ISSUERS (2025-10-28)

Mode: YOLO (batched updates)
Owner: Product Owner
Related Artifacts:
- Story: `docs/stories/STORY-SEC-CERT-MANAGER-ISSUERS.md`
- QA Risk Profile: `docs/qa/assessments/STORY-SEC-CERT-MANAGER-ISSUERS-risk-20251028.md`
- QA Test Design: `docs/qa/assessments/06.story-sec-cert-manager-issuers-test-design-20251028.md`

## Analysis Summary

- Context: Manifests-only story to create cert-manager issuers, ExternalSecret, wildcard Certificate, PrometheusRule, kustomization + Flux Kustomization. Deployment/E2E deferred to Story 45.
- Inputs processed: QA risk profile (must-fix: token scope, dependsOn alignment, cluster-settings), Test design (static/build validations mapped to ACs).
- Goal: Integrate QA guidance into the story so Dev can implement with clear guardrails and traceability; keep runtime checks out of scope.

## Proposed and Applied Edits

1. Header Links
   - Added links to QA risk profile and test design docs for quick reference.
2. Acceptance Criteria
   - AC2: Clarified ExternalSecret mapping: `remoteRef.property: credential` → secret key `api-token` and target secret details.
   - AC5: Clarified `dependsOn` name must match the actual External Secrets Kustomization (`external-secrets`).
3. Validation Steps
   - T4: Added `flux build | yq` check to verify `remoteRef.property` equals `credential`.
4. Dev Notes
   - Expanded security guidance: least-privilege, zone-scoped tokens, rotation; recommend distinct staging vs prod tokens.
   - Added explicit references to QA risk and test design documents.
5. Change Log
   - Added entry v3.2 documenting the above edits and rationale.

## Impact Assessment

- Scope: No functional expansion; improved specificity and validation clarity only.
- Risk Mitigation: Addresses high/medium risks (SEC-001, TECH-001, OPS-001) with explicit AC/validation language.
- Dependencies: None new; maintains manifests-only boundary.

## Recommended Path Forward

- Status: Keep as Draft → Approve after PO review of these changes.
- Handoff: Dev to implement; follow Test Design doc for local validations.
- QA: Use risk_summary block in risk profile to seed gate file after implementation.

## Checklist Completion

- [x] Change context analyzed
- [x] Story updated per QA guidance
- [x] No architecture/PRD changes required
- [x] Ready for approval and dev handoff

