# Release Notes — STORY-BOOT-TALOS v1.3 (2025-10-21)

Summary
- Hardened Talos safe‑detector to prevent double‑bootstrap (multi‑signal checks).
- Enforced 1Password Connect Secret preflight in Phase 2 with actionable remediation.
- Locked CRD/controller versions and documented alignment across bootstrap helmfiles.
- Added CP‑only cluster resource guardrails and troubleshooting guidance to runbook.

Validation Status
- Live cluster validation: PENDING for both infra and apps.
- Current evidence: DRY‑RUN ONLY (see links below). Do not tag final release until live evidence is attached and QA gate flips to PASS.

Operator Impact
- Bootstrap remains idempotent; dry‑run path available via `DRY_RUN=true`.
- Failure before core applies if `onepassword-connect-token` secret is missing (clear instructions provided).
- Version alignment reduces drift and validation errors during CRD establish.

Validation
- Dry‑run evidence: 
  - docs/qa/evidence/BOOT-TALOS-dry-run-infra-20251021.txt
  - docs/qa/evidence/BOOT-TALOS-dry-run-apps-20251021.txt
- QA Gate: CONCERNS — docs/qa/gates/EPIC-greenfield-multi-cluster-gitops.STORY-BOOT-TALOS-boot-talos.yml

How To Produce Live Evidence (both clusters)
1) End‑to‑end create or stepwise:
   - `task cluster:create-<cluster>`
   - or `task bootstrap:talos CLUSTER=<cluster>` → `task :bootstrap:phase:{0,1,2,3} CLUSTER=<cluster>`
2) Verify API reachability (Phase −1 scope):
   - `kubectl --context=<cluster> cluster-info` responds
   - (Node Ready will be validated by STORY‑BOOT‑CORE after CNI install)
3) Re‑run to assert idempotency (short‑circuit messages, no errors)
4) Save key excerpts to `docs/qa/evidence/BOOT-TALOS-live-<cluster>-YYYYMMDD.txt`

References
- Story: docs/stories/STORY-BOOT-TALOS.md
- Risk Profile: docs/qa/assessments/STORY-BOOT-TALOS-risk-20251021.md
- Test Design: docs/qa/assessments/STORY-BOOT-TALOS-test-design-20251021.md
