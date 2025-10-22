# Test Design: STORY-DB-CNPG-SHARED-CLUSTER — Multi‑Tenant Postgres Cluster

Date: 2025-10-21
Designer: Quinn (Test Architect)
Story: docs/stories/STORY-DB-CNPG-SHARED-CLUSTER.md
Related Risk Profile: docs/qa/assessments/STORY-DB-CNPG-SHARED-CLUSTER-risk-20251021.md

## Test Strategy Overview
- Scope: Validate CNPG shared cluster readiness, backups, poolers, metrics, TLS, and alerting on the infra cluster.
- Total test scenarios: 19
- By level: Unit 3, Integration 9, E2E 7
- By priority: P0 11, P1 6, P2 2
- Execution environment: Kubernetes context `infra`; S3-compatible endpoint via `${CNPG_MINIO_ENDPOINT_URL}`; Prometheus/VictoriaMetrics UI/API access.

Notation: IDs use `DB.CNPG.SHARED-{LEVEL}-{SEQ}`; some scenarios parameterized by `APP ∈ {harbor,keycloak,gitlab,synergyflow}`.

## Test Scenarios by Acceptance Criteria

### AC1: CNPG cluster pods Ready; primary elected; Service endpoints available

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                        | Justification                                |
| ----------------------- | ----------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| DB.CNPG.SHARED-INT-001  | Integration | P0       | G: `infra` ctx. W: `kubectl --context=infra -n <ns> get clusters.postgresql.cnpg.io shared-postgres -o yaml`. T: `.status.phase==Ready` and `.status.currentPrimary!=""`. | Validates operator-level cluster readiness.  |
| DB.CNPG.SHARED-E2E-001  | E2E         | P0       | G: CTX. W: `kubectl -n <ns> get pods -l cnpg.io/cluster=shared-postgres`. T: all 3 pods Ready and anti‑affined across nodes.                  | Runtime readiness across nodes.              |
| DB.CNPG.SHARED-INT-002  | Integration | P1       | G: CTX. W: `kubectl -n <ns> get svc -l cnpg.io/cluster=shared-postgres`. T: `shared-postgres-rw` endpoints present and resolvable.            | Service discoverability.                     |

### AC2: Scheduled backups succeed; six‑field cron at 02:00 UTC

| ID                      | Level | Priority | Test (Given/When/Then)                                                                                                                               | Justification                                   |
| ----------------------- | ----- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| DB.CNPG.SHARED-UNIT-001 | Unit  | P0       | G: repo. W: `yq '.spec.schedule' kubernetes/.../scheduledbackup.yaml`. T: value matches regex `^\"?0 0 2 \* \* \*\"?$` (six‑field).           | Static guard for cron format.                   |
| DB.CNPG.SHARED-INT-003  | Int   | P0       | G: CTX. W: after schedule window, list S3: `aws s3 ls s3://$CNPG_BACKUP_BUCKET/shared-postgres/ --endpoint-url $CNPG_MINIO_ENDPOINT_URL`. T: new objects appear daily. | Confirms scheduled backups run.                 |
| DB.CNPG.SHARED-E2E-002  | E2E   | P0       | G: CTX and barman tools image. W: run barman cloud restore dry‑run against last base backup. T: restore command completes without integrity errors.   | Proves recoverability, not just presence.       |
| DB.CNPG.SHARED-INT-004  | Int   | P0       | G: S3 access. W: `aws s3api head-object` on a recent backup file. T: `ServerSideEncryption∈{AES256,aws:kms}`.                                      | Verifies SSE at rest.                           |

### AC3: Poolers per app (≥3 replicas, anti‑affinity). Services resolvable

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                        | Justification                               |
| ----------------------- | ----------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| DB.CNPG.SHARED-INT-005  | Integration | P0       | G: CTX. W: for each APP, `kubectl -n <ns> get deploy <APP>-pooler`. T: `status.availableReplicas==3`.                                          | Ensures HA for connection layer.             |
| DB.CNPG.SHARED-INT-006  | Integration | P1       | G: CTX. W: `kubectl -n <ns> get deploy -o yaml <APP>-pooler`. T: anti‑affinity rules present (hostname spread).                                | Distribution across nodes.                   |
| DB.CNPG.SHARED-E2E-003  | E2E         | P1       | G: CTX. W: `kubectl -n <ns> get svc -l cnpg.io/poolerName`. T: Services exist per pooler; `nslookup <APP>-pooler.<ns>.svc`.                    | Client‑facing Service discovery.              |

### AC4: Metrics exposed and scraped; PodMonitor(s) present

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                                      | Justification                                  |
| ----------------------- | ----------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| DB.CNPG.SHARED-INT-007  | Integration | P0       | G: CTX. W: `kubectl -n <ns> get pod -l cnpg.io/poolerName=<APP>-pooler`. Exec curl 127.0.0.1:9127/metrics. T: lines begin with `cnpg_pgbouncer_`.         | Confirms exporter endpoint.                    |
| DB.CNPG.SHARED-INT-008  | Integration | P0       | G: CTX. W: `kubectl -n <ns> get podmonitor -l cnpg.io/poolerName` and for cluster `monitoring.enablePodMonitor`. T: PodMonitors exist and select pods.    | Scrape config present.                         |
| DB.CNPG.SHARED-E2E-004  | E2E         | P0       | G: Prometheus/Victoria query access. W: query `cnpg_pgbouncer_stats_*` and `cnpg_*` series. T: non‑empty results for last 5m.                              | End‑to‑end scrape validation.                  |

