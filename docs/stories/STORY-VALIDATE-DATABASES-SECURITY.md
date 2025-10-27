# 47 — STORY-VALIDATE-DATABASES-SECURITY — Deploy & Validate Databases and Security

Sequence: 47/50 | Prev: STORY-VALIDATE-STORAGE-OBSERVABILITY.md | Next: STORY-VALIDATE-APPS-CLUSTER.md
Sprint: 8 | Lane: Deployment & Validation
Global Sequence: 47/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md; docs/SCHEDULE-V2-GREENFIELD.md; Stories 22-24 (database manifests)

ID: STORY-VALIDATE-DATABASES-SECURITY

## Story

As a Platform Engineer, I want to deploy and validate all database manifests (stories 22-24) on the apps cluster, so that I can verify CloudNative-PG, DragonflyDB, and database infrastructure are operational before deploying CI/CD, messaging, and application workloads.

This story focuses on **database layer validation** as part of the phased deployment approach. Story 45 (VALIDATE-NETWORKING) completed networking, Story 46 (VALIDATE-STORAGE-OBSERVABILITY) completed storage and monitoring. This story establishes the database foundation for stateful applications.

## Why / Outcome

- **Deploy database manifests** (stories 22-24) to apps cluster
- **Validate CloudNative-PG** with shared PostgreSQL cluster and multi-tenant poolers
- **Validate DragonflyDB** as Redis-compatible cache/database
- **Test database operations** (connections, backups, failover, performance)
- **Establish database infrastructure** for GitLab, Harbor, Keycloak, applications
- **Verify monitoring** of database metrics and logs

## Scope

### v3.0 Phased Validation Approach

**Prerequisites** (completed in Stories 45-46):
- Networking operational (Cilium, DNS, certs)
- Storage operational (OpenEBS, Rook-Ceph with HEALTH_OK)
- Observability operational (VictoriaMetrics, VictoriaLogs, collectors)

**This Story Deploys & Validates**:
- Database manifests (stories 22-24)
- Database operational testing (connections, backups, performance)
- Integration with storage and observability

**Deferred to Story 48**:
- CI/CD deployment (GitLab, GitHub ARC)
- Messaging deployment (Kafka, Schema Registry)
- Application deployment (Harbor, Keycloak)

### Database Coverage (Stories 22-24)

22. STORY-DB-CNPG-OPERATOR — CloudNative-PG operator (apps cluster)
23. STORY-DB-CNPG-SHARED-CLUSTER — Shared PostgreSQL cluster with multi-tenant poolers
24. STORY-DB-DRAGONFLY-OPERATOR-CLUSTER — DragonflyDB operator + cluster

**Note on Security Stories**: Based on the manifest creation stories, NetworkPolicy, Keycloak, and SPIRE may be created in earlier stories (1-15). If security manifests exist, they should already be deployed as part of Story 45 (networking/security). This story focuses on databases only.

## Acceptance Criteria

### AC1 — CloudNative-PG Operator Operational

**Deployment**:
- [ ] CloudNative-PG operator pod Running in `cnpg-system` namespace
- [ ] CRDs Established: `Cluster`, `Pooler`, `Backup`, `ScheduledBackup`
- [ ] Operator logs show no errors
- [ ] Operator webhook service responding

**Monitoring**:
- [ ] ServiceMonitor scraping operator metrics
- [ ] Metrics visible in VictoriaMetrics: `cnpg_*`
- [ ] PrometheusRule alerts loaded (if defined)

### AC2 — Shared PostgreSQL Cluster Operational

**Cluster Health**:
- [ ] PostgreSQL cluster `shared-postgres` status: Cluster in healthy state (3 instances)
- [ ] 3 replica pods Running: `shared-postgres-1`, `shared-postgres-2`, `shared-postgres-3`
- [ ] Primary elected and replicas streaming from primary
- [ ] Synchronous replication configured (`minSyncReplicas=1`, `maxSyncReplicas=2`)
- [ ] Cluster using Rook-Ceph storage (`rook-ceph-block` storage class)

**Replication Validation**:
- [ ] Check replication status:
  ```sql
  SELECT * FROM pg_stat_replication;
  -- sync_state should show 'sync' for at least 1 replica
  ```
- [ ] Verify WAL streaming lag is minimal (<1MB)
- [ ] Test failover: delete primary pod, verify replica promoted, new replica created

**TLS Configuration**:
- [ ] TLS enabled for client connections
- [ ] Server certificate from cert-manager or self-signed
- [ ] Verify TLS connection: `psql "sslmode=require"`

### AC3 — Database Provisioning & Tenants

**Databases Created**:
- [ ] `gitlabhq_production` database for GitLab
- [ ] `registry` database for Harbor
- [ ] `keycloak` database for Keycloak
- [ ] `synergyflow` database for SynergyFlow application
- [ ] Each database has dedicated owner role with appropriate permissions

**Database Validation**:
- [ ] Connect to each database directly (via port-forward to primary pod)
- [ ] Verify database encoding (UTF8)
- [ ] Check for required extensions (if any):
  - GitLab: `pg_trgm`, `btree_gist`, `plpgsql`
  - Harbor: `uuid-ossp`
- [ ] Verify database sizes (empty initially)

### AC4 — PgBouncer Poolers Operational

**Poolers Deployed**:
- [ ] `gitlab-pooler-rw` (transaction mode, max 200 connections, pool size 15)
- [ ] `gitlab-pooler-ro` (readonly, transaction mode)
- [ ] `harbor-pooler-rw` (transaction mode, max 100 connections, pool size 10)
- [ ] `keycloak-pooler-rw` (session mode for Keycloak compatibility)
- [ ] `synergyflow-pooler-rw` (transaction mode)

**Pooler Health**:
- [ ] All pooler pods Running
- [ ] Poolers connected to PostgreSQL cluster
- [ ] Connection pooling working (check `SHOW POOLS` in pgbouncer admin console)
- [ ] PodDisruptionBudget configured (maxUnavailable=1)

