# 23 — STORY-DB-CNPG-SHARED-CLUSTER — Multi‑Tenant Postgres Cluster

Sequence: 23/41 | Prev: STORY-DB-CNPG-OPERATOR.md | Next: STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
Sprint: 5 | Lane: Database
Global Sequence: 23/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links:
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/externalsecrets.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/scheduledbackup.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/monitoring-configmap.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/prometheusrule.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/backup-validation.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/harbor-pooler.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/keycloak-pooler.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/gitlab-pooler.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/synergyflow-pooler.yaml

## Story
Provision a shared CNPG PostgreSQL cluster on infra with scheduled backups, monitoring, and PgBouncer poolers for platform apps.

## Why / Outcome
- Consolidated database service with operational guardrails.

## Scope
- Resources: `shared-cluster/*`, `poolers/*`, ExternalSecrets for credentials

Namespace & DNS
- Current manifests place data‑plane resources in `cnpg-system` (same as operator). If you prefer a dedicated data namespace (e.g., `databases`), call it out here and update manifests accordingly. Service names will follow `shared-postgres-rw`/`-ro` and pooler Services per pooler name within the chosen namespace.

Env & Secrets
- Required env vars: `CNPG_STORAGE_CLASS`, `CNPG_DATA_SIZE`, `CNPG_WAL_SIZE`, `CNPG_BACKUP_BUCKET`, `CNPG_MINIO_ENDPOINT_URL`, `EXTERNAL_SECRET_STORE`.
- ExternalSecrets inputs: `CNPG_SUPERUSER_SECRET_PATH`, `CNPG_MINIO_SECRET_PATH`, plus per‑app secret paths for `kubernetes/infra/cloudnative-pg/{harbor,keycloak,gitlab,synergyflow,readonly}`.
- Secret names referenced by manifests: `cnpg-superuser`, `cnpg-minio-credentials`, `{harbor,keycloak,gitlab,synergyflow}-db-credentials`, `postgres-readonly-credentials`, and `{harbor,keycloak,gitlab,synergyflow}-pooler-auth`.

## Acceptance Criteria
1) CNPG cluster pods Ready; primary elected; Service endpoints available.
2) Scheduled backups succeed (S3 RGW or external S3 per settings). Cron uses CNPG’s six‑field format and runs at 02:00 UTC; `cluster-settings` key `CNPG_BACKUP_SCHEDULE` is set to `"0 0 2 * * *"`.
3) Poolers deployed per app (≥3 replicas, anti‑affinity). Services resolvable for `rw` (and `ro` if declared).
4) Metrics: CNPG and PgBouncer metrics exposed and scraped (Prometheus/VictoriaMetrics). PodMonitor(s) present.
5) Security: TLS in transit confirmed client→pooler and pooler→Postgres (CNPG‑managed certs) or custom secrets documented.
6) Alerting: PrometheusRules fire on backup/replication issues; dashboards show cluster and pooler health.

