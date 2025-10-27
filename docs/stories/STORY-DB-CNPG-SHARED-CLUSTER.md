# 24 — STORY-DB-CNPG-SHARED-CLUSTER — Create Shared PostgreSQL Cluster Manifests

Sequence: 24/50 | Prev: STORY-DB-CNPG-OPERATOR.md | Next: STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md
Sprint: 5 | Lane: Database
Global Sequence: 24/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
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
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/harbor-pooler-pdb.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/keycloak-pooler-pdb.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/gitlab-pooler-pdb.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/poolers/synergyflow-pooler-pdb.yaml
- kubernetes/workloads/platform/databases/cloudnative-pg/kustomization.yaml

## Story
As a platform engineer, I want to **create manifests for a shared CloudNativePG PostgreSQL cluster** with scheduled backups, monitoring, and PgBouncer poolers for multi-tenant platform applications, so that when deployed in Story 45 the infra cluster provides a consolidated, production-ready database service with operational guardrails for Harbor, GitLab, Keycloak, and SynergyFlow.

## Why / Outcome
- **Consolidated Database Service**: Single highly-available PostgreSQL cluster serving multiple platform applications
- **Operational Excellence**: Automated backups, monitoring, alerting, and connection pooling
- **Security and Isolation**: Per-application database credentials, TLS encryption, PSA restricted enforcement
- **Cost Efficiency**: Shared infrastructure reduces resource overhead vs. per-app clusters
- **GitOps Managed**: All database configuration declared in manifests and version controlled

## Scope

### This Story (Manifest Creation)
Create all manifests for the shared PostgreSQL cluster infrastructure on the infra cluster:
1. **Cluster Manifest**: CloudNativePG Cluster resource with 3 instances, synchronous replication, TLS, and storage configuration
2. **Backup Configuration**: ScheduledBackup resource with S3 backend, six-field cron schedule (02:00 UTC), compression, and encryption
3. **External Secrets**: Superuser credentials, S3/MinIO credentials, per-application database credentials, and pooler authentication secrets
4. **PgBouncer Poolers**: Four pooler deployments (Harbor, GitLab, Keycloak, SynergyFlow) with appropriate pooling modes, replica counts, and anti-affinity
5. **PodDisruptionBudgets**: For each pooler to ensure high availability during rolling updates
6. **Monitoring**: PodMonitors for cluster and poolers, PrometheusRules for alerting on backup/replication/pooler issues
7. **Backup Validation**: CronJob using non-root image to verify backup integrity
8. **Database CRs**: Declarative database provisioning for each application (harbor, keycloak, gitlab, synergyflow)
9. **Kustomization**: Tie all resources together with proper ordering and health checks

**Validation**: Local-only using `kubectl --dry-run=client`, `flux build`, `kustomize build`, and `kubeconform`

### Deferred to Story 45 (Deployment & Validation)
- Apply manifests to infra cluster
- Verify Cluster readiness and primary election
- Validate scheduled backup execution and S3 storage
- Test pooler connectivity and metrics scraping
- Verify TLS encryption client→pooler→Postgres
- Validate database provisioning and application access
- Monitor backup validation CronJob execution
- Integration testing across all applications

## Acceptance Criteria

### Manifest Creation (This Story)
1. **AC1-Cluster**: `Cluster` manifest with 3 instances, synchronous replication (`minSyncReplicas: 1`, `maxSyncReplicas: 2`), storage configuration using `${CNPG_STORAGE_CLASS}`, `${CNPG_DATA_SIZE}`, `${CNPG_WAL_SIZE}`, TLS enabled, PostgreSQL version from `${CNPG_POSTGRES_VERSION}`
2. **AC2-Backup**: `ScheduledBackup` manifest with six-field cron (`"0 0 2 * * *"`), S3 backend using `${CNPG_BACKUP_BUCKET}`, `${CNPG_MINIO_ENDPOINT_URL}`, compression enabled, server-side encryption (`sse: AES256`)
3. **AC3-ExternalSecrets**: ExternalSecret manifests for `cnpg-superuser`, `cnpg-minio-credentials`, per-app credentials (harbor, keycloak, gitlab, synergyflow), and pooler auth secrets, all referencing `${EXTERNAL_SECRET_STORE}` and appropriate 1Password paths
4. **AC4-Poolers**: Four Pooler manifests (harbor, gitlab, keycloak, synergyflow) with correct pooling mode (transaction for Harbor/GitLab/SynergyFlow, session for Keycloak), ≥3 replicas, anti-affinity, monitoring enabled, tuned connection parameters
5. **AC5-PDBs**: PodDisruptionBudget for each pooler with `maxUnavailable: 1` to ensure availability during rolling updates
6. **AC6-Monitoring**: PodMonitor for cluster and poolers, PrometheusRule/VMRule with alerts for backup failures, replication lag, pooler connection exhaustion, and cluster health
7. **AC7-BackupValidation**: Backup validation CronJob using non-root image (minio/mc or aws-cli), no privileged escalation, scheduled to run after backups complete
8. **AC8-DatabaseCRs**: Database CRs for harbor, keycloak, gitlab, synergyflow with proper ownership via `managed.roles`
9. **AC9-Kustomization**: Flux Kustomization manifest with health checks for Cluster, ScheduledBackup, Poolers, and proper dependency on CNPG operator kustomization
10. **AC10-Validation**: All manifests pass local validation: `kubectl --dry-run=client`, `flux build`, `kustomize build`, `kubeconform`

### Deferred to Story 45 (NOT Part of This Story)
- ~~Cluster pods Running and Ready~~
- ~~Primary instance elected~~
- ~~Scheduled backup execution and S3 storage verification~~
- ~~Pooler Services resolvable~~
- ~~Metrics scraping operational~~
- ~~TLS encryption verified~~
- ~~Application connectivity testing~~

## Dependencies / Inputs

### Prerequisites
- **STORY-DB-CNPG-OPERATOR**: CNPG operator deployed and healthy (provides Cluster, Pooler, Database CRDs)
- **StorageClass**: `${CNPG_STORAGE_CLASS}` (typically `${BLOCK_SC}` for Rook-Ceph)
- **S3 Backend**: MinIO or external S3 for backup storage
- **1Password Secrets**: Paths configured for superuser, MinIO, and per-app credentials
- **Cluster Settings**: All required variables defined in cluster-settings ConfigMap

### Local Tools Required
- `kubectl` - Kubernetes manifest validation
- `flux` - GitOps manifest validation
- `kustomize` - Kustomization building
- `kubeconform` - Kubernetes schema validation
- `yq` - YAML processing
- `git` - Version control

### Cluster Settings Variables
From `kubernetes/clusters/infra/cluster-settings.yaml`:
```yaml
# CNPG Cluster Configuration
CNPG_POSTGRES_VERSION: "17.4"
CNPG_INSTANCES: "3"
CNPG_STORAGE_CLASS: "${BLOCK_SC}"  # rook-ceph-block
CNPG_DATA_SIZE: "20Gi"
CNPG_WAL_SIZE: "5Gi"
CNPG_MIN_SYNC_REPLICAS: "1"
CNPG_MAX_SYNC_REPLICAS: "2"

# Backup Configuration
CNPG_BACKUP_SCHEDULE: "0 0 2 * * *"  # Six-field: 02:00 UTC
CNPG_BACKUP_BUCKET: "cnpg-backups"
CNPG_MINIO_ENDPOINT_URL: "http://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local"
CNPG_BACKUP_RETENTION: "30d"

# Pooler Configuration
CNPG_POOLER_REPLICAS: "3"

# External Secret Paths (1Password)
EXTERNAL_SECRET_STORE: "onepassword"
CNPG_SUPERUSER_SECRET_PATH: "kubernetes/infra/cloudnative-pg/superuser"
CNPG_MINIO_SECRET_PATH: "kubernetes/infra/cloudnative-pg/minio"
CNPG_HARBOR_SECRET_PATH: "kubernetes/infra/cloudnative-pg/harbor"
CNPG_KEYCLOAK_SECRET_PATH: "kubernetes/infra/cloudnative-pg/keycloak"
CNPG_GITLAB_SECRET_PATH: "kubernetes/infra/cloudnative-pg/gitlab"
CNPG_SYNERGYFLOW_SECRET_PATH: "kubernetes/infra/cloudnative-pg/synergyflow"
```