**Connection Testing**:
- [ ] Connect to GitLab database via pooler:
  ```bash
  kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production
  ```
- [ ] Repeat for all poolers
- [ ] Verify connection succeeds and queries work

**Failover Testing**:
- [ ] Connect via pooler
- [ ] Delete primary PostgreSQL pod (simulate failure)
- [ ] Verify pooler automatically reconnects to new primary
- [ ] Verify minimal downtime (<30 seconds)

### AC5 — PostgreSQL Backups Operational

**ScheduledBackup Configuration**:
- [ ] ScheduledBackup resource created (daily backups)
- [ ] Backup destination configured (S3-compatible object storage or PVC)
- [ ] Retention policy configured (e.g., 30 days)

**Backup Validation**:
- [ ] Trigger manual backup:
  ```bash
  kubectl cnpg backup shared-postgres -n cnpg-system --backup-name manual-test-backup
  ```
- [ ] Verify backup completes successfully
- [ ] Check backup status:
  ```bash
  kubectl get backup -n cnpg-system
  # Status: completed
  ```
- [ ] Verify backup uploaded to destination (check S3 bucket or PVC)

**Restore Testing**:
- [ ] Create test database with sample data
- [ ] Create backup
- [ ] Drop test database
- [ ] Restore from backup:
  ```bash
  kubectl cnpg restore shared-postgres -n cnpg-system --backup-name manual-test-backup
  ```
- [ ] Verify data restored successfully

### AC6 — DragonflyDB Operator Operational

**Operator Deployment**:
- [ ] DragonflyDB operator pod Running in `dragonfly-system` namespace
- [ ] Dragonfly CRD Established
- [ ] Operator logs show no errors

**Monitoring**:
- [ ] ServiceMonitor scraping operator metrics (if available)
- [ ] Metrics visible in VictoriaMetrics

### AC7 — DragonflyDB Cluster Operational

**Cluster Health**:
- [ ] DragonflyDB instance deployed (3 replicas for HA)
- [ ] All replica pods Running
- [ ] Redis protocol compatibility enabled
- [ ] Persistence configured (RDB snapshots or AOF)

**Connection Testing**:
- [ ] Connect with redis-cli:
  ```bash
  kubectl exec -it -n dragonfly-system dragonfly-0 -- redis-cli
  > PING
  PONG
  ```
- [ ] Test basic operations:
  ```redis
  SET test-key "test-value"
  GET test-key
  # Should return: "test-value"
  ```
- [ ] Test data structures (lists, sets, hashes, sorted sets)
- [ ] Test pub/sub (if used)

**Persistence Testing**:
- [ ] Write test data
- [ ] Delete DragonflyDB pod
- [ ] Wait for pod recreation
- [ ] Verify data persisted (GET test-key still returns value)

**Replication Testing** (if multi-replica):
- [ ] Write data to primary
- [ ] Read from replica, verify data replicated
- [ ] Check replication lag (should be minimal)

### AC8 — Database Performance Baselines

**PostgreSQL Performance**:
- [ ] Run pgbench initialization:
  ```bash
  kubectl exec -it shared-postgres-1 -n cnpg-system -- pgbench -i -s 10 postgres
  ```
- [ ] Run pgbench benchmark:
  ```bash
  kubectl exec -it shared-postgres-1 -n cnpg-system -- pgbench -c 10 -j 2 -t 1000 postgres
  ```
- [ ] Capture TPS (transactions per second) baseline
- [ ] Target: >1000 TPS for small-scale workload

**DragonflyDB Performance**:
- [ ] Run redis-benchmark:
  ```bash
  kubectl exec -it -n dragonfly-system dragonfly-0 -- redis-benchmark -t set,get -n 100000 -q
  ```
- [ ] Capture SET/GET operations per second
- [ ] Target: >50,000 ops/sec

### AC9 — Database Monitoring Integration

**Metrics Collection**:
- [ ] PostgreSQL metrics scraped by VMAgent:
  - `pg_stat_database_*` (database statistics)
  - `pg_stat_replication_*` (replication lag)
  - `cnpg_*` (CNPG operator metrics)
  - `pgbouncer_*` (pooler metrics)
- [ ] DragonflyDB metrics scraped:
  - `dragonfly_*` (if exposed)
  - Redis-compatible metrics

**Logs Collection**:
- [ ] PostgreSQL logs forwarded to VictoriaLogs (via fluent-bit)
- [ ] DragonflyDB logs forwarded to VictoriaLogs
- [ ] Query logs: `{namespace="cnpg-system"} |= "statement"`

**Grafana Dashboards**:
- [ ] Import CNPG dashboard (if available)
- [ ] Verify PostgreSQL metrics visible in Grafana
- [ ] Verify DragonflyDB metrics visible
- [ ] Create test dashboard for database health

### AC10 — Integration Testing

**Application Database Integration**:
- [ ] Deploy test application (e.g., simple web app with database)
- [ ] Application connects to PostgreSQL via pooler
- [ ] Application performs CRUD operations
- [ ] Verify data persisted in PostgreSQL
- [ ] Verify application metrics and logs collected

**Cache Integration**:
- [ ] Deploy test application using DragonflyDB for caching
- [ ] Verify cache SET/GET operations work
- [ ] Test cache expiration (TTL)
- [ ] Verify cache hit/miss metrics

**Storage Integration**:
- [ ] Verify PostgreSQL using Rook-Ceph PVCs (check PVC status)
- [ ] Verify DragonflyDB using storage (if persistent)
- [ ] Monitor storage usage in Ceph cluster

### AC11 — Documentation & Evidence

