# 13 — STORY-BOOT-AUTOMATION-ALIGN — Canonicalize Bootstrap via Taskfiles

Sequence: 13/21 | Prev: STORY-NET-CILIUM-CLUSTERMESH.md | Next: STORY-STO-OPENEBS-BASE.md

Status: Draft
Owner: Product → Platform Engineering
Date: 2025-10-21
Links: docs/stories/STORY-BOOT-CRDS.md; docs/stories/STORY-BOOT-CORE.md; .taskfiles/bootstrap/Taskfile.yaml

## Story
As a Platform Engineer, I want CRD/Core bootstrap to be executed exclusively through Taskfile entrypoints (with raw commands moved to appendices), so that onboarding, runbooks, and CI dry‑runs use one source of truth.

## Why / Outcome
- Consistent, repeatable bootstrap across contributors and CI.
- Lower cognitive load: fewer imperative command sequences to remember.
- Easier drift detection via `task bootstrap:dry-run`.

## Scope
- Update CRDS and CORE stories to reference only Taskfile entrypoints in Tasks/Acceptance sections.
- Keep raw kubectl/helmfile pipelines in a clearly labeled Appendix for deep‑dive reference.

## Acceptance Criteria
1) CRDs: `task bootstrap:infra-crds` and `task bootstrap:apps-crds` succeed; `task bootstrap:list-crds` shows expected counts.
2) Core: `task bootstrap:phase:2 CLUSTER={infra|apps}` deploys core; `task bootstrap:status` confirms components.
3) CI (required for this story):
   - `.github/workflows/validate-infrastructure.yaml` contains a job that runs `task bootstrap:dry-run CLUSTER=infra` on PR and default‑branch pushes.
   - Job prints a concise summary to the workflow summary. Initially non‑blocking is acceptable (continue‑on‑error), with a documented path to make it gating later.
4) Stories updated with “Taskfile is canonical; raw commands in Appendix”.

## Tasks / Subtasks
- T0 — Update STORIES
  - Edit `STORY-BOOT-CRDS.md` and `STORY-BOOT-CORE.md` Tasks sections to use `task` targets first.
  - Add Appendix sections retaining prior raw command sequences.
- T1 — CI Dry‑Run (MANDATORY in this story)
  - Add a job in `.github/workflows/validate-infrastructure.yaml` to run `task bootstrap:dry-run CLUSTER=infra` on PR + push.
  - Emit a short step summary with Helmfile releases and CRD counts. Use `continue-on-error: true` initially; note when to move to blocking.

## Definition of Done
- Both stories read cleanly with Taskfile as primary path; all acceptance checks are expressible via tasks; Appendix exists for raw commands.
- CI job exists and runs the dry‑run; link to a passing run is recorded in Dev Notes.

## Architect Handoff
- Architecture (docs/architecture.md)
  - Update “Bootstrap Architecture” to reference Taskfile entrypoints by name and phase.
  - Add explicit phase guard: Phase 0 emits only CRDs; Phase 1 installs controllers with CRDs disabled; include a validation note (kinds audit).
  - Show mapping of Flux handoff criteria to story ACs.
- PRD (docs/prd.md)
  - Add NFRs for Taskfile canonicalization and idempotency.
  - Add CI dry‑run requirement and success criteria (summary output, non‑blocking start, intent to gate later).
