# 50 — STORY-BOOT-AUTOMATION-ALIGN — Canonicalize Bootstrap via Taskfiles

Sequence: 50/50 | Prev: STORY-VALIDATE-MESSAGING-TENANCY.md | Next: —
Sprint: 7 | Lane: Bootstrap & Platform
Global Sequence: 50/50

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
1) CRDs: `task -d .taskfiles/bootstrap infra-crds` and `task -d .taskfiles/bootstrap apps-crds` succeed; `task -d .taskfiles/bootstrap list-crds` shows expected counts.
2) Core: `task -d .taskfiles/bootstrap phase:2 CLUSTER={infra|apps}` deploys core; `task -d .taskfiles/bootstrap status` confirms components.
3) CI (required for this story):
   - `.github/workflows/validate-infrastructure.yaml` contains a job that runs `task -d .taskfiles/bootstrap dry-run CLUSTER=infra` on PR and default‑branch pushes.
   - Job prints a concise summary to `$GITHUB_STEP_SUMMARY` including: phases attempted, CRD counts, helmfile release list, and a final status line.
   - A lint step verifies that all AC‑referenced Taskfile targets exist: `task -l -d .taskfiles/bootstrap | rg -q "^(infra-crds|apps-crds|phase:2|status|list-crds|dry-run)$"` (or equivalent). Fails if any are missing.
   - Initially non‑blocking is acceptable (`continue-on-error: true`), with a documented path to make it gating later.
4) Stories updated with “Taskfile is canonical; raw commands in Appendix”.

## Tasks / Subtasks
- T0 — Update STORIES
  - Edit `STORY-BOOT-CRDS.md` and `STORY-BOOT-CORE.md` Tasks sections to use `task` targets first.
  - Add Appendix sections retaining prior raw command sequences.
- T1 — CI Dry‑Run (MANDATORY in this story)
  - Add a job in `.github/workflows/validate-infrastructure.yaml` to run `task -d .taskfiles/bootstrap dry-run CLUSTER=infra` on PR + push.
  - Emit a short step summary with Helmfile releases and CRD counts. Use `continue-on-error: true` initially; note when to move to blocking.
  - Add a Taskfile target lint step that checks all AC‑referenced targets exist in `.taskfiles/bootstrap`.
  - Ensure the runner has `task` available (install if needed) and fail fast with a clear message if missing.

### Local Dry‑Run Examples (contributors)
- `task -d .taskfiles/bootstrap infra-crds DRY_RUN=true`
- `task -d .taskfiles/bootstrap apps-crds DRY_RUN=true`
- `task -d .taskfiles/bootstrap phase:2 CLUSTER=infra DRY_RUN=true`
- `task -d .taskfiles/bootstrap bootstrap CLUSTER=infra DRY_RUN=true`

Notes
- Unless overridden, `CONTEXT` defaults to the value of `CLUSTER` inside `.taskfiles/bootstrap/Taskfile.yaml`.

## Dev Notes

Variables and defaults
- `CLUSTER` (infra|apps) — required for some tasks
- `CONTEXT` — defaults to `CLUSTER`
- `DRY_RUN` — set to `true` to simulate actions locally

Local run examples
- `task -d .taskfiles/bootstrap infra-crds DRY_RUN=true`
- `task -d .taskfiles/bootstrap phase:2 CLUSTER=infra DRY_RUN=true`
- `task -d .taskfiles/bootstrap status CLUSTER=infra`

CI summary format (expected lines)
- Phases attempted (0–3)
- CRD counts (VictoriaMetrics, monitoring.coreos)
- Helmfile release list (from 01-core)
- Final status line (Succeeded/Issues noted)

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

## Change Log
| Date       | Version | Description                                   | Author |
|------------|---------|-----------------------------------------------|--------|
| 2025-10-21 | 0.2     | PO course‑correction + QA risk/design integ. | Sarah  |

## Dev Agent Record

### Agent Model Used
<to be filled by dev>