**QA Evidence**:
- [ ] PostgreSQL cluster status: `kubectl cnpg status shared-postgres`
- [ ] Replication status: `SELECT * FROM pg_stat_replication;`
- [ ] Pooler connection tests (logs)
- [ ] Backup/restore test results
- [ ] DragonflyDB connection tests (redis-cli output)
- [ ] Performance benchmark results (pgbench, redis-benchmark)
- [ ] Grafana screenshots (database dashboards)

**Dev Notes**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments
- [ ] Known limitations (e.g., backup destination, pooler connection limits)

## Dependencies / Inputs

**Upstream Prerequisites**:
- **Story 46 Complete**: Storage (Rook-Ceph HEALTH_OK), Observability (VictoriaMetrics, VictoriaLogs)
- **Stories 22-24 Complete**: Database manifests committed to git
- **Storage**: Rook-Ceph storage class `rook-ceph-block` available for PostgreSQL PVCs
- **Secrets**: 1Password Connect for database credentials (postgres superuser, application users)

**Tools Required**:
- `kubectl`, `flux`
- `kubectl-cnpg` plugin for CloudNative-PG operations
- `psql` (PostgreSQL client)
- `redis-cli` (Redis client)
- `pgbench` for PostgreSQL benchmarks
- `redis-benchmark` for DragonflyDB benchmarks

**Cluster Access**:
- KUBECONFIG context: `apps`
- Network connectivity to apps cluster

## Tasks / Subtasks

### T0 — Pre-Deployment Validation (NO Cluster Changes)

**Manifest Quality Checks**:
- [ ] Verify database manifests (stories 22-24) committed to git
- [ ] Run `flux build kustomization` for database components:
  ```bash
  flux build kustomization cluster-apps-databases --path kubernetes/workloads/platform/databases
  ```
- [ ] Validate with `kubeconform`:
  ```bash
  kustomize build kubernetes/workloads/platform/databases | kubeconform -summary -strict
  ```

**Prerequisites Validation**:
- [ ] Verify Story 46 complete:
  - Storage: `kubectl --context=apps get sc rook-ceph-block`
  - Observability: `kubectl --context=apps -n observability get pods`
- [ ] Verify backup destination configured (S3 bucket or PVC)
- [ ] Verify 1Password secrets available for database credentials

### T1 — Deploy CloudNative-PG Operator

**Operator Deployment**:
- [ ] Trigger CNPG operator reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-databases-cnpg-operator --with-source
  ```
- [ ] Monitor operator deployment:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg -w
  ```
- [ ] Wait for operator Ready:
  ```bash
  kubectl --context=apps -n cnpg-system rollout status deploy/cnpg-controller-manager
  ```

**Validation**:
- [ ] Verify CRDs installed:
  ```bash
  kubectl --context=apps get crd | grep cnpg.io
  # Should show: clusters.postgresql.cnpg.io, poolers.postgresql.cnpg.io, backups.postgresql.cnpg.io, scheduledbackups.postgresql.cnpg.io
  ```
- [ ] Check operator logs:
  ```bash
  kubectl --context=apps -n cnpg-system logs deploy/cnpg-controller-manager --tail=50
  # Should show no errors
  ```
- [ ] Verify webhook service:
  ```bash
  kubectl --context=apps -n cnpg-system get svc
  # cnpg-webhook-service should exist
  ```

### T2 — Deploy Shared PostgreSQL Cluster

**Cluster Deployment**:
- [ ] Trigger shared cluster reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-databases-cnpg-shared-cluster --with-source
  ```
- [ ] Monitor cluster deployment (may take 5-10 minutes):
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres -w
  ```
- [ ] Wait for 3 replicas Running:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres
  # shared-postgres-1, shared-postgres-2, shared-postgres-3
  ```

**Cluster Health Check**:
- [ ] Check cluster status:
  ```bash
  kubectl --context=apps -n cnpg-system get cluster shared-postgres
  # Status: Cluster in healthy state
  ```
- [ ] Use kubectl-cnpg plugin (if available):
  ```bash
  kubectl cnpg status shared-postgres -n cnpg-system --context=apps
  ```

**Validation**:
- [ ] Capture cluster status output
- [ ] Verify PVCs created and bound:
  ```bash
  kubectl --context=apps -n cnpg-system get pvc -l cnpg.io/cluster=shared-postgres
  # Should show 3 PVCs (one per replica) with status Bound
  ```
- [ ] Check PVC storage class (should be `rook-ceph-block`)

### T3 — Validate PostgreSQL Replication

**Replication Status**:
- [ ] Port-forward to primary pod:
  ```bash
  kubectl --context=apps -n cnpg-system port-forward shared-postgres-1 5432:5432
  ```
- [ ] Connect to primary as postgres user:
  ```bash
  PGPASSWORD=$(kubectl --context=apps -n cnpg-system get secret shared-postgres-superuser -o jsonpath='{.data.password}' | base64 -d) \
    psql -h localhost -U postgres -d postgres
  ```
- [ ] Check replication status:
  ```sql
  SELECT * FROM pg_stat_replication;
  -- Should show 2 standby servers in 'streaming' state
  -- At least 1 should have sync_state='sync' (synchronous replica)
  ```
- [ ] Check replication lag:
  ```sql
  SELECT client_addr, state, sync_state,
         pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) AS send_lag,
         pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn) AS write_lag,
         pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS flush_lag,
         pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replay_lag
  FROM pg_stat_replication;
  -- Lag should be minimal (<1MB)
  ```

**Validation**:
- [ ] Capture replication status output
- [ ] Document lag measurements

### T4 — Test PostgreSQL Failover

**Failover Test**:
- [ ] Identify current primary:
  ```bash
  kubectl --context=apps -n cnpg-system get cluster shared-postgres -o jsonpath='{.status.currentPrimary}'
  # e.g., shared-postgres-1
  ```
- [ ] Delete primary pod (simulate failure):
  ```bash
  kubectl --context=apps -n cnpg-system delete pod shared-postgres-1
  ```
- [ ] Monitor failover (should complete in <30 seconds):
  ```bash
  watch kubectl --context=apps -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres
  ```
- [ ] Verify new primary elected:
  ```bash
  kubectl --context=apps -n cnpg-system get cluster shared-postgres -o jsonpath='{.status.currentPrimary}'
  # Should show different pod (e.g., shared-postgres-2)
  ```
- [ ] Verify old primary recreated as replica:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres
  # shared-postgres-1 should be recreated and running
  ```
