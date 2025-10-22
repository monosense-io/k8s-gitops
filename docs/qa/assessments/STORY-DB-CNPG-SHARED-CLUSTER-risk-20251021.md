# Risk Profile — STORY-DB-CNPG-SHARED-CLUSTER (Multi‑Tenant Postgres Cluster)

Date: 2025-10-21
Reviewer: Quinn (Test Architect)
Story: docs/stories/STORY-DB-CNPG-SHARED-CLUSTER.md
Related: kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/**, kubernetes/workloads/platform/databases/cloudnative-pg/poolers/**, docs/architecture.md

---

## Gate Snippet (risk_summary)

```yaml
risk_summary:
  totals:
    critical: 0
    high: 5
    medium: 6
    low: 1
  highest:
    id: DATA-001
    score: 6
    title: 'ScheduledBackup cron format incorrect — backups may not run'
  recommendations:
    must_fix:
      - 'Update ScheduledBackup to six-field cron (seconds first): 0 0 2 * * *'
      - 'Harden backup validation CronJob: non-root image with tools preinstalled; drop privilege escalation'
      - 'Enable S3 server-side encryption (SSE) for backups or enforce via bucket policy'
      - 'Add restore drill/dry-run to validate backup recoverability'
      - 'Plan to disable superuser access post-setup (break-glass only)'
    should_fix:
      - 'Decide and document data-plane namespace (cnpg-system vs databases) and align manifests'
      - 'Document per-app pooling mode (transaction vs session) and prepared-statement handling'
      - 'Add explicit pooler Service endpoint checks in validation steps'
  suggested_gate: CONCERNS
```

- Overall Risk Rating: High
- Overall Story Risk Score: ≈58/100 (aggregate, weighted by high risks)

---

## Risk Matrix

| Risk ID   | Category | Description                                                                               | Prob | Impact | Score | Priority |
| --------- | -------- | ----------------------------------------------------------------------------------------- | ---- | ------ | ----- | -------- |
| DATA-001  | Data     | ScheduledBackup cron is 5-field; CNPG expects 6-field (seconds first); backups may not run | 2    | 3      | 6     | P1       |
| SEC-001   | Security | Backup validation CronJob runs as root, installs tools at runtime; PSA/supply-chain risk  | 2    | 3      | 6     | P1       |
| TECH-001  | Tech     | Superuser access left enabled beyond bootstrap increases blast radius                     | 2    | 3      | 6     | P1       |
| DATA-002  | Data     | Backups may lack SSE; risk of data exposure in S3/RGW                                     | 2    | 3      | 6     | P1       |
| OPS-002   | Ops      | No restore drill; backups present but unrecoverable                                       | 2    | 3      | 6     | P1       |
| OPS-001   | Ops      | Operator/data-plane sharing cnpg-system namespace complicates PSA/RBAC boundaries         | 2    | 2      | 4     | P2       |
| PERF-001  | Perf     | Pooler sizing/tuning mistakes cause connection storms or starvation                       | 2    | 2      | 4     | P2       |
| TECH-002  | Tech     | Pooling mode mismatch (transaction vs session) and prepared-statement caveats             | 2    | 2      | 4     | P2       |
| MON-001   | Ops      | Metrics/PodMonitor miswiring → missing PgBouncer metrics                                  | 2    | 2      | 4     | P2       |
| OPS-003   | Ops      | ExternalSecret paths/keys mismatch → provision/connection failures                         | 2    | 2      | 4     | P2       |
| DATA-003  | Data     | Ad-hoc DB provisioner jobs drift from desired state; access grants diverge                | 2    | 2      | 4     | P2       |
| SEC-002   | Security | TLS misconfiguration between client↔pooler or pooler↔Postgres when customizing secrets    | 1    | 3      | 3     | P3       |

Legend: Probability (1–3), Impact (1–3), Score = Prob×Impact

---

## Detailed Risk Register with Mitigations

### DATA-001 — ScheduledBackup cron format incorrect (Score 6)
- Evidence: kubernetes/.../shared-cluster/scheduledbackup.yaml: schedule is `"0 2 * * *"` (5-field).
- Risk: Backups may never fire; false sense of protection.
- Mitigation: Change to six-field, seconds-first: `"0 0 2 * * *"`. Add CI lint or policy.
- Testing: After change, verify new objects appear under `s3://${CNPG_BACKUP_BUCKET}/shared-postgres/` and run a barman restore dry-run.

### SEC-001 — Backup validation CronJob privileges (Score 6)
- Evidence: backup-validation.yaml runs as root, installs packages via apt-get, `allowPrivilegeEscalation: true`.
- Risk: Violates restricted PSA; increases supply-chain and runtime risk.
- Mitigation: Use a non-root image with tools preinstalled (`aws-cli`, `minio/mc`, or barman-cloud); drop privilege escalation and extra capabilities.
- Testing: Job succeeds with read-only root FS; verify only S3 list/head ops occur.

### TECH-001 — Superuser access retained (Score 6)
- Evidence: cluster.yaml sets `enableSuperuserAccess: true`.
- Risk: Over-privileged operations post-setup; lateral movement risk.
- Mitigation: Adopt CNPG `Database` CRs + `managed.roles`; set `enableSuperuserAccess: false` after migration; keep break-glass documented.
- Testing: Validate app connectivity and role permissions after disabling superuser.

### DATA-002 — Missing server-side encryption (Score 6)
- Evidence: `barmanObjectStore` lacks explicit SSE; bucket policy not documented.
- Risk: Backup data exposure at rest.
- Mitigation: Set `sse: AES256` in `barmanObjectStore` or enforce via bucket policy/KMS.
- Testing: Inspect object metadata; confirm SSE headers present.

### OPS-002 — No restore drill (Score 6)
- Risk: Backups may be unrecoverable despite presence in S3.
- Mitigation: Add periodic restore drill or automated dry-run; capture RTO/RPO evidence.
- Testing: Execute barman restore dry-run to a temp path and validate integrity.

### OPS-001 — Namespace & PSA boundaries (Score 4)
- Evidence: cluster/poolers in `cnpg-system` (operator namespace).
- Risk: Least-privilege and PSA clarity reduced; noisy blast radius.
- Mitigation: Choose data-plane namespace (e.g., `databases`) and align manifests; update Services and DNS.
- Testing: Post-move, validate Kustomization health and Service discovery.

### PERF-001 — Pooler sizing/tuning (Score 4)
- Risk: Over/under-provisioned poolers can throttle throughput or overload Postgres.
- Mitigation: Start with conservative defaults; tune via `cnpg_pgbouncer_stats_*` and app latency; enforce PDB and anti-affinity.
- Testing: Load test representative traffic; watch pool metrics and DB saturation.

### TECH-002 — Pooling mode mismatches (Score 4)
- Risk: `transaction` mode breaks session features; prepared-statement caveats by driver.
- Mitigation: Document per-app mode; set PS behavior (e.g., disable client-side PS or adjust server settings) where needed.
- Testing: App-level tests for session features and prepared statements through pooler.

### MON-001 — Metrics/PodMonitor gaps (Score 4)
- Evidence: PodMonitors enabled; risk remains of label/selector mismatch.
- Mitigation: Validate pod labels and discovery; ensure Prometheus/Victoria scrape success.
- Testing: Confirm `cnpg_*` and `cnpg_pgbouncer_*` time series present.

### OPS-003 — ExternalSecret path/key mismatch (Score 4)
- Evidence: Multiple ExternalSecrets depend on 1Password paths.
- Risk: Secret sync failure → auth errors.
- Mitigation: Validate paths; add preflight check; alert on ESO sync failures.
- Testing: Observe ExternalSecret status conditions; simulate missing key.

### DATA-003 — Ad‑hoc provisioner jobs (Score 4)
- Evidence: harbor-database-provisioner.yaml performs DDL and grants.
- Risk: Drift vs declarative desired state; inconsistent grants.
- Mitigation: Replace with CNPG `Database` CRs; keep grants in `managed.roles`.
- Testing: Verify DB lifecycle and permissions through CRs; remove job.

### SEC-002 — TLS gaps with custom secrets (Score 3)
- Risk: If overriding CNPG-managed certs, TLS may fail or downgrade.
- Mitigation: Prefer CNPG-managed TLS; if custom, document and test both legs (client↔pooler, pooler↔DB).
- Testing: OpenSSL/psql `sslmode=verify-full` checks; inspect server certs.

---

## Risk-Based Testing Strategy

### Priority 1 (address before moving on)
- Fix ScheduledBackup cron and verify actual backup artifacts appear (DATA-001).
- Harden backup validation job and rerun (SEC-001).
- Add/execute restore dry-run; record evidence (OPS-002).
- Configure SSE and confirm on objects (DATA-002).
- Plan and test disabling superuser after per-app DB lifecycle in place (TECH-001).

### Priority 2
- Validate pooler Services, metrics discovery, and tuning under load (PERF-001, MON-001).
- Prove app compatibility for chosen pooling mode and PS handling (TECH-002).
- Confirm ExternalSecrets paths and alerting (OPS-003).
- Decide and apply namespace alignment; revalidate health (OPS-001).

### Priority 3
- TLS verification for any custom cert flow (SEC-002).

---

## Risk Acceptance Criteria
- Must Fix before production: All score 6 risks (DATA-001, SEC-001, TECH-001, DATA-002, OPS-002).
- Acceptable with monitoring: Score 4 risks once mitigations and tests pass.
- Residual low risks: Documented with periodic revalidation.