### Debug Log References
<to be filled by dev>

### Completion Notes List
<to be filled by dev>

### File List
<to be filled by dev>

## QA Results — Risk Profile (2025-10-21)

Reviewer: Quinn (Test Architect & Quality Advisor)

Summary
- Total Risks Identified: 11
- Critical: 2 | High: 3 | Medium: 5 | Low: 1
- Overall Story Risk Score: 49/100

Critical Risks (Must Address Within This Story)
- OPS-001 — CI does not execute Taskfile dry‑run per AC3 (Score 9). Mitigation: Update `.github/workflows/validate-infrastructure.yaml` to run `task -d .taskfiles/bootstrap dry-run CLUSTER=infra` and write a concise summary to `$GITHUB_STEP_SUMMARY`; keep `continue-on-error: true` initially.
- TECH-002 — Future drift between AC task names and Taskfile targets (Score 9). Mitigation: Keep ACs referencing fully‑qualified `task -d .taskfiles/bootstrap <target>` names; add a quick lint in CI that `task -l -d .taskfiles/bootstrap` contains all referenced targets.

Risk Matrix
| ID | Category | Description | Prob | Impact | Score | Priority | Mitigation / Owner |
|---|---|---|---|---|---:|---|---|
| OPS-001 | Operational | CI does not run Taskfile dry‑run required by AC3 | High(3) | High(3) | 9 | Critical | Add Taskfile step + summary; non‑blocking initially. Owner: Platform |
| TECH-002 | Technical | ACs drift from Taskfile target names | High(3) | High(3) | 9 | Critical | Reference targets with `-d .taskfiles/bootstrap`; add CI lint. Owner: SM/Platform |
| OPS-003 | Operational | No standard for dry‑run summary format | Medium(2) | High(3) | 6 | High | Define summary lines (phases executed, CRD counts, helmfile list). Owner: Platform |
| OPS-004 | Operational | Contributors still follow raw commands | Medium(2) | High(3) | 6 | High | Move raw to Appendix; add note “Taskfile is canonical” in both stories. Owner: SM |
| TECH-005 | Technical | CONTEXT/CLUSTER confusion during local runs | Medium(2) | Medium(2) | 4 | Medium | Document default: CONTEXT defaults to CLUSTER; examples provided. Owner: SM |
| OPS-006 | Operational | Missing gating plan timeline | Medium(2) | Medium(2) | 4 | Medium | Track issue to flip from non‑blocking → blocking after 2 green runs. Owner: PM |
| TECH-007 | Technical | Helmfile/Gateway CRD URLs change causing dry‑run noise | Low(1) | Medium(2) | 2 | Low | Pin versions and validate links in CI. Owner: Platform |
| OPS-008 | Operational | Taskfile not available in CI image | Medium(2) | Medium(2) | 4 | Medium | Install Task or vendor wrapper; verify with `task -v`. Owner: Platform |
| SEC-009 | Security | Workflow writes secrets to summary by mistake | Low(1) | High(3) | 3 | Low | Ensure summary only prints counts/names; no secrets. Owner: Platform |
| PERF-010 | Performance | Dry‑run takes too long in PRs | Medium(2) | Medium(2) | 4 | Medium | Limit output; short timeouts; cache tooling. Owner: Platform |
| OPS-011 | Operational | Multiple repos diverge on bootstrap process | Medium(2) | Medium(2) | 4 | Medium | Reuse Taskfile via subtree or shared module; document version. Owner: Platform |

Risk‑Based Testing Focus
- P1 (Critical):
  - CI step actually runs Taskfile dry‑run; verify non‑zero exit on catastrophic errors while keeping continue-on-error: true for the job.
  - Lint that all AC‑referenced targets exist in `.taskfiles/bootstrap` (e.g., `task -l`).
- P2 (High/Medium):
  - Verify `$GITHUB_STEP_SUMMARY` includes: phases attempted, CRD counts, helmfile release list, and final status line.
  - Confirm “Taskfile is canonical” statement present in referenced stories and that raw commands moved to Appendix.