- [ ] Connect to new primary and verify cluster healthy:
  ```sql
  SELECT * FROM pg_stat_replication;
  -- Should still show 2 replicas streaming
  ```

**Validation**:
- [ ] Document failover time (pod deletion → new primary ready)
- [ ] Capture cluster status after failover

### T5 — Provision Databases and Users

**Database Provisioning**:
- [ ] Connect to primary as postgres superuser
- [ ] Create databases and users (if not auto-created by CNPG bootstrap):
  ```sql
  -- GitLab database
  CREATE DATABASE gitlabhq_production OWNER gitlab;
  GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;

  -- Harbor database
  CREATE DATABASE registry OWNER harbor;
  GRANT ALL PRIVILEGES ON DATABASE registry TO harbor;

  -- Keycloak database
  CREATE DATABASE keycloak OWNER keycloak;
  GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

  -- SynergyFlow database
  CREATE DATABASE synergyflow OWNER synergyflow;
  GRANT ALL PRIVILEGES ON DATABASE synergyflow TO synergyflow;
  ```
- [ ] Install required extensions:
  ```sql
  -- GitLab extensions
  \c gitlabhq_production
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS btree_gist;
  CREATE EXTENSION IF NOT EXISTS plpgsql;

  -- Harbor extensions
  \c registry
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  ```

**Validation**:
- [ ] List databases:
  ```sql
  \l
  ```
- [ ] Verify each database has correct owner
- [ ] Verify extensions installed:
  ```sql
  \c gitlabhq_production
  \dx
  ```

### T6 — Deploy and Validate PgBouncer Poolers

**Pooler Deployment**:
- [ ] Poolers should be deployed with shared cluster (part of T2)
- [ ] Verify pooler pods Running:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/poolerName
  # Should show: gitlab-pooler-rw, gitlab-pooler-ro, harbor-pooler-rw, keycloak-pooler-rw, synergyflow-pooler-rw
  ```

**Pooler Configuration Validation**:
- [ ] Check pooler specs:
  ```bash
  kubectl --context=apps -n cnpg-system get pooler -o yaml
  ```
- [ ] Verify configuration:
  - gitlab-pooler: transaction mode, max_client_conn=200, default_pool_size=15
  - harbor-pooler: transaction mode, max_client_conn=100, default_pool_size=10
  - keycloak-pooler: session mode (Keycloak requirement), max_client_conn=100
  - synergyflow-pooler: transaction mode

**Connection Testing**:
- [ ] Test GitLab pooler connection:
  ```bash
  kubectl --context=apps run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production -c "SELECT version();"
  ```
- [ ] Test Harbor pooler:
  ```bash
  kubectl --context=apps run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h harbor-pooler-rw.cnpg-system.svc.cluster.local -U harbor -d registry -c "SELECT version();"
  ```
- [ ] Test Keycloak pooler:
  ```bash
  kubectl --context=apps run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h keycloak-pooler-rw.cnpg-system.svc.cluster.local -U keycloak -d keycloak -c "SELECT version();"
  ```
- [ ] Test SynergyFlow pooler:
  ```bash
  kubectl --context=apps run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h synergyflow-pooler-rw.cnpg-system.svc.cluster.local -U synergyflow -d synergyflow -c "SELECT version();"
  ```

**Pooler Admin Console** (optional):
- [ ] Connect to pgbouncer admin console:
  ```bash
  kubectl --context=apps exec -it -n cnpg-system deploy/gitlab-pooler-rw -- psql -p 5432 -U postgres pgbouncer
  pgbouncer=# SHOW POOLS;
  pgbouncer=# SHOW DATABASES;
  pgbouncer=# SHOW STATS;
  ```

**Validation**:
- [ ] Capture pooler connection test outputs
- [ ] Capture SHOW POOLS output

### T7 — Test Pooler Failover

**Failover Test via Pooler**:
- [ ] Connect to database via pooler (keep connection open):
  ```bash
  kubectl --context=apps run -it --rm psql-long --image=postgres:16 --restart=Never -- \
    psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production
  ```
- [ ] In another terminal, delete primary PostgreSQL pod:
  ```bash
  kubectl --context=apps -n cnpg-system delete pod <current-primary>
  ```
- [ ] In psql session, run query after failover:
  ```sql
  SELECT now();
  ```
- [ ] Verify query succeeds (pooler reconnected to new primary automatically)
- [ ] Measure downtime (time between pod deletion and query success)

**Validation**:
- [ ] Document failover downtime via pooler (target: <30 seconds)
- [ ] Verify pooler connection resilience

### T8 — Configure and Test Backups

**Backup Configuration Validation**:
- [ ] Verify ScheduledBackup resource:
  ```bash
  kubectl --context=apps -n cnpg-system get scheduledbackup
  ```
- [ ] Check backup schedule (e.g., daily at 2 AM)
- [ ] Verify backup destination configured (S3 or PVC)

**Manual Backup Test**:
- [ ] Trigger manual backup:
  ```bash
  kubectl cnpg backup shared-postgres -n cnpg-system --backup-name manual-test-backup --context=apps
  ```
- [ ] Monitor backup progress:
  ```bash
  kubectl --context=apps -n cnpg-system get backup manual-test-backup -w
  ```
- [ ] Wait for backup completion:
  ```bash
  kubectl --context=apps -n cnpg-system get backup manual-test-backup
  # Status: completed
  ```
- [ ] Verify backup uploaded to destination:
  - If S3: Check S3 bucket for backup files
  - If PVC: `kubectl --context=apps -n cnpg-system exec shared-postgres-1 -- ls -lh /var/lib/postgresql/backups/`

**Restore Test**:
- [ ] Create test database with sample data:
  ```sql
  CREATE DATABASE test_restore;
  \c test_restore
  CREATE TABLE test_data (id SERIAL PRIMARY KEY, data TEXT);
  INSERT INTO test_data (data) VALUES ('test data 1'), ('test data 2'), ('test data 3');
  SELECT * FROM test_data;
  ```
- [ ] Create backup of test database:
  ```bash
  kubectl cnpg backup shared-postgres -n cnpg-system --backup-name restore-test-backup --context=apps
  ```
- [ ] Drop test database:
  ```sql
  DROP DATABASE test_restore;
  ```
- [ ] Restore from backup (note: CNPG restores create new cluster):
  ```bash
  # This typically involves creating a new Cluster resource with bootstrap.recovery pointing to the backup
  # Refer to CNPG documentation for exact restore procedure
  ```
- [ ] Verify test_data table restored with all rows

**Validation**:
- [ ] Capture backup status
- [ ] Capture backup file listing (S3 or PVC)
- [ ] Document restore procedure and results

### T9 — Deploy DragonflyDB

**DragonflyDB Operator Deployment**:
- [ ] Trigger DragonflyDB operator reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-databases-dragonfly-operator --with-source
  ```