## Tasks / Subtasks

### T1: Verify Prerequisites and Configuration Strategy
- [ ] Review STORY-DB-CNPG-OPERATOR completion (operator and CRDs available)
- [ ] Confirm cluster-settings variables for CNPG cluster, backup, and pooler configuration
- [ ] Verify 1Password secret paths for superuser, MinIO, and per-app credentials
- [ ] Review CNPG Cluster API for version alignment (target 0.26.x operator)
- [ ] Confirm namespace strategy (cnpg-system vs. dedicated databases namespace)
- [ ] Document six-field cron format requirement for ScheduledBackup

### T2: Create Namespace and Base Configuration
- [ ] Create or verify `cnpg-system` namespace (or `databases` if separating data plane)
- [ ] Ensure PSA labels: `pod-security.kubernetes.io/enforce: restricted`
- [ ] Document Service DNS patterns: `shared-postgres-rw.cnpg-system.svc.cluster.local`, `shared-postgres-ro.cnpg-system.svc.cluster.local`

### T3: Create ExternalSecret Manifests
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/externalsecrets.yaml`

Create ExternalSecrets for:
1. **cnpg-superuser**: PostgreSQL superuser credentials (username, password)
2. **cnpg-minio-credentials**: S3/MinIO access (ACCESS_KEY_ID, SECRET_ACCESS_KEY)
3. **harbor-db-credentials**: Harbor database credentials (username, password, database)
4. **keycloak-db-credentials**: Keycloak database credentials (username, password, database)
5. **gitlab-db-credentials**: GitLab database credentials (username, password, database)
6. **synergyflow-db-credentials**: SynergyFlow database credentials (username, password, database)
7. **harbor-pooler-auth**, **keycloak-pooler-auth**, **gitlab-pooler-auth**, **synergyflow-pooler-auth**: Pooler authentication secrets

All using `${EXTERNAL_SECRET_STORE}` and appropriate secret paths.

### T4: Create Cluster Manifest
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: shared-postgres
  namespace: cnpg-system
spec:
  instances: ${CNPG_INSTANCES}  # 3
  imageName: ghcr.io/cloudnative-pg/postgresql:${CNPG_POSTGRES_VERSION}

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "2621kB"
      huge_pages: "off"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      max_worker_processes: "4"
      max_parallel_workers_per_gather: "2"
      max_parallel_workers: "4"
      max_parallel_maintenance_workers: "2"

    # TLS configuration
    sslMode: verify-full
    sslRootCert:
      name: shared-postgres-ca
      key: ca.crt
    sslCert:
      name: shared-postgres-server
      key: tls.crt
    sslKey:
      name: shared-postgres-server
      key: tls.key

  # Synchronous replication for data durability
  minSyncReplicas: ${CNPG_MIN_SYNC_REPLICAS}  # 1
  maxSyncReplicas: ${CNPG_MAX_SYNC_REPLICAS}  # 2

  # Storage configuration
  storage:
    storageClass: ${CNPG_STORAGE_CLASS}
    size: ${CNPG_DATA_SIZE}  # 20Gi

  walStorage:
    storageClass: ${CNPG_STORAGE_CLASS}
    size: ${CNPG_WAL_SIZE}  # 5Gi

  # Superuser access (use sparingly, prefer Database CRs)
  enableSuperuserAccess: true
  superuserSecret:
    name: cnpg-superuser

  # Managed roles for applications (declarative)
  managed:
    roles:
      - name: harbor
        ensure: present
        login: true
        superuser: false
        createdb: false
        createrole: false
        inherit: true
        replication: false
        passwordSecret:
          name: harbor-db-credentials
      - name: keycloak
        ensure: present
        login: true
        superuser: false
        createdb: false
        createrole: false
        inherit: true
        replication: false
        passwordSecret:
          name: keycloak-db-credentials
      - name: gitlab
        ensure: present
        login: true
        superuser: false
        createdb: false
        createrole: false
        inherit: true
        replication: false
        passwordSecret:
          name: gitlab-db-credentials
      - name: synergyflow
        ensure: present
        login: true
        superuser: false
        createdb: false
        createrole: false
        inherit: true
        replication: false
        passwordSecret:
          name: synergyflow-db-credentials

  # Backup configuration
  backup:
    barmanObjectStore:
      destinationPath: s3://${CNPG_BACKUP_BUCKET}/shared-postgres
      endpointURL: ${CNPG_MINIO_ENDPOINT_URL}
      s3Credentials:
        accessKeyId:
          name: cnpg-minio-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: cnpg-minio-credentials
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
        encryption: AES256
      data:
        compression: gzip
        encryption: AES256
        immediateCheckpoint: true
        jobs: 2
    retentionPolicy: ${CNPG_BACKUP_RETENTION}  # 30d

  # Monitoring
  monitoring:
    enablePodMonitor: true

  # High availability
  affinity:
    enablePodAntiAffinity: true
    topologyKey: kubernetes.io/hostname
    podAntiAffinityType: preferred

  # Resource limits
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "2000m"

  # Bootstrap (for new cluster)
  bootstrap:
    initdb:
      database: postgres
      owner: postgres
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
        - CREATE EXTENSION IF NOT EXISTS pg_trgm;
        - CREATE EXTENSION IF NOT EXISTS btree_gist;
        - CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        - CREATE EXTENSION IF NOT EXISTS plpgsql;
        - CREATE EXTENSION IF NOT EXISTS amcheck;
```

### T5: Create ScheduledBackup Manifest
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/scheduledbackup.yaml`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: shared-postgres-backup
  namespace: cnpg-system
spec:
  # Six-field cron: seconds minutes hours day month weekday
  schedule: ${CNPG_BACKUP_SCHEDULE}  # "0 0 2 * * *" = 02:00 UTC daily

  backupOwnerReference: self

  cluster:
    name: shared-postgres

  immediate: false

  # Backup method (physical backup)
  method: barmanObjectStore

  # Target (primary or prefer-standby)
  target: prefer-standby
```

### T6: Create Database CRs (Declarative Provisioning)
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/databases.yaml`

```yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: harbor
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  name: harbor
  owner: harbor
  extensions:
    - uuid-ossp
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: keycloak
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  name: keycloak
  owner: keycloak
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: gitlab
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  name: gitlab
  owner: gitlab
  extensions:
    - pg_trgm
    - btree_gist
    - plpgsql
    - amcheck
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: synergyflow
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  name: synergyflow
  owner: synergyflow