Gate Decision
- Decision: CONCERNS — Proceed when OPS‑001 and TECH‑002 mitigations are implemented and validated by CI output.

## QA Results — Test Design (2025-10-21)

Designer: Quinn (Test Architect)

Test Strategy Overview
- Emphasis on integration and workflow validation (Taskfile invocation, CI behavior).
- Priorities: P0 on CI dry‑run execution and AC/Taskfile target alignment; P1 on local task runs; P2 on editorial checks.

Test Scenarios by Acceptance Criteria

AC1: CRDs installed via Taskfile; list-crds shows counts
- ID: BOOT-AUTO-INT-001 | Level: Integration | Priority: P1
  - Given a contributor shell with Task installed
  - When `task -d .taskfiles/bootstrap infra-crds DRY_RUN=true` runs
  - Then the command exits 0 and outputs Phase 1 messaging without errors

- ID: BOOT-AUTO-INT-002 | Level: Integration | Priority: P1
  - Given a contributor shell with access to a cluster context
  - When `task -d .taskfiles/bootstrap list-crds` runs
  - Then command exits 0 and prints counts for VictoriaMetrics and monitoring CRDs

AC2: Core deploy via phase:2; status confirms components
- ID: BOOT-AUTO-INT-003 | Level: Integration | Priority: P1
  - Given a test cluster context and Task installed
  - When `task -d .taskfiles/bootstrap phase:2 CLUSTER=infra DRY_RUN=true` runs
  - Then the command exits 0 and shows core sync intent (helmfile list)

- ID: BOOT-AUTO-INT-004 | Level: Integration | Priority: P2
  - Given Taskfile status target exists
  - When `task -d .taskfiles/bootstrap status CLUSTER=infra` runs (against a cluster)
  - Then output lists CRD counts and core component pod tallies

AC3: CI contains Taskfile dry‑run and writes summary
- ID: BOOT-AUTO-E2E-001 | Level: E2E (CI) | Priority: P0 | Mitigates: OPS-001
  - Given a PR to main that touches kubernetes/**
  - When the workflow runs
  - Then a step executes `task -d .taskfiles/bootstrap dry-run CLUSTER=infra` and appends to `$GITHUB_STEP_SUMMARY` a concise report (phases attempted, CRD counts, helmfile releases, final line)

- ID: BOOT-AUTO-INT-005 | Level: Integration | Priority: P0 | Mitigates: TECH-002
  - Given the story ACs reference Taskfile targets
  - When CI runs `task -l -d .taskfiles/bootstrap` and greps for each referenced target
  - Then all targets are found; otherwise fail this lint step

AC4: Stories updated to declare Taskfile canonical
- ID: BOOT-AUTO-UNIT-006 | Level: Unit (doc lint) | Priority: P2
  - Given the updated stories `STORY-BOOT-CRDS.md` and `STORY-BOOT-CORE.md`
  - When a doc check scans for the string "Taskfile is canonical; raw commands in Appendix"
  - Then both stories contain the statement in the expected sections

Negative / Edge Cases
- ID: BOOT-AUTO-NEG-007 | Level: Integration | Priority: P1
  - Given ACs reference a non-existent Taskfile target
  - When the CI lint runs
  - Then it fails with a clear message listing missing targets

Recommended Execution Order
1) P0: BOOT-AUTO-E2E-001 (CI dry-run), BOOT-AUTO-INT-005 (target lint)
2) P1: BOOT-AUTO-INT-001/002/003 (local task runs)
3) P2: BOOT-AUTO-INT-004 (status), BOOT-AUTO-UNIT-006 (doc lint)

Evidence to Capture (Dev Notes / CI Summary)
- CI: excerpt of `$GITHUB_STEP_SUMMARY` showing phases, CRD counts, helmfile list, final status line.
- Local: command exit codes and key lines from outputs (Phase 1, helmfile list, CRD counts).
