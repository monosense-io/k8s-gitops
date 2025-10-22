# Sprint Change Proposal — STORY-DB-CNPG-OPERATOR (QA Integration) — 2025-10-21

Author: PO (Sarah)
Status: Draft → For Review
Scope: Incorporate QA Risk Profile and Test Design into story DoD and Testing; tighten evidence handling

## Summary
- QA added Risk Profile and Test Design to the story (AC1–AC6 coverage). To operationalize this, the story now:
  - Requires a QA Gate decision file under `docs/qa/gates/` (PASS or PASS WITH CONCERNS)
  - Requires storing test evidence under `docs/qa/evidence/story-db-cnpg-operator/`
  - Expands Testing section to reference QA test IDs

## Edits Applied
- Story: `docs/stories/STORY-DB-CNPG-OPERATOR.md`
  - Testing: added evidence archival requirement and reference to QA test IDs
  - Definition of Done: requires QA Gate file and evidence; explicit execution of AC2–AC6 validation
  - Change Log: version 0.3 entry recording QA integration

## Rationale
- Aligns implementation and validation with QA’s risk assessment; prevents missing artifacts during review and makes the gate explicit.

## Approvals
- PO: Pending
- QA: Pending
- SM/Architect: Optional

---

Proceed to implement the story using updated DoD and Testing. Ensure a minor version choice (0.25.x vs 0.26.x) is finalized before merge.