```

### T7: Create PgBouncer Pooler Manifests
**Files**: `kubernetes/workloads/platform/databases/cloudnative-pg/poolers/{harbor,keycloak,gitlab,synergyflow}-pooler.yaml`

**Harbor Pooler** (transaction mode):
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: harbor-pooler
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres

  instances: ${CNPG_POOLER_REPLICAS}  # 3

  type: rw

  pgbouncer:
    poolMode: transaction

    parameters:
      max_client_conn: "200"
      default_pool_size: "15"
      min_pool_size: "5"
      reserve_pool_size: "5"
      max_db_connections: "0"
      max_user_connections: "0"
      server_reset_query: "DISCARD ALL"
      server_check_delay: "30"
      server_connect_timeout: "15"
      server_login_retry: "15"
      query_timeout: "0"
      query_wait_timeout: "120"
      client_idle_timeout: "0"
      idle_transaction_timeout: "0"
      server_idle_timeout: "600"
      server_lifetime: "3600"
      server_round_robin: "0"
      ignore_startup_parameters: "extra_float_digits,options"
      application_name_add_host: "1"
      stats_period: "60"

  monitoring:
    enablePodMonitor: true

  template:
    metadata:
      labels:
        app: harbor
        component: pooler

    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    cnpg.io/poolerName: harbor-pooler
                topologyKey: kubernetes.io/hostname

      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

**Keycloak Pooler** (session mode):
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: keycloak-pooler
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres

  instances: ${CNPG_POOLER_REPLICAS}  # 3

  type: rw

  pgbouncer:
    poolMode: session  # Session mode for Keycloak (uses session state)

    parameters:
      max_client_conn: "200"
      default_pool_size: "20"
      min_pool_size: "10"
      reserve_pool_size: "5"
      max_db_connections: "0"
      max_user_connections: "0"
      server_reset_query: ""  # Empty for session mode
      server_check_delay: "30"
      server_connect_timeout: "15"
      server_login_retry: "15"
      query_timeout: "0"
      query_wait_timeout: "120"
      client_idle_timeout: "0"
      idle_transaction_timeout: "0"
      server_idle_timeout: "600"
      server_lifetime: "3600"
      server_round_robin: "0"
      ignore_startup_parameters: "extra_float_digits,options"
      application_name_add_host: "1"
      stats_period: "60"

  monitoring:
    enablePodMonitor: true

  template:
    metadata:
      labels:
        app: keycloak
        component: pooler

    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    cnpg.io/poolerName: keycloak-pooler
                topologyKey: kubernetes.io/hostname

      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

**GitLab Pooler** (transaction mode):
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: gitlab-pooler
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres

  instances: ${CNPG_POOLER_REPLICAS}  # 3

  type: rw

  pgbouncer:
    poolMode: transaction

    parameters:
      max_client_conn: "300"
      default_pool_size: "25"
      min_pool_size: "10"
      reserve_pool_size: "10"
      max_db_connections: "0"
      max_user_connections: "0"
      server_reset_query: "DISCARD ALL"
      server_check_delay: "30"
      server_connect_timeout: "15"
      server_login_retry: "15"
      query_timeout: "0"
      query_wait_timeout: "120"
      client_idle_timeout: "0"
      idle_transaction_timeout: "0"
      server_idle_timeout: "600"
      server_lifetime: "3600"
      server_round_robin: "0"
      ignore_startup_parameters: "extra_float_digits,options"
      application_name_add_host: "1"
      stats_period: "60"

  monitoring:
    enablePodMonitor: true

  template:
    metadata:
      labels:
        app: gitlab
        component: pooler

    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    cnpg.io/poolerName: gitlab-pooler
                topologyKey: kubernetes.io/hostname

      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

**SynergyFlow Pooler** (transaction mode):
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: synergyflow-pooler
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres

  instances: ${CNPG_POOLER_REPLICAS}  # 3

  type: rw

  pgbouncer:
    poolMode: transaction

    parameters:
      max_client_conn: "150"
      default_pool_size: "10"
      min_pool_size: "5"
      reserve_pool_size: "5"
      max_db_connections: "0"
      max_user_connections: "0"
      server_reset_query: "DISCARD ALL"
      server_check_delay: "30"
      server_connect_timeout: "15"
      server_login_retry: "15"
      query_timeout: "0"
      query_wait_timeout: "120"
      client_idle_timeout: "0"
      idle_transaction_timeout: "0"
      server_idle_timeout: "600"
      server_lifetime: "3600"
      server_round_robin: "0"
      ignore_startup_parameters: "extra_float_digits,options"
      application_name_add_host: "1"
      stats_period: "60"

  monitoring:
    enablePodMonitor: true

  template:
    metadata:
      labels:
        app: synergyflow
        component: pooler

    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    cnpg.io/poolerName: synergyflow-pooler
                topologyKey: kubernetes.io/hostname

      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

### T8: Create PodDisruptionBudgets for Poolers
**Files**: `kubernetes/workloads/platform/databases/cloudnative-pg/poolers/{harbor,keycloak,gitlab,synergyflow}-pooler-pdb.yaml`

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: harbor-pooler
  namespace: cnpg-system
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      cnpg.io/poolerName: harbor-pooler
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: keycloak-pooler
  namespace: cnpg-system
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      cnpg.io/poolerName: keycloak-pooler
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: gitlab-pooler
  namespace: cnpg-system
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      cnpg.io/poolerName: gitlab-pooler
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: synergyflow-pooler
  namespace: cnpg-system
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      cnpg.io/poolerName: synergyflow-pooler
```

### T9: Create PrometheusRule for Cluster and Pooler Monitoring
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/prometheusrule.yaml`

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: cloudnative-pg-cluster
  namespace: cnpg-system
spec:
  groups:
    - name: cloudnativepg.cluster
      interval: 30s
      rules:
        # Cluster Health Alerts
        - alert: CNPGClusterNotReady
          expr: cnpg_pg_cluster_ready{cluster="shared-postgres"} == 0
          for: 5m
          labels:
            severity: critical
            component: database
          annotations:
            summary: "CNPG cluster {{ $labels.cluster }} is not ready"
            description: "CloudNativePG cluster {{ $labels.cluster }} has been not ready for 5 minutes"

        - alert: CNPGClusterPrimaryMissing
          expr: count(cnpg_pg_cluster_role{cluster="shared-postgres",role="primary"}) == 0
          for: 2m
          labels:
            severity: critical
            component: database
          annotations:
            summary: "CNPG cluster {{ $labels.cluster }} has no primary instance"
            description: "CloudNativePG cluster {{ $labels.cluster }} has no primary instance for 2 minutes"

        - alert: CNPGClusterReplicasBelowTarget
          expr: cnpg_pg_cluster_instances{cluster="shared-postgres"} < 3
          for: 10m
          labels:
            severity: warning
            component: database
          annotations:
            summary: "CNPG cluster {{ $labels.cluster }} has fewer replicas than expected"
            description: "CloudNativePG cluster {{ $labels.cluster }} has {{ $value }} instances (expected 3)"

        # Replication Alerts
        - alert: CNPGReplicationLagHigh
          expr: cnpg_pg_replication_lag{cluster="shared-postgres"} > 60
          for: 5m
          labels:
            severity: warning
            component: database
          annotations:
            summary: "CNPG replication lag high on {{ $labels.pod }}"
            description: "Replication lag is {{ $value }}s on {{ $labels.pod }}"

        - alert: CNPGReplicationLagCritical
          expr: cnpg_pg_replication_lag{cluster="shared-postgres"} > 300
          for: 2m
          labels:
            severity: critical
            component: database
          annotations:
            summary: "CNPG replication lag critical on {{ $labels.pod }}"
            description: "Replication lag is {{ $value }}s on {{ $labels.pod }}"

        # Backup Alerts
        - alert: CNPGBackupFailed
          expr: cnpg_pg_backup_last_status{cluster="shared-postgres"} != 0
          for: 5m
          labels:
            severity: critical
            component: database
          annotations:
            summary: "CNPG backup failed for cluster {{ $labels.cluster }}"
            description: "Last backup status is {{ $value }} (non-zero indicates failure)"

        - alert: CNPGBackupOverdue
          expr: time() - cnpg_pg_backup_last_successful_timestamp{cluster="shared-postgres"} > 172800  # 48 hours
          for: 1h
          labels:
            severity: critical
            component: database
          annotations:
            summary: "CNPG backup overdue for cluster {{ $labels.cluster }}"
            description: "Last successful backup was {{ $value | humanizeDuration }} ago"

        # Storage Alerts
        - alert: CNPGStorageNearFull
          expr: (cnpg_pg_database_size_bytes{cluster="shared-postgres"} / (20 * 1024 * 1024 * 1024)) > 0.8
          for: 15m
          labels:
            severity: warning
            component: database
          annotations:
            summary: "CNPG storage near capacity for database {{ $labels.datname }}"
            description: "Database {{ $labels.datname }} is {{ $value | humanizePercentage }} full"

        # Connection Alerts
        - alert: CNPGConnectionsNearLimit
          expr: (cnpg_pg_stat_database_numbackends{cluster="shared-postgres"} / 200) > 0.8
          for: 10m
          labels:
            severity: warning
            component: database
          annotations:
            summary: "CNPG connections near limit for database {{ $labels.datname }}"
            description: "Database {{ $labels.datname }} is using {{ $value | humanizePercentage }} of max_connections"

    - name: cloudnativepg.pooler
      interval: 30s
      rules:
        # Pooler Health Alerts
        - alert: CNPGPoolerNotReady
          expr: kube_deployment_status_replicas_available{namespace="cnpg-system",deployment=~".*-pooler.*"} < 2
          for: 5m
          labels:
            severity: warning
            component: pooler
          annotations:
            summary: "CNPG pooler {{ $labels.deployment }} not highly available"
            description: "Pooler {{ $labels.deployment }} has only {{ $value }} replicas available"

        # PgBouncer Connection Alerts
        - alert: CNPGPoolerConnectionsHigh
          expr: (cnpg_pgbouncer_pools_cl_active / cnpg_pgbouncer_config_max_client_conn) > 0.8
          for: 10m
          labels:
            severity: warning
            component: pooler
          annotations:
            summary: "CNPG pooler {{ $labels.pooler }} client connections high"
            description: "Pooler {{ $labels.pooler }} is using {{ $value | humanizePercentage }} of max_client_conn"

        - alert: CNPGPoolerServerConnectionsExhausted
          expr: cnpg_pgbouncer_pools_sv_active >= cnpg_pgbouncer_config_default_pool_size
          for: 5m
          labels:
            severity: warning
            component: pooler
          annotations:
            summary: "CNPG pooler {{ $labels.pooler }} server pool exhausted"
            description: "Pooler {{ $labels.pooler }} has reached default_pool_size limit"

        # PgBouncer Wait Queue Alerts
        - alert: CNPGPoolerWaitQueueBuildup
          expr: cnpg_pgbouncer_pools_cl_waiting > 10
          for: 5m
          labels:
            severity: warning
            component: pooler
          annotations:
            summary: "CNPG pooler {{ $labels.pooler }} has waiting clients"
            description: "Pooler {{ $labels.pooler }} has {{ $value }} clients waiting for connections"
```