## Dependencies / Inputs
- STORY-DB-CNPG-OPERATOR; StorageClass `${CEPH_BLOCK_STORAGE_CLASS}`; S3 credentials in secrets.

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/workloads/platform/databases/cloudnative-pg`.
- [ ] Replace/harden `backup-validation` CronJob to use a non‑root image with required tools preinstalled; drop privilege escalation/capabilities.
- [ ] Validate backup job success; add optional restore probe or barman dry‑run.
- [ ] Confirm `cluster-settings` value `CNPG_BACKUP_SCHEDULE` equals `"0 0 2 * * *"` (six‑field seconds‑first format) and the `ScheduledBackup` reflects the value after reconciliation.

## Validation Steps
- kubectl --context=infra -n cnpg-system get clusters.postgresql.cnpg.io -A
- kubectl --context=infra -n cnpg-system get scheduledbackups.postgresql.cnpg.io -A
- Confirm ScheduledBackup cron uses six fields and fires at 02:00 UTC (e.g., `0 0 2 * * *`).
- Verify cluster-settings: `kubectl --context=infra -n flux-system get cm cluster-settings -o jsonpath='{.data.CNPG_BACKUP_SCHEDULE}'` → `0 0 2 * * *`
- Poolers Ready: `kubectl --context=infra -n cnpg-system get deploy -l app.kubernetes.io/component=connection-pooler`
- Pooler Services resolvable: `kubectl --context=infra -n cnpg-system get svc -l cnpg.io/poolerName`; and `nslookup <pooler-svc>.cnpg-system.svc`.
- Metrics present: `curl -s <pooler-pod>:9127/metrics | rg '^cnpg_pgbouncer_'`; PodMonitor discovered.
- TLS check: verify client→pooler and pooler→Postgres TLS (CNPG defaults) or document custom auth/certs if overridden.
- Optional: validate backups via listing recent base backups and WAL; perform restore dry‑run against latest base backup.

ExternalSecret Preflight
- Verify ExternalSecrets in `cnpg-system` are synced: `kubectl --context=infra -n cnpg-system get externalsecret -o wide`; check `.status.conditions` for errors and alert routes.

Notes
- CNPG ScheduledBackup uses a six‑field cron expression (seconds first). Use `"0 0 2 * * *"` for 02:00 UTC; update `scheduledbackup.yaml` if it currently uses a five‑field form.

## Definition of Done
- ACs met with evidence.

---

## Research — CNPG Pooler (PgBouncer)

- What it is: CloudNativePG (CNPG) exposes a `Pooler` CRD that deploys PgBouncer as a separate, scalable access layer in front of a CNPG `Cluster` (`type: rw` or `ro`). Poolers live in the same namespace as their target cluster and are created/managed independently from the `Cluster`. citeturn0search3turn0search4
- Key spec fields: `.spec.instances` replica count, `.spec.type` (`rw`/`ro`), `.spec.pgbouncer.poolMode` (`session` or `transaction`), `.spec.pgbouncer.parameters` for tuning, optional `.spec.monitoring.enablePodMonitor: true` to auto‑create a `PodMonitor`. `.spec.pgbouncer.authQuery`/`authQuerySecret` enable custom auth queries. citeturn0search6
- Security/auth: Pooler reuses the cluster TLS certs for in‑transit encryption on both client→pooler and pooler→Postgres sides. CNPG creates a dedicated `auth_user` (`cnpg_pooler_pgbouncer`) and `user_search` function; PgBouncer authenticates to Postgres with a TLS client cert to run auth queries. If you supply your own secrets, you must manually create the role/function/grants. citeturn1view0
- Monitoring: CNPG’s PgBouncer image exposes Prometheus metrics on port `9127` with prefixes `cnpg_pgbouncer_*` (e.g., lists, pools, stats). You can enable an operator‑managed `PodMonitor` via `.spec.monitoring.enablePodMonitor: true`, or select pods by label `cnpg.io/poolerName: <POOLER_NAME>` in a manual PodMonitor. citeturn6view0

### Pooling Mode Guidance

- `transaction` mode maximizes server connection reuse but disallows session‑scoped features (e.g., `SET`, session advisory locks, WITH HOLD cursors, temp tables with PRESERVE/DELETE ROWS). Use only if apps don’t rely on these. citeturn0search2
- Prepared statements in transaction mode are supported if `max_prepared_statements > 0`, but client/driver caveats apply (e.g., older PHP/PDO). Alternatively, disable prepared statements at the client (e.g., JDBC `prepareThreshold=0`). citeturn0search0
- `session` mode preserves all PostgreSQL semantics at the cost of lower pooling efficiency. Choose per‑app based on workload characteristics. citeturn0search2

### Operational Notes

- Lifecycle: Poolers are decoupled from clusters (create/scale/roll independently). Operator upgrades trigger pooler pod rolling upgrades. citeturn0search3
- Rolling strategy: Use Deployment `RollingUpdate` with `maxUnavailable: 1` for zero‑drop during changes (mirrors our current manifests). Reference pod anti‑affinity across nodes for HA. citeturn0search6
- Pause/Resume: `.spec.pgbouncer.paused: true|false` maps to PgBouncer `PAUSE/RESUME` for safe maintenance windows. citeturn8view0
- Metrics check: `kubectl -n cnpg-system exec -ti <pooler-pod> -- curl -s 127.0.0.1:9127/metrics | rg cnpg_pgbouncer_` to verify scrape. citeturn6view0

### Baseline Recommendations (Infra Cluster)

- One pooler per app hitting the shared cluster (e.g., `harbor-pooler`, `keycloak-pooler`) with `.spec.type: rw` by default; add `ro` poolers for read‑heavy apps as needed. citeturn0search3
- Start with `poolMode: transaction` for stateless web apps and APIs; pin `session` for apps known to use session state (advisory locks, SET, LISTEN/NOTIFY patterns with HOLD cursors, etc.). Validate drivers against transaction‑mode limitations. citeturn0search4turn0search1
- Enable `.spec.monitoring.enablePodMonitor: true` and keep PodMonitor operator‑managed; scrape port `9127`. Ensure selector uses `cnpg.io/poolerName`. citeturn6view0
- Parameters: set sane upper bounds and timeouts per app. Example starting point (already reflected in our manifests): `max_client_conn`, `default_pool_size`, `min_pool_size`, `reserve_pool_size`, `server_connect_timeout`, `query_timeout`, `idle_transaction_timeout`, and `ignore_startup_parameters: "extra_float_digits,options"`. Tune using `cnpg_pgbouncer_stats_*` and application latency. citeturn6view0
- Topology: keep at least 3 replicas with pod anti‑affinity across nodes; ensure PDB and node spread at the environment layer to avoid cross‑AZ hops where possible. citeturn0search3

#### Per‑App Pooling Mode (initial)
- Harbor — transaction (current manifest)
- GitLab — transaction (current manifest)
- SynergyFlow — transaction (current manifest)
- Keycloak — session (current manifest)

### Acceptance Criteria — Pooler Additions

1) Pooler Deployments Ready with ≥3 replicas and anti‑affinity; Services for `rw` (and `ro` if declared) present and resolvable.
2) Metrics exposed on `9127/metrics`; PodMonitor discovered by Prometheus; `cnpg_pgbouncer_stats_*` time series present in VictoriaMetrics.
3) Security: TLS in transit confirmed client→pooler and pooler→Postgres (CNPG‑managed certs) or documented custom secrets with manual SQL integration where applicable. citeturn1view0turn0search4
4) For apps using `transaction` mode: validated driver compatibility and, if required, `max_prepared_statements > 0` or client‑side PS disabled. Evidence recorded. citeturn0search0

### References

- CNPG — Connection Pooling overview and examples (v1.16–v1.27). citeturn0search4turn0search3
- CNPG — Pooler API reference (fields and monitoring). citeturn0search6
- PgBouncer — Feature matrix by pooling mode; prepared statements FAQ. citeturn0search2turn0search0

---

## Research — Shared Cluster Best Practices

- Scheduled backups require a six‑field cron expression (seconds field first). Use `"0 0 2 * * *"` for 02:00 UTC instead of `"0 2 * * *"`. citeturn0search6
- Prefer declarative DB provisioning over ad‑hoc Jobs: CNPG provides a `Database` CRD for per‑database lifecycle; combine with `managed.roles` to avoid distributing superuser credentials. citeturn1search2turn1search3
- Synchronous replication: On ≥1.25, you can express durability with `dataDurability` and `postgresql.synchronous` (e.g., `preferred`/`required`) rather than only `minSyncReplicas/maxSyncReplicas`. Plan a migration to the new config when you align versions. citeturn3search2
- Backups: Use `barmanObjectStore` with compression and optional S3‑side encryption (`sse: AES256` or KMS). Periodically validate restore using barman cloud tools. citeturn4search0turn4search1
- Security and PSA: CNPG components do not require privileged pods; target `restricted` PSA for cluster namespaces and avoid running jobs as root with `apt-get` in‑pod. citeturn0search10

## Gap Analysis — Repo vs Best Practices

- ScheduledBackup cron uses 5‑field format (`"0 2 * * *"`); should be 6‑field (`"0 0 2 * * *"`). citeturn0search6
- Backup validation CronJob installs packages at runtime as root and sets broad Linux capabilities. Replace with a purpose‑built image (e.g., `minio/mc` or `aws-cli`) or CNPG barman tools and drop root/privilege escalation. citeturn4search2
- Superuser exposure: `enableSuperuserAccess: true` and provisioning Jobs use superuser creds. Prefer `Database` CR + `managed.roles`, and disable superuser access for day‑2 operations. citeturn1search2
- Operator/data‑plane mixing: Cluster and poolers run in `cnpg-system` (operator namespace). Move data‑plane resources into a dedicated namespace (e.g., `databases`) for least privilege and cleaner PSA boundaries. (Architecture practice.)
- Version migration opportunity: When aligning operator/CRDs to ≥1.25, plan to express synchronous replication via `dataDurability` and update retention/backup settings to match current defaults. citeturn3search2

## Tasks / Subtasks — Implementation Plan (Story Only)

- [ ] Fix ScheduledBackup cron to six‑field: `"0 0 2 * * *"`. citeturn0search6
- [ ] Replace `backup-validation` CronJob image with a non‑root image that already includes required tools (e.g., `minio/mc` or `public.ecr.aws/aws-cli/aws-cli`) and drop all added Linux capabilities. Add a simple `mc ls`/`mc find` check and, optionally, `barman-cloud-check-wal-archive`. citeturn4search2
- [ ] Add S3 server‑side encryption for backups (bucket policy or set `sse: AES256` in `barmanObjectStore`). citeturn4search1
- [ ] Adopt `Database` CRs for app databases (harbor, keycloak, gitlab, synergyflow) and remove ad‑hoc provisioning Jobs; keep `managed.roles` for per‑app users. citeturn1search2
- [ ] Reduce superuser use: set `enableSuperuserAccess: false` after migrating to Database CRs; keep the secret for break‑glass only (documented process).
- [ ] Move data‑plane (`Cluster`, `Pooler`, secrets) to `databases` namespace; retain operator in `cnpg-system`. Update Service DNS in provisioners/poolers accordingly.
- [ ] Keep 3 Postgres instances with HA slots and anti‑affinity; review switch to `dataDurability` API when versions align. citeturn3search2
- [ ] Ensure `monitoring.enablePodMonitor: true` for cluster and poolers; confirm VictoriaMetrics scrapes `cnpg_*` and `cnpg_pgbouncer_*` series.

## Validation Steps — Shared Cluster

- `kubectl --context=infra -n cnpg-system get clusters.postgresql.cnpg.io shared-postgres -o yaml | rg -n "status:|instances:|synchronous"`
- Confirm backups: new objects under `s3://${CNPG_BACKUP_BUCKET}/shared-postgres/` after schedule change; run restore dry‑run with barman cloud tools.
- Poolers: scrape metrics on `:9127/metrics` and validate connection pooling KPIs.