### AC5: TLS in transit confirmed client→pooler and pooler→Postgres (or custom documented)

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                                                  | Justification                               |
| ----------------------- | ----------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| DB.CNPG.SHARED-E2E-005  | E2E         | P0       | G: CTX and psql client certs trust chain. W: `psql "host=<APP>-pooler.<ns>.svc sslmode=verify-full dbname=postgres user=<app_user>" -c 'select version();'`. T: SSL used, CN matches. | Validates client→pooler TLS.                |
| DB.CNPG.SHARED-INT-009  | Integration | P1       | G: Pooler pod. W: inspect PgBouncer connection params or CNPG docs; verify pooler uses CNPG‑managed certs to DB; optional: tcpdump in non‑prod to confirm TLS.            | Validates pooler→DB TLS (non‑intrusively).   |

### AC6: PrometheusRules fire on failures; dashboards available

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                                 | Justification                               |
| ----------------------- | ----------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| DB.CNPG.SHARED-INT-010  | Integration | P1       | G: CTX. W: `kubectl -n <ns> get prometheusrule -l app.kubernetes.io/part-of=cloudnative-pg -o yaml`. T: expected CNPG alert rules present.         | Rule presence.                               |
| DB.CNPG.SHARED-E2E-006  | E2E         | P0       | G: PromQL access. W: temporarily pause a pooler (`.spec.pgbouncer.paused: true`) or simulate backup miss (non‑prod). T: corresponding alert transitions to Firing. | Validates alerting behavior end‑to‑end.     |

## Negative and Edge Case Tests

| ID                      | Level       | Priority | Test (Given/When/Then)                                                                                                                                      | Mitigates Risks                   |
| ----------------------- | ----------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| DB.CNPG.SHARED-INT-011  | Integration | P1       | G: APP using `transaction` mode. W: run app‑level prepared statements (driver default). T: either succeeds with server PS or disable client PS; document behavior. | TECH-002 (PS with transaction).  |
| DB.CNPG.SHARED-INT-012  | Integration | P2       | G: ExternalSecrets. W: intentionally wrong key path in non‑prod. T: ESO condition shows error; alert route triggers; revert and recover.                         | OPS-003 (secret path mismatch).  |

## Risk Coverage Mapping
- DATA-001 (cron format) → DB.CNPG.SHARED-UNIT-001, -INT-003, -E2E-002
- SEC-001 (backup validator privileges) → DB.CNPG.SHARED-E2E-002 (uses hardened image), operational review
- TECH-001 (superuser post‑setup) → add follow‑up test after migration to `enableSuperuserAccess: false` (advisory)
- DATA-002 (SSE) → DB.CNPG.SHARED-INT-004
- OPS-002 (restore drill) → DB.CNPG.SHARED-E2E-002
- OPS-001 (namespace boundaries) → AC1/3/4 checks rerun post‑namespace move (advisory)
- PERF-001 (pooler tuning) → AC3/4 metrics plus load observation (advisory)
- TECH-002 (pooling mode) → DB.CNPG.SHARED-INT-011
- MON-001 (metrics discovery) → DB.CNPG.SHARED-INT-008, -E2E-004
- OPS-003 (ESO paths) → DB.CNPG.SHARED-INT-012
- DATA-003 (ad‑hoc jobs) → advisory: adopt `Database` CRs and re‑run AC3/5
- SEC-002 (TLS) → DB.CNPG.SHARED-E2E-005, -INT-009

## Recommended Execution Order
1. P0 Unit: -UNIT-001
2. P0 Integration: -INT-001, -INT-003, -INT-004, -INT-005, -INT-007, -INT-008
3. P0 E2E: -E2E-001, -E2E-002, -E2E-004, -E2E-006, -E2E-005
4. P1 set: -INT-002, -INT-006, -INT-010, -INT-011, -INT-012, -E2E-003
5. P2 set as time permits

## Gate YAML Block
```yaml
test_design:
  scenarios_total: 19
  by_level:
    unit: 3
    integration: 9
    e2e: 7
  by_priority:
    p0: 11
    p1: 6
    p2: 2
  coverage_gaps: []
```

## Notes
- Replace `<ns>` with the decided data‑plane namespace (`cnpg-system` currently; `databases` preferred for least privilege). Re‑run all AC checks if namespace changes.
- Use a purpose‑built non‑root image for backup restore drills (e.g., `ghcr.io/cloudnative-pg/barman-cloud` or `public.ecr.aws/aws-cli/aws-cli:2`).
- Keep tests non‑destructive; limit Paused/Resume or backup miss simulations to non‑production.