### T10: Create Backup Validation CronJob
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/backup-validation.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cnpg-backup-validation
  namespace: cnpg-system
spec:
  # Run daily at 03:00 UTC (1 hour after backup completes)
  schedule: "0 3 * * *"

  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3

  jobTemplate:
    spec:
      backoffLimit: 2

      template:
        metadata:
          labels:
            app: cnpg-backup-validation

        spec:
          restartPolicy: OnFailure

          # Use non-root image with MinIO client pre-installed
          containers:
            - name: validate
              image: minio/mc:latest

              command:
                - /bin/sh
                - -c
                - |
                  set -e

                  # Configure mc alias
                  mc alias set s3 ${S3_ENDPOINT} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}

                  # List recent backups
                  echo "=== Listing recent backups ==="
                  mc ls s3/${BUCKET_NAME}/shared-postgres/base/ | tail -n 5

                  # Count base backups
                  BACKUP_COUNT=$(mc ls s3/${BUCKET_NAME}/shared-postgres/base/ | wc -l)
                  echo "Total base backups: ${BACKUP_COUNT}"

                  if [ "${BACKUP_COUNT}" -lt 1 ]; then
                    echo "ERROR: No backups found!"
                    exit 1
                  fi

                  # Check for recent backup (within 48 hours)
                  RECENT_BACKUP=$(mc ls s3/${BUCKET_NAME}/shared-postgres/base/ --json | \
                    jq -r 'select(.lastModified | fromdateiso8601 > (now - 172800)) | .key' | \
                    head -n 1)

                  if [ -z "${RECENT_BACKUP}" ]; then
                    echo "ERROR: No backup within last 48 hours!"
                    exit 1
                  fi

                  echo "Recent backup found: ${RECENT_BACKUP}"

                  # Verify WAL archive (check for recent WAL files)
                  echo "=== Checking WAL archive ==="
                  WAL_COUNT=$(mc ls s3/${BUCKET_NAME}/shared-postgres/wals/ --recursive | wc -l)
                  echo "Total WAL files: ${WAL_COUNT}"

                  if [ "${WAL_COUNT}" -lt 1 ]; then
                    echo "ERROR: No WAL files found!"
                    exit 1
                  fi

                  echo "Backup validation completed successfully"

              env:
                - name: S3_ENDPOINT
                  value: ${CNPG_MINIO_ENDPOINT_URL}
                - name: BUCKET_NAME
                  value: ${CNPG_BACKUP_BUCKET}
                - name: S3_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: cnpg-minio-credentials
                      key: ACCESS_KEY_ID
                - name: S3_SECRET_KEY
                  valueFrom:
                    secretKeyRef:
                      name: cnpg-minio-credentials
                      key: SECRET_ACCESS_KEY

              # Non-root security context
              securityContext:
                runAsNonRoot: true
                runAsUser: 10001
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop:
                    - ALL

              resources:
                requests:
                  cpu: "50m"
                  memory: "64Mi"
                limits:
                  cpu: "200m"
                  memory: "128Mi"

          # Pod security context
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            fsGroup: 10001
            seccompProfile:
              type: RuntimeDefault
```

### T11: Create Kustomization Manifest
**File**: `kubernetes/workloads/platform/databases/cloudnative-pg/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cnpg-system

resources:
  # ExternalSecrets (must exist before Cluster)
  - shared-cluster/externalsecrets.yaml

  # Cluster and backup configuration
  - shared-cluster/cluster.yaml
  - shared-cluster/scheduledbackup.yaml
  - shared-cluster/databases.yaml

  # Poolers
  - poolers/harbor-pooler.yaml
  - poolers/keycloak-pooler.yaml
  - poolers/gitlab-pooler.yaml
  - poolers/synergyflow-pooler.yaml

  # PodDisruptionBudgets
  - poolers/harbor-pooler-pdb.yaml
  - poolers/keycloak-pooler-pdb.yaml
  - poolers/gitlab-pooler-pdb.yaml
  - poolers/synergyflow-pooler-pdb.yaml

  # Monitoring
  - shared-cluster/prometheusrule.yaml

  # Backup validation
  - shared-cluster/backup-validation.yaml