- [ ] Monitor operator deployment:
  ```bash
  kubectl --context=apps -n dragonfly-system get pods -l app=dragonfly-operator -w
  ```

**DragonflyDB Cluster Deployment**:
- [ ] Trigger Dragonfly cluster reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-databases-dragonfly-cluster --with-source
  ```
- [ ] Monitor cluster deployment:
  ```bash
  kubectl --context=apps -n dragonfly-system get pods -l app=dragonfly -w
  ```
- [ ] Wait for all replicas Running (3 expected)

**Validation**:
- [ ] Verify DragonflyDB CRD:
  ```bash
  kubectl --context=apps get crd dragonflyinstances.dragonflydb.io
  ```
- [ ] Verify Dragonfly instance:
  ```bash
  kubectl --context=apps -n dragonfly-system get dragonfly
  # Status should show Ready
  ```

### T10 — Validate DragonflyDB Operations

**Connection Testing**:
- [ ] Connect to DragonflyDB with redis-cli:
  ```bash
  kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-cli
  ```
- [ ] Test PING:
  ```redis
  > PING
  PONG
  ```

**Basic Operations**:
- [ ] Test SET/GET:
  ```redis
  > SET test-key "test-value"
  OK
  > GET test-key
  "test-value"
  ```
- [ ] Test TTL:
  ```redis
  > SET expiring-key "value" EX 10
  OK
  > TTL expiring-key
  (integer) 10
  ```
- [ ] Test data structures:
  ```redis
  > LPUSH test-list "item1" "item2" "item3"
  (integer) 3
  > LRANGE test-list 0 -1
  1) "item3"
  2) "item2"
  3) "item1"

  > SADD test-set "member1" "member2" "member3"
  (integer) 3
  > SMEMBERS test-set

  > HSET test-hash field1 "value1" field2 "value2"
  (integer) 2
  > HGETALL test-hash
  ```

**Persistence Testing**:
- [ ] Write test data:
  ```redis
  > SET persistent-key "this should persist"
  OK
  ```
- [ ] Delete DragonflyDB pod:
  ```bash
  kubectl --context=apps -n dragonfly-system delete pod dragonfly-0
  ```
- [ ] Wait for pod recreation
- [ ] Reconnect and verify data persisted:
  ```redis
  > GET persistent-key
  "this should persist"
  ```

**Validation**:
- [ ] Capture redis-cli command outputs
- [ ] Document persistence test results

### T11 — Database Performance Benchmarks

**PostgreSQL Benchmark (pgbench)**:
- [ ] Initialize pgbench:
  ```bash
  kubectl --context=apps exec -it -n cnpg-system shared-postgres-1 -- pgbench -i -s 10 postgres
  ```
- [ ] Run pgbench benchmark:
  ```bash
  kubectl --context=apps exec -it -n cnpg-system shared-postgres-1 -- pgbench -c 10 -j 2 -t 1000 postgres
  ```
- [ ] Capture output:
  - TPS (transactions per second)
  - Latency (average, p95, p99)
  - Target: >1000 TPS

**DragonflyDB Benchmark (redis-benchmark)**:
- [ ] Run redis-benchmark:
  ```bash
  kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-benchmark -t set,get -n 100000 -q
  ```
- [ ] Capture output:
  - SET operations per second
  - GET operations per second
  - Target: >50,000 ops/sec

**Connection Pool Benchmark**:
- [ ] Run pgbench via pooler:
  ```bash
  kubectl --context=apps run -it --rm pgbench-pooler --image=postgres:16 --restart=Never -- \
    pgbench -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production -c 20 -j 4 -t 500
  ```
- [ ] Compare TPS via pooler vs direct connection
- [ ] Verify pooling reduces connection overhead

**Validation**:
- [ ] Document benchmark results
- [ ] Compare against baseline targets
- [ ] Note any performance issues

### T12 — Database Monitoring Validation

**Metrics Validation**:
- [ ] Port-forward to VictoriaMetrics (infra cluster):
  ```bash
  kubectl --context=infra port-forward -n observability svc/vmselect 8481:8481
  ```
- [ ] Query PostgreSQL metrics:
  ```promql
  # Database size
  pg_database_size_bytes{cluster="apps",datname="gitlabhq_production"}

  # Connections
  pg_stat_database_numbackends{cluster="apps"}

  # Replication lag
  pg_replication_lag{cluster="apps"}

  # PgBouncer metrics
  pgbouncer_pools_cl_active{cluster="apps"}
  pgbouncer_pools_sv_active{cluster="apps"}
  ```
- [ ] Verify all queries return data

**Logs Validation**:
- [ ] Query PostgreSQL logs in VictoriaLogs:
  ```bash
  kubectl --context=infra port-forward -n observability svc/victorialogs 9428:9428
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps",namespace="cnpg-system"}'
  ```
- [ ] Query for SQL statements:
  ```bash
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps",namespace="cnpg-system"} |= "statement"'
  ```

**Grafana Dashboard**:
- [ ] In Grafana (infra cluster), create or import CNPG dashboard
- [ ] Verify metrics visible for shared-postgres cluster
- [ ] Take screenshots

**Validation**:
- [ ] Capture metrics query results
- [ ] Capture logs query results
- [ ] Screenshot Grafana dashboard

### T13 — Integration Testing

**Test Application Deployment**:
- [ ] Deploy test web application with PostgreSQL backend:
  ```bash
  kubectl --context=apps apply -f - <<EOF
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: test-app-db
    namespace: default
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: test-app-db
    template:
      metadata:
        labels:
          app: test-app-db
      spec:
        containers:
          - name: app
            image: postgres:16
            env:
              - name: PGHOST
                value: gitlab-pooler-rw.cnpg-system.svc.cluster.local
              - name: PGUSER
                value: gitlab
              - name: PGDATABASE
                value: gitlabhq_production
              - name: PGPASSWORD
                valueFrom:
                  secretKeyRef:
                    name: gitlab-db-secret
                    key: password
            command:
              - sh
              - -c
              - |
                while true; do
                  psql -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, data TEXT, created_at TIMESTAMP DEFAULT NOW());"
                  psql -c "INSERT INTO test_table (data) VALUES ('test data $(date)');"
                  psql -c "SELECT COUNT(*) FROM test_table;"
                  sleep 60
                done
  EOF
  ```
- [ ] Monitor test app:
  ```bash
  kubectl --context=apps logs -f deploy/test-app-db
  ```
- [ ] Verify app successfully connects to PostgreSQL and inserts data

**Test Cache Application**:
- [ ] Deploy test app with DragonflyDB caching:
  ```bash
  kubectl --context=apps apply -f - <<EOF
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: test-app-cache
    namespace: default
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: test-app-cache
    template:
      metadata:
        labels:
          app: test-app-cache
      spec:
        containers:
          - name: app
            image: redis:7
            command:
              - sh
              - -c
              - |
                while true; do
                  redis-cli -h dragonfly.dragonfly-system.svc.cluster.local SET cache-key "cached-value-$(date +%s)"
                  redis-cli -h dragonfly.dragonfly-system.svc.cluster.local GET cache-key
                  sleep 30
                done
  EOF
  ```
- [ ] Monitor test app:
  ```bash
  kubectl --context=apps logs -f deploy/test-app-cache
  ```
- [ ] Verify app successfully connects to DragonflyDB

**Storage Integration**:
- [ ] Verify PostgreSQL PVCs using Rook-Ceph:
  ```bash
  kubectl --context=apps -n cnpg-system get pvc -l cnpg.io/cluster=shared-postgres -o jsonpath='{.items[*].spec.storageClassName}'
  # Should show: rook-ceph-block
  ```
- [ ] Check Ceph pool usage:
  ```bash
  kubectl --context=apps -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
  # Should show storage used by PostgreSQL PVCs
  ```

**Validation**:
- [ ] Capture test app logs
- [ ] Verify data persistence in PostgreSQL
- [ ] Verify cache operations in DragonflyDB

### T14 — Documentation & Evidence Collection

**QA Evidence Artifacts**:
- [ ] Database validation:
  - `docs/qa/evidence/VALIDATE-DB-cnpg-cluster-status.txt`
  - `docs/qa/evidence/VALIDATE-DB-replication-status.txt`
  - `docs/qa/evidence/VALIDATE-DB-pooler-connections.txt`
  - `docs/qa/evidence/VALIDATE-DB-backup-restore.txt`
  - `docs/qa/evidence/VALIDATE-DB-dragonfly-operations.txt`
  - `docs/qa/evidence/VALIDATE-DB-performance-benchmarks.txt`

- [ ] Screenshots:
  - Grafana PostgreSQL dashboard
  - Grafana DragonflyDB metrics (if available)
  - CNPG cluster status (kubectl output)
  - Backup status (S3 bucket or PVC listing)

**Dev Notes Documentation**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments (pooler connection limits, backup schedule)
- [ ] Known limitations (backup destination, database sizes, connection limits)
- [ ] Recommendations for application deployment (Story 48)

**Architecture/PRD Updates**:
- [ ] Update architecture.md with PostgreSQL cluster topology
- [ ] Document pooler configuration and connection limits
- [ ] Document backup/restore procedures
- [ ] Note database performance baselines in PRD

## Validation Steps

### Pre-Deployment Validation (NO Cluster)
```bash
# Validate manifests can build
flux build kustomization cluster-apps-databases --path kubernetes/workloads/platform/databases

