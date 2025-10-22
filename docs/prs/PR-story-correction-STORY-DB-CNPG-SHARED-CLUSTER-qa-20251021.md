# Sprint Change Proposal — STORY-DB-CNPG-SHARED-CLUSTER (QA Integration) — 2025-10-21

Owner: Product Owner (Sarah)
Contributors: QA (Quinn), Scrum Master (Bob)
Related Story: docs/stories/STORY-DB-CNPG-SHARED-CLUSTER.md
Related QA Artifacts:
- Risk Profile: docs/qa/assessments/STORY-DB-CNPG-SHARED-CLUSTER-risk-20251021.md
- Test Design: docs/qa/assessments/STORY-DB-CNPG-SHARED-CLUSTER-test-design-20251021.md

## 1) Analysis Summary
- Trigger: QA risk profile flagged multiple P1 risks (cron format, backup validator privileges, missing SSE, restore drill) and medium risks (namespace boundaries, pooler tuning, prepared statements, metrics discovery, ESO paths).
- Impact: Backups may not run or be recoverable; security posture weakened; ambiguous namespace impacts validation and Service DNS; potential app incompatibilities with pooling mode.
- Path Forward: Apply minimal manifest fixes (cron format, validator hardening, SSE), tighten story validation steps, and lock namespace decision. Retain superuser for bootstrap only; plan to disable post‑migration.

## 2) Proposed Edits (for approval)

### A. Story — docs/stories/STORY-DB-CNPG-SHARED-CLUSTER.md
1. Validation Steps — add explicit pooler Service resolution check:
   - Add: `kubectl --context=infra -n <namespace> get svc -l cnpg.io/poolerName; nslookup <pooler-svc>.<namespace>.svc`
2. Namespace decision — replace `<namespace>` placeholders with the chosen namespace once decided (see Decisions Required).
3. Keep ACs as currently strengthened (metrics, TLS, alerts, cron six‑field note).

### B. Manifests — Minimal, Safe Fixes
1. ScheduledBackup cron (critical)
   - File: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/scheduledbackup.yaml`
   - Change: `.spec.schedule` from `"0 2 * * *"` → `"0 0 2 * * *"` (six‑field, seconds first; 02:00 UTC).

2. Backup validation CronJob hardening (critical)
   - File: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/backup-validation.yaml`
   - Option A (aws-cli):
     - `image: public.ecr.aws/aws-cli/aws-cli:2`
     - Remove in‑pod `apt-get` install block.
     - Run as non‑root; `allowPrivilegeEscalation: false`; drop added capabilities; keep read‑only root FS.
     - Command performs only S3 list/head operations using provided env vars.
   - Option B (minio/mc):
     - `image: minio/mc:RELEASE-*`
     - Use `mc alias set` with endpoint + creds; `mc find`/`mc ls` for presence checks.
   - Option C (barman cloud):
     - Use `ghcr.io/cloudnative-pg/barman-cloud` and run `barman-cloud-check-wal-archive`/restore dry‑run commands.

3. Backups SSE at rest (critical)
   - File: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml`
   - Add under `.spec.backup.barmanObjectStore`: `sse: AES256` (or document bucket/KMS policy).

4. Superuser hardening (should‑fix plan)
   - File: `.../shared-cluster/cluster.yaml`
   - After per‑app `Database` CR adoption, set `enableSuperuserAccess: false`. Retain secret for break‑glass and document the process.

5. Optional (advisory) — Namespace alignment
   - Move data‑plane resources (`Cluster`, `Pooler`, ExternalSecrets) from `cnpg-system` to a dedicated `databases` namespace to improve PSA/RBAC boundaries. Update Services/DNS accordingly. Re‑run all validation checks.

## 3) Mapping to QA Artifacts
- Risks mitigated by these edits: DATA‑001, SEC‑001, DATA‑002, OPS‑002 (critical); OPS‑001, TECH‑001, MON‑001 (should‑fix).
- Test design coverage references: P0 scenarios DB.CNPG.SHARED‑UNIT‑001, ‑INT‑003/004/005/007/008, ‑E2E‑001/002/004/006.

## 4) Decisions Required
- Namespace: keep `cnpg-system` (current) or move to `databases` (recommended)?
- Backup validator: choose Option A (aws-cli), B (minio/mc), or C (barman cloud)?
- SSE method: inline `sse: AES256` in manifest vs enforce via bucket policy/KMS?
- Timeline to disable superuser after adopting per‑app Database CRs?

## 5) Gate Suggestion
- Until critical fixes are merged and validated, maintain QA gate as CONCERNS for this story.

## 6) Implementation Plan (once approved)
- Commit patch set in this order: cron → SSE → validator hardening → story validation step → (optional) namespace move.
- Execute P0 tests from the test design; attach evidence under `docs/qa/evidence/`.

## 7) Approval Checklist
- [ ] Approve namespace choice
- [ ] Choose backup validator option (A/B/C)
- [ ] Approve adding `sse: AES256` (or bucket/KMS policy doc)
- [ ] Approve disabling superuser post‑migration plan
- [ ] Approve story validation step addition

---

If approved, I will apply the changes and notify QA to re-run P0 scenarios.