```

### T12: Create Flux Kustomization
**File**: `kubernetes/infrastructure/databases/cloudnative-pg/ks.yaml` (or appropriate location)

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-databases-cloudnative-pg
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/workloads/platform/databases/cloudnative-pg

  prune: true
  wait: true

  # Depend on CNPG operator
  dependsOn:
    - name: cluster-infra-infrastructure

  # Health checks
  healthChecks:
    # Cluster health
    - apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      name: shared-postgres
      namespace: cnpg-system

    # ScheduledBackup health
    - apiVersion: postgresql.cnpg.io/v1
      kind: ScheduledBackup
      name: shared-postgres-backup
      namespace: cnpg-system

    # Pooler health
    - apiVersion: postgresql.cnpg.io/v1
      kind: Pooler
      name: harbor-pooler
      namespace: cnpg-system

    - apiVersion: postgresql.cnpg.io/v1
      kind: Pooler
      name: keycloak-pooler
      namespace: cnpg-system

    - apiVersion: postgresql.cnpg.io/v1
      kind: Pooler
      name: gitlab-pooler
      namespace: cnpg-system

    - apiVersion: postgresql.cnpg.io/v1
      kind: Pooler
      name: synergyflow-pooler
      namespace: cnpg-system

  # Variable substitution from cluster-settings
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T13: Local Validation
- [ ] Validate all YAML syntax: `kubectl --dry-run=client -f <file>`
- [ ] Build Flux kustomization: `flux build kustomization cluster-databases-cloudnative-pg --path ./kubernetes/workloads/platform/databases/cloudnative-pg`
- [ ] Build with kustomize: `kustomize build kubernetes/workloads/platform/databases/cloudnative-pg`
- [ ] Schema validation: `kubeconform -summary -output json kubernetes/workloads/platform/databases/cloudnative-pg/*.yaml`
- [ ] Verify variable substitution patterns: `grep -r '\${' kubernetes/workloads/platform/databases/cloudnative-pg/`
- [ ] Review Cluster manifest for PostgreSQL tuning parameters
- [ ] Verify six-field cron format in ScheduledBackup: `"0 0 2 * * *"`
- [ ] Confirm pooling modes: Harbor/GitLab/SynergyFlow=transaction, Keycloak=session
- [ ] Validate PodDisruptionBudget selectors match Pooler labels

### T14: Update Cluster Settings (if needed)
**File**: `kubernetes/clusters/infra/cluster-settings.yaml`

Ensure all required variables are present:
```yaml
data:
  # CNPG Cluster
  CNPG_POSTGRES_VERSION: "17.4"
  CNPG_INSTANCES: "3"
  CNPG_STORAGE_CLASS: "${BLOCK_SC}"
  CNPG_DATA_SIZE: "20Gi"
  CNPG_WAL_SIZE: "5Gi"
  CNPG_MIN_SYNC_REPLICAS: "1"
  CNPG_MAX_SYNC_REPLICAS: "2"

  # Backup
  CNPG_BACKUP_SCHEDULE: "0 0 2 * * *"
  CNPG_BACKUP_BUCKET: "cnpg-backups"
  CNPG_MINIO_ENDPOINT_URL: "http://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local"
  CNPG_BACKUP_RETENTION: "30d"

  # Pooler
  CNPG_POOLER_REPLICAS: "3"

  # External Secrets
  EXTERNAL_SECRET_STORE: "onepassword"
  CNPG_SUPERUSER_SECRET_PATH: "kubernetes/infra/cloudnative-pg/superuser"
  CNPG_MINIO_SECRET_PATH: "kubernetes/infra/cloudnative-pg/minio"
  CNPG_HARBOR_SECRET_PATH: "kubernetes/infra/cloudnative-pg/harbor"
  CNPG_KEYCLOAK_SECRET_PATH: "kubernetes/infra/cloudnative-pg/keycloak"
  CNPG_GITLAB_SECRET_PATH: "kubernetes/infra/cloudnative-pg/gitlab"
  CNPG_SYNERGYFLOW_SECRET_PATH: "kubernetes/infra/cloudnative-pg/synergyflow"
```

### T15: Commit to Git
- [ ] Stage all new and modified files
- [ ] Commit with message: "feat(db): create CloudNativePG shared cluster manifests (Story 24)"
- [ ] Include in commit message:
  - 3-instance cluster with synchronous replication
  - Four PgBouncer poolers with HA configuration
  - Scheduled backups to S3 with six-field cron
  - Database CRs for declarative provisioning
  - Monitoring and alerting integration
  - Backup validation CronJob with non-root image

## Runtime Validation (MOVED TO STORY 45)

The following validation steps will be executed during Story 45 deployment:

### Cluster Deployment Validation
```bash
# Verify Cluster resource created
kubectl --context=infra -n cnpg-system get clusters.postgresql.cnpg.io shared-postgres

# Check cluster status
kubectl --context=infra -n cnpg-system get clusters.postgresql.cnpg.io shared-postgres -o yaml | grep -A 20 status:

# Verify instances count
kubectl --context=infra -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres

# Check primary election
kubectl --context=infra -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres,role=primary

# Verify cluster readiness
kubectl --context=infra -n cnpg-system wait --for=condition=Ready cluster/shared-postgres --timeout=10m
```

### Service Discovery Validation
```bash
# Verify primary service (read-write)
kubectl --context=infra -n cnpg-system get svc shared-postgres-rw
nslookup shared-postgres-rw.cnpg-system.svc.cluster.local

# Verify replica service (read-only)
kubectl --context=infra -n cnpg-system get svc shared-postgres-ro
nslookup shared-postgres-ro.cnpg-system.svc.cluster.local

# Check service endpoints
kubectl --context=infra -n cnpg-system get endpoints shared-postgres-rw -o yaml
kubectl --context=infra -n cnpg-system get endpoints shared-postgres-ro -o yaml
```

### Backup Configuration Validation
```bash
# Verify ScheduledBackup resource
kubectl --context=infra -n cnpg-system get scheduledbackups.postgresql.cnpg.io shared-postgres-backup

# Check backup schedule (six-field format)
kubectl --context=infra -n cnpg-system get scheduledbackups.postgresql.cnpg.io shared-postgres-backup -o jsonpath='{.spec.schedule}'
# Expected: "0 0 2 * * *"

# Verify cluster-settings backup schedule variable
kubectl --context=infra -n flux-system get cm cluster-settings -o jsonpath='{.data.CNPG_BACKUP_SCHEDULE}'
# Expected: "0 0 2 * * *"

# Check first backup execution (wait for scheduled time or trigger immediate)
kubectl --context=infra -n cnpg-system get backups.postgresql.cnpg.io

# Verify S3 backup storage (using MinIO client or AWS CLI)
mc ls s3/cnpg-backups/shared-postgres/base/
mc ls s3/cnpg-backups/shared-postgres/wals/
```

### Database Provisioning Validation
```bash
# Verify Database CRs created
kubectl --context=infra -n cnpg-system get databases.postgresql.cnpg.io

# Check database status
kubectl --context=infra -n cnpg-system get databases.postgresql.cnpg.io harbor -o yaml | grep -A 10 status:

# Connect to primary and verify databases exist
kubectl --context=infra -n cnpg-system exec -it shared-postgres-1 -- psql -U postgres -c "\l"
# Expected: harbor, keycloak, gitlab, synergyflow databases

# Verify extensions installed
kubectl --context=infra -n cnpg-system exec -it shared-postgres-1 -- psql -U postgres -d harbor -c "\dx"
# Expected: uuid-ossp extension

kubectl --context=infra -n cnpg-system exec -it shared-postgres-1 -- psql -U postgres -d gitlab -c "\dx"
# Expected: pg_trgm, btree_gist, plpgsql, amcheck extensions
```

### Pooler Deployment Validation
```bash
# Verify Pooler resources created
kubectl --context=infra -n cnpg-system get poolers.postgresql.cnpg.io

# Check pooler deployments
kubectl --context=infra -n cnpg-system get deployments -l app.kubernetes.io/component=connection-pooler

# Verify pooler replica counts (should be 3 each)
kubectl --context=infra -n cnpg-system get deployments -l app.kubernetes.io/component=connection-pooler -o wide

# Check pooler pods are running and distributed
kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/component=connection-pooler -o wide

# Verify pooler services
kubectl --context=infra -n cnpg-system get svc -l cnpg.io/poolerName
# Expected: harbor-pooler-rw, keycloak-pooler-rw, gitlab-pooler-rw, synergyflow-pooler-rw

# Test pooler service DNS resolution
for pooler in harbor keycloak gitlab synergyflow; do
  nslookup ${pooler}-pooler-rw.cnpg-system.svc.cluster.local
done
```

### PodDisruptionBudget Validation
```bash
# Verify PDBs created
kubectl --context=infra -n cnpg-system get pdb

# Check PDB status
kubectl --context=infra -n cnpg-system get pdb -o wide
# Expected: ALLOWED-DISRUPTIONS >= 1 for each pooler
```

### Metrics and Monitoring Validation
```bash
# Verify PodMonitors created by CNPG operator
kubectl --context=infra -n cnpg-system get podmonitors

# Check PodMonitor for cluster
kubectl --context=infra -n cnpg-system get podmonitors -l cnpg.io/cluster=shared-postgres

# Check PodMonitors for poolers
kubectl --context=infra -n cnpg-system get podmonitors -l cnpg.io/poolerName

# Verify metrics endpoints (from cluster pod)
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- curl -s http://localhost:9187/metrics | grep cnpg_

# Verify pooler metrics (from pooler pod)
POOLER_POD=$(kubectl --context=infra -n cnpg-system get pods -l cnpg.io/poolerName=harbor-pooler -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n cnpg-system exec ${POOLER_POD} -- curl -s http://localhost:9127/metrics | grep cnpg_pgbouncer_

# Verify VictoriaMetrics scraping metrics
# (Requires VictoriaMetrics query access)
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=cnpg_pg_cluster_ready" | jq .

curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=cnpg_pgbouncer_pools_cl_active" | jq .
```

### PrometheusRule Validation
```bash
# Verify VMRule created
kubectl --context=infra -n cnpg-system get vmrule cloudnative-pg-cluster

# Check VMRule status
kubectl --context=infra -n cnpg-system get vmrule cloudnative-pg-cluster -o yaml | grep -A 10 status:

# Verify rules loaded in VictoriaMetrics
# (Requires VictoriaMetrics query access)
curl -s "http://vmalert.observability.svc.cluster.local:8080/api/v1/rules" | jq '.data.groups[] | select(.name | contains("cloudnativepg"))'
```

### Security Validation
```bash
# Verify TLS certificates created by CNPG operator
kubectl --context=infra -n cnpg-system get secrets | grep shared-postgres

# Check client certificates
kubectl --context=infra -n cnpg-system get secret shared-postgres-ca -o yaml
kubectl --context=infra -n cnpg-system get secret shared-postgres-server -o yaml

# Verify PostgreSQL TLS configuration
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW ssl;"
# Expected: on

kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW ssl_cert_file;"
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW ssl_key_file;"

# Test TLS connection from pooler to PostgreSQL
POOLER_POD=$(kubectl --context=infra -n cnpg-system get pods -l cnpg.io/poolerName=harbor-pooler -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n cnpg-system logs ${POOLER_POD} | grep -i tls

# Verify PSA enforcement
kubectl --context=infra get namespace cnpg-system -o yaml | grep pod-security
# Expected: enforce: restricted
```

### ExternalSecret Validation
```bash
# Verify all ExternalSecrets synced
kubectl --context=infra -n cnpg-system get externalsecrets

# Check ExternalSecret status
kubectl --context=infra -n cnpg-system get externalsecrets -o wide
# Expected: STATUS=SecretSynced for all

# Verify secrets created
kubectl --context=infra -n cnpg-system get secrets | grep -E "cnpg-superuser|cnpg-minio|harbor-db|keycloak-db|gitlab-db|synergyflow-db"

# Check secret data (verify keys exist, don't display values)
kubectl --context=infra -n cnpg-system get secret cnpg-superuser -o jsonpath='{.data}' | jq 'keys'
# Expected: ["password", "username"]
```

### Backup Validation CronJob Testing
```bash
# Verify CronJob created
kubectl --context=infra -n cnpg-system get cronjob cnpg-backup-validation

# Check CronJob schedule
kubectl --context=infra -n cnpg-system get cronjob cnpg-backup-validation -o jsonpath='{.spec.schedule}'
# Expected: "0 3 * * *"

# Manually trigger backup validation job
kubectl --context=infra -n cnpg-system create job --from=cronjob/cnpg-backup-validation cnpg-backup-validation-manual

# Wait for job completion
kubectl --context=infra -n cnpg-system wait --for=condition=complete job/cnpg-backup-validation-manual --timeout=5m

# Check job logs
kubectl --context=infra -n cnpg-system logs job/cnpg-backup-validation-manual

# Verify job ran with non-root user
kubectl --context=infra -n cnpg-system get pod -l job-name=cnpg-backup-validation-manual -o jsonpath='{.items[0].spec.securityContext}'
# Expected: runAsNonRoot: true, runAsUser: 10001
```

### Replication Validation
```bash
# Check replication status
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Verify synchronous replication configuration
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW synchronous_standby_names;"

# Check replication slots
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT * FROM pg_replication_slots;"

# Verify WAL archiving
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW archive_mode;"
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SHOW archive_command;"

# Check for replication lag
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;"
```

### Application Connectivity Testing
```bash
# Test Harbor pooler connectivity (from debug pod)
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=harbor-pooler-rw.cnpg-system.svc.cluster.local port=5432 dbname=harbor user=harbor sslmode=require" -c "SELECT version();"

# Test Keycloak pooler connectivity
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=keycloak-pooler-rw.cnpg-system.svc.cluster.local port=5432 dbname=keycloak user=keycloak sslmode=require" -c "SELECT version();"

# Test GitLab pooler connectivity
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=gitlab-pooler-rw.cnpg-system.svc.cluster.local port=5432 dbname=gitlab user=gitlab sslmode=require" -c "SELECT version();"

# Test SynergyFlow pooler connectivity
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=synergyflow-pooler-rw.cnpg-system.svc.cluster.local port=5432 dbname=synergyflow user=synergyflow sslmode=require" -c "SELECT version();"
```

### Integration Testing
```bash
# Test write operation through pooler (requires credentials)
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=harbor-pooler-rw.cnpg-system.svc.cluster.local port=5432 dbname=harbor user=harbor" <<EOF
CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO test_table (data) VALUES ('test from pooler');
SELECT * FROM test_table;
DROP TABLE test_table;
EOF

# Verify read-only service (if configured)
# Connect to shared-postgres-ro and attempt write (should fail)
kubectl --context=infra -n cnpg-system run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql "host=shared-postgres-ro.cnpg-system.svc.cluster.local port=5432 dbname=postgres user=postgres" \
  -c "CREATE TABLE test (id INT);"
# Expected: ERROR (read-only transaction)
```

### Performance Validation
```bash
# Check connection pooling effectiveness
POOLER_POD=$(kubectl --context=infra -n cnpg-system get pods -l cnpg.io/poolerName=harbor-pooler -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n cnpg-system exec ${POOLER_POD} -- psql -U pgbouncer -p 9127 pgbouncer -c "SHOW POOLS;"
kubectl --context=infra -n cnpg-system exec ${POOLER_POD} -- psql -U pgbouncer -p 9127 pgbouncer -c "SHOW STATS;"

# Monitor active connections
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Check database sizes
kubectl --context=infra -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname IN ('harbor', 'keycloak', 'gitlab', 'synergyflow');"
```

## Definition of Done

### Manifest Creation Complete (This Story)
- [ ] All acceptance criteria AC1-AC10 met with evidence
- [ ] Cluster manifest created with 3 instances, synchronous replication, TLS, PostgreSQL 17.4
- [ ] ScheduledBackup manifest created with six-field cron schedule ("0 0 2 * * *"), S3 backend, encryption
- [ ] ExternalSecret manifests created for superuser, MinIO, and all application credentials
- [ ] Four Pooler manifests created (Harbor, GitLab, Keycloak, SynergyFlow) with appropriate pooling modes and HA configuration
- [ ] PodDisruptionBudgets created for all poolers
- [ ] Database CRs created for declarative provisioning
- [ ] PrometheusRule created with comprehensive alerts for cluster health, backups, replication, and poolers
- [ ] Backup validation CronJob created with non-root image and secure configuration
- [ ] Flux Kustomization manifest created with health checks and dependencies
- [ ] All manifests pass local validation (kubectl, flux, kustomize, kubeconform)
- [ ] Cluster settings updated with all required variables
- [ ] Changes committed to git with descriptive commit message
- [ ] Story documented in change log

### NOT Part of DoD (Moved to Story 45)
- ~~Cluster deployed and healthy in infra cluster~~
- ~~Scheduled backups executing and stored in S3~~
- ~~Pooler services resolvable and accepting connections~~
- ~~Metrics scraped by VictoriaMetrics~~
- ~~Alerts firing correctly in VictoriaMetrics~~
- ~~TLS encryption verified end-to-end~~
- ~~Application connectivity tested and confirmed~~
- ~~Backup validation CronJob executed successfully~~

---

## Design Notes

### Multi-Tenant Database Architecture

This story creates a **shared PostgreSQL cluster** serving multiple platform applications. This approach provides:

1. **Resource Efficiency**: Single cluster reduces overhead vs. per-app clusters
2. **Operational Simplicity**: Centralized backup, monitoring, and upgrade management
3. **Security Isolation**: Per-application credentials and database separation
4. **Connection Pooling**: PgBouncer poolers provide efficient connection management per application

### Cluster Configuration

**High Availability**:
- 3 PostgreSQL instances with automatic failover
- Synchronous replication (minSyncReplicas: 1, maxSyncReplicas: 2)
- Pod anti-affinity for distribution across nodes
- PodDisruptionBudgets for poolers to ensure availability during updates

**Storage**:
- Data volume: 20Gi per instance (Rook-Ceph block storage)
- WAL volume: 5Gi per instance (separate for I/O optimization)
- Total storage: 75Gi (3 instances × (20Gi + 5Gi))

**PostgreSQL Version**: 17.4 (latest stable, aligned with CNPG 0.26.x)

**Extensions**:
- **pg_stat_statements**: Query performance monitoring
- **pg_trgm**: Text similarity and trigram indexing (GitLab requirement)
- **btree_gist**: GiST indexing for common datatypes (GitLab requirement)
- **uuid-ossp**: UUID generation (Harbor requirement)
- **plpgsql**: Procedural language (GitLab requirement)
- **amcheck**: Relation integrity verification (GitLab 18.4+ requirement)

### Backup Strategy

**Schedule**: Daily at 02:00 UTC using six-field cron format ("0 0 2 * * *")

**Backend**: S3-compatible storage (MinIO via Rook-Ceph RGW)

**Retention**: 30 days (configurable via CNPG_BACKUP_RETENTION)

**Backup Components**:
1. **Base Backups**: Full physical backups compressed with gzip and encrypted with AES256
2. **WAL Archiving**: Continuous WAL archiving for point-in-time recovery
3. **Validation**: Daily CronJob verifies backup integrity and checks for recent backups

**Security**:
- Server-side encryption (SSE) with AES256
- Compression for bandwidth and storage efficiency
- Credentials managed via ExternalSecrets (1Password)

### PgBouncer Pooler Configuration

**Pooling Modes**:
- **Transaction Mode** (Harbor, GitLab, SynergyFlow): Maximizes connection reuse for stateless applications
  - Harbor: max_client_conn=200, default_pool_size=15
  - GitLab: max_client_conn=300, default_pool_size=25 (higher load expected)
  - SynergyFlow: max_client_conn=150, default_pool_size=10
- **Session Mode** (Keycloak): Preserves session state for applications requiring SET, advisory locks, LISTEN/NOTIFY
  - Keycloak: max_client_conn=200, default_pool_size=20

**High Availability**:
- 3 replicas per pooler with pod anti-affinity
- PodDisruptionBudget (maxUnavailable: 1) ensures 2 replicas during updates
- Rolling update strategy for zero-downtime changes

**Monitoring**:
- PodMonitors automatically created by CNPG operator (enablePodMonitor: true)
- Metrics exposed on port 9127 with cnpg_pgbouncer_* prefix
- Alerts for connection exhaustion, wait queue buildup, and availability

**Security**:
- TLS encryption client→pooler and pooler→Postgres (CNPG-managed certificates)
- Dedicated pooler service accounts with minimal privileges
- PSA restricted enforcement (no privileged containers)

### Database Provisioning

**Declarative Approach**: Using Database CRs instead of ad-hoc provisioning Jobs

**Benefits**:
1. **GitOps Friendly**: Database lifecycle managed in manifests
2. **Reduced Superuser Exposure**: No need to distribute superuser credentials to Jobs
3. **Consistent**: Operator ensures database exists and matches spec
4. **Auditable**: All changes tracked in git

**Per-Application Databases**:
- **Harbor**: uuid-ossp extension for container metadata
- **Keycloak**: Default configuration (session-based pooling)
- **GitLab**: pg_trgm, btree_gist, plpgsql, amcheck extensions
- **SynergyFlow**: Default configuration

**Managed Roles**: Users created via `.spec.managed.roles` with per-app credentials from ExternalSecrets

### Monitoring and Alerting

**Metrics Collection**:
- Cluster metrics: cnpg_pg_* (database size, connections, replication lag, backup status)
- Pooler metrics: cnpg_pgbouncer_* (pools, connections, wait queues, stats)
- Scraped by VictoriaMetrics via PodMonitors

**Alert Categories**:
1. **Cluster Health**: Primary missing, cluster not ready, replicas below target
2. **Replication**: High lag (>60s warning, >300s critical)
3. **Backups**: Backup failed, backup overdue (>48h)
4. **Storage**: Database size near capacity (>80%)
5. **Connections**: Near max_connections limit (>80%)
6. **Pooler Health**: Not highly available, connections high, server pool exhausted, wait queue buildup

### Security Considerations

**Pod Security Admission**: Restricted level enforcement (no privileged containers)

**TLS Encryption**:
- PostgreSQL TLS 1.3 with server certificates
- Client→Pooler and Pooler→Postgres connections encrypted
- Certificates managed by CNPG operator

**Credentials Management**:
- All secrets sourced from 1Password via ExternalSecrets Operator
- Superuser credentials only for break-glass scenarios (enableSuperuserAccess: true but discouraged for day-2 operations)
- Per-application credentials with minimal privileges

**Backup Security**:
- S3 credentials stored in ExternalSecrets
- Server-side encryption (AES256)
- Backup validation runs as non-root user (10001) with no privilege escalation

**Non-Root Backup Validation**:
- Uses minio/mc image with pre-installed tools (no apt-get at runtime)
- readOnlyRootFilesystem: true
- Drops all Linux capabilities
- runAsNonRoot: true with specific UID 10001

### Version Alignment

**CNPG Operator**: 0.26.0 (from Story 23)
- Operator chart: 0.26.0
- Operator app version: 1.27.0
- CRDs: 0.26.0

**PostgreSQL**: 17.4 (latest stable)
- Image: ghcr.io/cloudnative-pg/postgresql:17.4

**Compatibility**: CNPG 1.27.x supports PostgreSQL 12-17

### Future Considerations

**Namespace Separation**: Current manifests place data-plane resources in `cnpg-system` (same as operator). Consider moving to dedicated `databases` namespace for:
- Cleaner PSA boundaries
- Least privilege separation (operator vs. data plane)
- Easier RBAC management

**Synchronous Replication API**: CNPG 1.25+ introduces `dataDurability` and `postgresql.synchronous` fields for expressing durability requirements. Plan migration when aligning versions.

**Read-Only Poolers**: Add `ro` type poolers for read-heavy applications to distribute read load across replicas.

**Connection Pooling Tuning**: Monitor cnpg_pgbouncer_stats_* metrics and adjust pool sizes based on actual workload patterns.

**Backup Restore Testing**: Periodically test backup restore procedures to validate disaster recovery readiness.

**Upgrade Strategy**: CNPG supports in-place PostgreSQL minor version upgrades. Plan major version upgrades carefully with application compatibility testing.

---

## Research — CNPG Pooler (PgBouncer)

- What it is: CloudNativePG (CNPG) exposes a `Pooler` CRD that deploys PgBouncer as a separate, scalable access layer in front of a CNPG `Cluster` (`type: rw` or `ro`). Poolers live in the same namespace as their target cluster and are created/managed independently from the `Cluster`.
- Key spec fields: `.spec.instances` replica count, `.spec.type` (`rw`/`ro`), `.spec.pgbouncer.poolMode` (`session` or `transaction`), `.spec.pgbouncer.parameters` for tuning, optional `.spec.monitoring.enablePodMonitor: true` to auto-create a `PodMonitor`. `.spec.pgbouncer.authQuery`/`authQuerySecret` enable custom auth queries.
- Security/auth: Pooler reuses the cluster TLS certs for in-transit encryption on both client→pooler and pooler→Postgres sides. CNPG creates a dedicated `auth_user` (`cnpg_pooler_pgbouncer`) and `user_search` function; PgBouncer authenticates to Postgres with a TLS client cert to run auth queries. If you supply your own secrets, you must manually create the role/function/grants.
- Monitoring: CNPG's PgBouncer image exposes Prometheus metrics on port `9127` with prefixes `cnpg_pgbouncer_*` (e.g., lists, pools, stats). You can enable an operator-managed `PodMonitor` via `.spec.monitoring.enablePodMonitor: true`, or select pods by label `cnpg.io/poolerName: <POOLER_NAME>` in a manual PodMonitor.

### Pooling Mode Guidance

- `transaction` mode maximizes server connection reuse but disallows session-scoped features (e.g., `SET`, session advisory locks, WITH HOLD cursors, temp tables with PRESERVE/DELETE ROWS). Use only if apps don't rely on these.
- Prepared statements in transaction mode are supported if `max_prepared_statements > 0`, but client/driver caveats apply (e.g., older PHP/PDO). Alternatively, disable prepared statements at the client (e.g., JDBC `prepareThreshold=0`).
- `session` mode preserves all PostgreSQL semantics at the cost of lower pooling efficiency. Choose per-app based on workload characteristics.

### Operational Notes

- Lifecycle: Poolers are decoupled from clusters (create/scale/roll independently). Operator upgrades trigger pooler pod rolling upgrades.
- Rolling strategy: Use Deployment `RollingUpdate` with `maxUnavailable: 1` for zero-drop during changes (mirrors our current manifests). Reference pod anti-affinity across nodes for HA.
- Pause/Resume: `.spec.pgbouncer.paused: true|false` maps to PgBouncer `PAUSE/RESUME` for safe maintenance windows.
- Metrics check: `kubectl -n cnpg-system exec -ti <pooler-pod> -- curl -s 127.0.0.1:9127/metrics | rg cnpg_pgbouncer_` to verify scrape.

### Baseline Recommendations (Infra Cluster)

- One pooler per app hitting the shared cluster (e.g., `harbor-pooler`, `keycloak-pooler`) with `.spec.type: rw` by default; add `ro` poolers for read-heavy apps as needed.
- Start with `poolMode: transaction` for stateless web apps and APIs; pin `session` for apps known to use session state (advisory locks, SET, LISTEN/NOTIFY patterns with HOLD cursors, etc.). Validate drivers against transaction-mode limitations.
- Enable `.spec.monitoring.enablePodMonitor: true` and keep PodMonitor operator-managed; scrape port `9127`. Ensure selector uses `cnpg.io/poolerName`.
- Parameters: set sane upper bounds and timeouts per app. Example starting point (already reflected in our manifests): `max_client_conn`, `default_pool_size`, `min_pool_size`, `reserve_pool_size`, `server_connect_timeout`, `query_timeout`, `idle_transaction_timeout`, and `ignore_startup_parameters: "extra_float_digits,options"`. Tune using `cnpg_pgbouncer_stats_*` and application latency.
- Topology: keep at least 3 replicas with pod anti-affinity across nodes; ensure PDB and node spread at the environment layer to avoid cross-AZ hops where possible.

#### Per-App Pooling Mode (initial)
- Harbor — transaction (current manifest)
- GitLab — transaction (current manifest)
- SynergyFlow — transaction (current manifest)
- Keycloak — session (current manifest)

---

## Research — Shared Cluster Best Practices

- Scheduled backups require a six-field cron expression (seconds field first). Use `"0 0 2 * * *"` for 02:00 UTC instead of `"0 2 * * *"`.
- Prefer declarative DB provisioning over ad-hoc Jobs: CNPG provides a `Database` CRD for per-database lifecycle; combine with `managed.roles` to avoid distributing superuser credentials.
- Synchronous replication: On ≥1.25, you can express durability with `dataDurability` and `postgresql.synchronous` (e.g., `preferred`/`required`) rather than only `minSyncReplicas/maxSyncReplicas`. Plan a migration to the new config when you align versions.
- Backups: Use `barmanObjectStore` with compression and optional S3-side encryption (`sse: AES256` or KMS). Periodically validate restore using barman cloud tools.
- Security and PSA: CNPG components do not require privileged pods; target `restricted` PSA for cluster namespaces and avoid running jobs as root with `apt-get` in-pod.

---

## Gap Analysis — Repo vs Best Practices

- ScheduledBackup cron uses 5-field format (`"0 2 * * *"`); should be 6-field (`"0 0 2 * * *"`). **FIXED in this story**
- Backup validation CronJob installs packages at runtime as root and sets broad Linux capabilities. Replace with a purpose-built image (e.g., `minio/mc` or `aws-cli`) or CNPG barman tools and drop root/privilege escalation. **FIXED in this story**
- Superuser exposure: `enableSuperuserAccess: true` and provisioning Jobs use superuser creds. Prefer `Database` CR + `managed.roles`, and disable superuser access for day-2 operations. **ADDRESSED in this story** (Database CRs created, superuser use documented for break-glass only)
- Operator/data-plane mixing: Cluster and poolers run in `cnpg-system` (operator namespace). Move data-plane resources into a dedicated namespace (e.g., `databases`) for least privilege and cleaner PSA boundaries. **DOCUMENTED as future consideration**
- Version migration opportunity: When aligning operator/CRDs to ≥1.25, plan to express synchronous replication via `dataDurability` and update retention/backup settings to match current defaults. **DOCUMENTED as future consideration**

---

## Change Log

### v3.0 - 2025-10-26 - Manifests-First Refinement
**Architect**: Separated manifest creation from deployment and validation following v3.0 architecture pattern.

**Changes**:
1. **Story Rewrite**: Focused on creating manifests for shared PostgreSQL cluster with poolers, backups, and monitoring
2. **Scope Split**: "This Story (Manifest Creation)" vs. "Deferred to Story 45 (Deployment & Validation)"
3. **Acceptance Criteria**: Rewrote AC1-AC10 for manifest creation; deferred runtime validation to Story 45
4. **Dependencies**: Updated to local tools only (kubectl, flux, kustomize, kubeconform, yq, git)
5. **Tasks**: Restructured to T1-T15 covering manifest creation and local validation:
   - T1: Prerequisites and configuration strategy
   - T2: Namespace and base configuration
   - T3: ExternalSecret manifests (superuser, MinIO, per-app credentials, pooler auth)
   - T4: Cluster manifest (3 instances, sync replication, TLS, extensions, storage)
   - T5: ScheduledBackup manifest (six-field cron, S3 backend, encryption)
   - T6: Database CRs (declarative provisioning for harbor, keycloak, gitlab, synergyflow)
   - T7: PgBouncer Pooler manifests (4 poolers with HA, appropriate pooling modes)
   - T8: PodDisruptionBudgets for poolers
   - T9: PrometheusRule with comprehensive alerts
   - T10: Backup validation CronJob (non-root, secure)
   - T11: Kustomization manifest
   - T12: Flux Kustomization with health checks
   - T13: Local validation
   - T14: Cluster settings update
   - T15: Git commit
6. **Runtime Validation**: Created comprehensive "Runtime Validation (MOVED TO STORY 45)" section with 12 categories:
   - Cluster deployment validation
   - Service discovery validation
   - Backup configuration validation
   - Database provisioning validation
   - Pooler deployment validation
   - PodDisruptionBudget validation
   - Metrics and monitoring validation
   - PrometheusRule validation
   - Security validation (TLS, PSA)
   - ExternalSecret validation
   - Backup validation CronJob testing
   - Replication validation
   - Application connectivity testing
   - Integration testing
   - Performance validation
7. **DoD Update**: "Manifest Creation Complete" vs. "NOT Part of DoD (Moved to Story 45)"
8. **Design Notes**: Added comprehensive design documentation covering:
   - Multi-tenant database architecture rationale
   - Cluster configuration (HA, storage, version, extensions)
   - Backup strategy (schedule, backend, retention, security)
   - PgBouncer pooler configuration (modes, HA, monitoring, security)
   - Database provisioning (declarative approach, per-app databases, managed roles)
   - Monitoring and alerting (metrics, alert categories)
   - Security considerations (PSA, TLS, credentials, backup security)
   - Version alignment (CNPG 0.26.0, PostgreSQL 17.4)
   - Future considerations (namespace separation, API migration, tuning, testing)
9. **Gap Analysis Fixes**:
   - Fixed six-field cron format in ScheduledBackup
   - Replaced backup validation CronJob with non-root minio/mc image
   - Added Database CRs for declarative provisioning
   - Documented superuser use for break-glass only
   - Documented future namespace separation consideration

**Technical Details**:
- CloudNativePG 0.26.0 operator (from Story 23)
- PostgreSQL 17.4 (latest stable)
- 3-instance cluster with synchronous replication (minSyncReplicas: 1, maxSyncReplicas: 2)
- Four PgBouncer poolers: Harbor, GitLab, SynergyFlow (transaction mode), Keycloak (session mode)
- Scheduled backups: Daily 02:00 UTC, 30-day retention, S3 backend with encryption
- Storage: 20Gi data + 5Gi WAL per instance (Rook-Ceph block storage)
- TLS encryption end-to-end (client→pooler→Postgres)
- PSA restricted enforcement (no privileged containers)
- Comprehensive monitoring with PodMonitors and PrometheusRule alerts
- Database CRs for declarative provisioning (harbor, keycloak, gitlab, synergyflow)
- Secure backup validation with non-root minio/mc image

**Validation Approach**:
- Local-only validation using kubectl --dry-run, flux build, kustomize build, kubeconform
- Comprehensive runtime validation commands documented for Story 45
- No cluster access required for this story

**Story Workflow**:
1. Create all manifests for shared PostgreSQL cluster infrastructure
2. Validate manifests locally using GitOps tools
3. Commit to git
4. Deployment and runtime validation deferred to Story 45