# Schema validation
kustomize build kubernetes/workloads/platform/databases | kubeconform -summary -strict
```

### Runtime Validation Commands (Summary)

**PostgreSQL Validation**:
```bash
# Cluster status
kubectl --context=apps -n cnpg-system get cluster shared-postgres
kubectl cnpg status shared-postgres -n cnpg-system --context=apps

# Replication status
kubectl --context=apps -n cnpg-system port-forward shared-postgres-1 5432:5432
psql -h localhost -U postgres -c "SELECT * FROM pg_stat_replication;"

# Pooler connection test
kubectl --context=apps run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production -c "SELECT version();"

# Backup test
kubectl cnpg backup shared-postgres -n cnpg-system --backup-name test-backup --context=apps
```

**DragonflyDB Validation**:
```bash
# Connection test
kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-cli PING

# Basic operations
kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-cli SET test "value"
kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-cli GET test
```

**Performance Benchmarks**:
```bash
# PostgreSQL
kubectl --context=apps exec -it -n cnpg-system shared-postgres-1 -- pgbench -c 10 -j 2 -t 1000 postgres

# DragonflyDB
kubectl --context=apps exec -it -n dragonfly-system dragonfly-0 -- redis-benchmark -t set,get -n 100000 -q
```

## Rollback Procedures

**PostgreSQL Rollback** (HIGH RISK - data loss possible):
```bash
# Suspend cluster (preserve data)
flux --context=apps suspend kustomization apps-databases-cnpg-shared-cluster

# Delete cluster (DESTRUCTIVE - will delete PVCs!)
kubectl --context=apps -n cnpg-system delete cluster shared-postgres

# Re-deploy with fixes
flux --context=apps resume kustomization apps-databases-cnpg-shared-cluster --with-source
```

**DragonflyDB Rollback**:
```bash
# Suspend DragonflyDB
flux --context=apps suspend kustomization apps-databases-dragonfly-cluster

# Delete instance
kubectl --context=apps -n dragonfly-system delete dragonfly <instance-name>

# Re-deploy with fixes
flux --context=apps resume kustomization apps-databases-dragonfly-cluster --with-source
```

## Risks / Mitigations

**Database Risks**:

**R1 — PostgreSQL Cluster Initialization Failure** (Prob=Medium, Impact=High):
- Risk: CNPG cluster fails to initialize (pod crashloop, replication issues)
- Mitigation: Pre-validate storage class available, check operator logs, verify PVC provisioning
- Recovery: Delete cluster CR, fix configuration, re-apply; or restore from backup if cluster was previously healthy

**R2 — Replication Lag** (Prob=Low, Impact=Medium):
- Risk: Standby replicas fall behind primary (network issues, disk I/O bottleneck)
- Mitigation: Monitor `pg_stat_replication`, verify Ceph storage performance, check network latency
- Recovery: Investigate bottleneck (storage, network, CPU); tune PostgreSQL parameters; add more replicas if needed

**R3 — Backup/Restore Failures** (Prob=Medium, Impact=High):
- Risk: Backups fail to upload to S3, or restores fail
- Mitigation: Validate S3 credentials, test backup destination access, verify retention policy
- Recovery: Fix S3 credentials; verify backup files exist; re-run backup; test restore in isolated cluster

**R4 — Pooler Connection Issues** (Prob=Medium, Impact=High):
- Risk: PgBouncer cannot connect to PostgreSQL, applications fail to connect via pooler
- Mitigation: Validate pooler configuration (mode, connection limits), test direct connection first
- Recovery: Check pooler logs; verify PostgreSQL service endpoint; adjust pooler parameters; restart pooler pods

**R5 — DragonflyDB Data Loss** (Prob=Low, Impact=Medium):
- Risk: DragonflyDB loses data after restart (persistence not configured)
- Mitigation: Verify persistence enabled (RDB or AOF), test persistence before production use
- Recovery: Enable persistence in DragonflyDB configuration; accept data loss for cache use case

**R6 — Database Performance Below Baseline** (Prob=Low, Impact=Medium):
- Risk: PostgreSQL or DragonflyDB performance worse than expected (TPS, latency)
- Mitigation: Run benchmarks early (pgbench, redis-benchmark), monitor resource usage, verify Ceph storage performance
- Recovery: Tune database parameters; scale up resources (CPU, memory); optimize queries; check storage IOPS

## Definition of Done

**All Acceptance Criteria Met**:
- [ ] AC1: CloudNative-PG operator operational
- [ ] AC2: Shared PostgreSQL cluster healthy (3 replicas, synchronous replication)
- [ ] AC3: Databases provisioned for all tenants
- [ ] AC4: PgBouncer poolers operational
- [ ] AC5: PostgreSQL backups configured and tested
- [ ] AC6: DragonflyDB operator operational
- [ ] AC7: DragonflyDB cluster operational
- [ ] AC8: Database performance baselines established
- [ ] AC9: Database monitoring integrated
- [ ] AC10: Integration testing passed
- [ ] AC11: Documentation & evidence complete

**QA Gate**:
- [ ] QA evidence artifacts collected and reviewed
- [ ] Risk assessment updated with deployment findings
- [ ] Test design execution complete (all P0 tests passing)
- [ ] QA gate decision: PASS (or waivers documented)

**PO Acceptance**:
- [ ] PostgreSQL cluster healthy and accepting connections
- [ ] Backups configured and restore tested
- [ ] Poolers operational for all applications
- [ ] DragonflyDB operational for caching
- [ ] Performance baselines acceptable
- [ ] Ready for application deployment (Story 48: GitLab, Harbor, CI/CD)

**Handoff to Story 48**:
- [ ] Database infrastructure ready for applications
- [ ] Pooler endpoints documented for application configuration
- [ ] Database credentials available in 1Password/ExternalSecrets
- [ ] Monitoring configured for database health

## Architect Handoff

**Architecture (docs/architecture.md)**:
- Validate multi-tenant database architecture matches deployment
- Document PostgreSQL cluster topology (primary, replicas, poolers)
- Document backup/restore strategy (S3 destination, retention, RPO/RTO)
- Update DragonflyDB integration details

**PRD (docs/prd.md)**:
- Confirm database NFRs met (connection pooling, failover <30s, backup RPO 24h)
- Document performance baselines (TPS, latency, ops/sec)
- Note database resource sizing (CPU, memory, storage)
- Document connection limits and scaling strategy

**Runbooks**:
- Create `docs/runbooks/postgresql-operations.md` for CNPG management
- Create `docs/runbooks/database-backup-restore.md` for backup/restore procedures
- Document database troubleshooting procedures (replication lag, connection issues)

## Change Log

| Date       | Version | Description                              | Author  |
|------------|---------|------------------------------------------|---------|
| 2025-10-26 | 0.1     | Initial validation story creation (draft)| Winston |
| 2025-10-26 | 1.0     | **v3.0 Refinement**: Database deployment/validation story. Added 14 tasks (T0-T14) covering CloudNative-PG (operator, cluster, poolers, backups) and DragonflyDB. Created 11 acceptance criteria with detailed validation. Added replication testing, failover testing, backup/restore validation, performance benchmarks, QA artifacts. | Winston |

## Dev Agent Record

### Agent Model Used
<to be filled by dev>

### Debug Log References
<to be filled by dev>

### Completion Notes List
<to be filled by dev>

### File List
<to be filled by dev>

## QA Results — Risk Profile

**Reviewer**: Quinn (Test Architect & Quality Advisor)

**Summary**:
- Total Risks Identified: 6
- Critical: 0 | High: 3 | Medium: 3 | Low: 0
- Overall Story Risk Score: 58/100 (Medium-High)

**Top Risks**:
1. **R1 — PostgreSQL Cluster Initialization Failure** (High): Cluster fails to initialize
2. **R3 — Backup/Restore Failures** (High): Backups fail or restores don't work
3. **R4 — Pooler Connection Issues** (High): Applications cannot connect via poolers
4. **R2 — Replication Lag** (Medium): Standby replicas fall behind primary

**Mitigations**:
- All risks have documented mitigation and recovery procedures
- Pre-validation of storage and credentials before deployment
- Phased deployment allows early failure detection
- Backup/restore testing before production use

**Risk-Based Testing Focus**:
- Priority 1: PostgreSQL cluster health, replication, pooler connections, backups
- Priority 2: DragonflyDB operations, failover testing
- Priority 3: Performance benchmarks, monitoring integration

**Artifacts**:
- Full assessment: `docs/qa/assessments/STORY-VALIDATE-DATABASES-SECURITY-risk-20251026.md` (to be created)

## QA Results — Test Design

**Designer**: Quinn (Test Architect)

**Test Strategy Overview**:
- **Emphasis**: Database reliability, data integrity, failover resilience
- **Approach**: Component deployment → functional testing → failover testing → performance validation → integration
- **Coverage**: All 11 acceptance criteria mapped to test cases
- **Priority Distribution**: P0 (cluster health, replication, backups), P1 (poolers, failover), P2 (performance, monitoring)

**Test Environments**:
- **Apps Cluster**: 3 control plane nodes with Rook-Ceph storage

**Test Phases**:

**Phase 1: Pre-Deployment Validation** (T0):
- Manifest build validation
- Storage and secrets readiness
- Story 46 completion check

**Phase 2: Database Deployment** (T1-T2):
- CNPG operator deployment
- Shared PostgreSQL cluster deployment (3 replicas)
- Database and user provisioning

**Phase 3: PostgreSQL Validation** (T3-T5):
- Replication status validation
- Failover testing
- Database provisioning and extensions

**Phase 4: Pooler Validation** (T6-T7):
- Pooler deployment and configuration
- Connection testing via poolers
- Pooler failover testing

**Phase 5: Backup/Restore Validation** (T8):
- Backup configuration verification
- Manual backup execution
- Restore testing with data integrity check

**Phase 6: DragonflyDB Deployment & Validation** (T9-T10):
- Operator and cluster deployment
- Connection and operations testing
- Persistence testing

**Phase 7: Performance & Monitoring** (T11-T12):
- PostgreSQL benchmarks (pgbench)
- DragonflyDB benchmarks (redis-benchmark)
- Metrics and logs validation

**Phase 8: Integration & Evidence** (T13-T14):
- Test application with database integration
- Storage integration validation
- Evidence collection

**Test Cases** (High-Level Summary):

**P0 Tests (Critical Path)** (~15 tests):
- PostgreSQL cluster healthy (3 replicas)
- Replication streaming (synchronous replica)
- Pooler connections successful
- Backup creation successful
- Restore with data integrity verified
- DragonflyDB connection successful

**P1 Tests (Core Functionality)** (~20 tests):
- Failover completes in <30 seconds
- Pooler reconnects after failover
- Databases provisioned for all tenants
- Extensions installed correctly
- Persistence validated (DragonflyDB)
- Metrics scraped by VictoriaMetrics

**P2 Tests (Performance & Integration)** (~10 tests):
- PostgreSQL TPS >1000
- DragonflyDB ops/sec >50,000
- Replication lag <1MB
- Monitoring dashboards functional
- Test application integration

**Total Test Cases**: ~45 tests

**Traceability** (Acceptance Criteria → Test Coverage):
- AC1 (CNPG operator) → T1 tests
- AC2 (PostgreSQL cluster) → T2, T3, T4 tests
- AC3 (Database provisioning) → T5 tests
- AC4 (Poolers) → T6, T7 tests
- AC5 (Backups) → T8 tests
- AC6 (Dragonfly operator) → T9 tests
- AC7 (Dragonfly cluster) → T10 tests
- AC8 (Performance) → T11 tests
- AC9 (Monitoring) → T12 tests
- AC10 (Integration) → T13 tests
- AC11 (Documentation) → T14 tasks

**Go/No-Go Criteria**:
- **GO**: All P0 tests pass, PostgreSQL cluster healthy, backups working, poolers operational, P1 tests >90% pass
- **NO-GO**: PostgreSQL cluster unhealthy, backups failing, pooler connections broken, critical risks not mitigated

**Artifacts**:
- Full test design: `docs/qa/assessments/STORY-VALIDATE-DATABASES-SECURITY-test-design-20251026.md` (to be created)
- Test execution results: `docs/qa/evidence/VALIDATE-DB-*.txt`

## *** End of Story ***
