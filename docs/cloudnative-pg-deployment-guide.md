# CloudNative-PG Platform Deployment Guide

**Status:** Ready for Production Deployment
**Version:** 1.0
**Last Updated:** 2025-10-15
**Target PostgreSQL:** 16.8
**CNPG Operator:** 1.25.1

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [Migration from Legacy gitlab-postgres](#migration-from-legacy-gitlab-postgres)
6. [Operational Procedures](#operational-procedures)
7. [Troubleshooting](#troubleshooting)
8. [References](#references)

---

## Overview

This deployment implements a **production-grade, multi-tenant PostgreSQL platform** using CloudNative-PG operator. The platform provides:

✅ **High Availability**: 3-instance clusters with automatic failover
✅ **Multi-Tenancy**: Shared cluster hosting multiple application databases
✅ **Connection Pooling**: PgBouncer poolers for efficient connection management
✅ **Backup & DR**: Multi-tier backup strategy with PITR capability
✅ **Monitoring**: Comprehensive metrics, alerts, and custom queries
✅ **Security**: TLS encryption, RBAC, network policies
✅ **Self-Service**: Reusable component for database provisioning

### Key Improvements Over Legacy Deployment

| Feature | Legacy (gitlab-postgres) | New (shared-postgres) |
|---------|--------------------------|----------------------|
| Architecture | Single-purpose | Multi-tenant platform |
| Operator | Not installed | Deployed in infrastructure |
| Instances | 3 | 3 (configurable) |
| PostgreSQL | 15 | 16.8 |
| Connection Pooling | None | PgBouncer per database |
| Storage | 200Gi data, 100Gi WAL | 500Gi data, 200Gi WAL |
| Backup Tiers | 1 (MinIO) | 3 (Local, MinIO, R2) |
| Monitoring | Basic PodMonitor | 15+ alerts, custom queries |
| Performance Tuning | Minimal | Optimized for 16GB RAM |
| Security | Basic | TLS, managed roles, network policies |

---

## Architecture

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: CNPG Operator (cnpg-system namespace)              │
│ ├── HelmRelease: cloudnative-pg v1.25.1                     │
│ ├── Replicas: 2 (HA)                                        │
│ └── CRDs: Cluster, Pooler, Backup, ScheduledBackup          │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Database Clusters (cnpg-system namespace)          │
│                                                             │
│ ┌─────────────────────┐  ┌──────────────────────┐           │
│ │ gitlab-postgres     │  │ shared-postgres      │           │
│ │ (Legacy - Migrate)  │  │ (New Platform)       │           │
│ │ - 3 instances       │  │ - PG 16.8            │           │
│ │ - PG 15             │  │ - 3 instances        │           │
│ └─────────────────────┘  │ - 500Gi data         │           │
│                          │ - Optimized config   │           │
│                          │ - TLS enabled        │           │
│                          └──────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Connection Poolers (cnpg-system namespace)         │
│ ├── gitlab-pooler (transaction mode, 50 pool)               │
│ ├── harbor-pooler (transaction mode, 25 pool)               │
│ ├── mattermost-pooler (transaction mode, 40 pool)           │
│ └── keycloak-pooler (session mode, 20 pool)                 │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Monitoring & Alerting                              │
│ ├── Operator Alerts: 5 rules                                │
│ ├── Cluster Alerts: 15 rules                                │
│ ├── Custom Metrics: 7 query families                        │
│ └── Grafana Dashboards: Pre-built CNPG dashboards           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Backup & Disaster Recovery                         │
│ ├── Tier 1: Local (24h) - Rook-Ceph                         │
│ ├── Tier 2: Primary (30d) - MinIO                           │
│ ├── Tier 3: DR (90d) - Cloudflare R2                        │
│ ├── Schedule: Daily at 2 AM UTC                             │
│ └── PITR: < 5 minute RPO                                    │
└─────────────────────────────────────────────────────────────┘
```

### Network Topology

```
┌────────────────────────────────────────────────────────┐
│ infra Cluster                                          │
│                                                        │
│  ┌────────────────────────────────────────────┐        │
│  │ cnpg-system namespace                      │        │
│  │                                            │        │
│  │  [shared-postgres-rw] ← Primary            │        │
│  │  [shared-postgres-ro] ← Replicas           │        │
│  │  [shared-postgres-r]  ← Any instance       │        │
│  │                                            │        │
│  │  [gitlab-pooler-rw]    ← Pooler            │        │
│  │  [harbor-pooler-rw]    ← Pooler            │        │
│  │  [mattermost-pooler-rw] ← Pooler           │        │
│  │  [keycloak-pooler-rw]   ← Pooler           │        │
│  └────────────────────────────────────────────┘        │
│                    ↑                                   │
│                    │ Cilium ClusterMesh                │
│                    │ (service.cilium.io/global: true)  │
└────────────────────┼───────────────────────────────────┘
                     │
┌────────────────────┼───────────────────────────────────┐
│ apps Cluster       ↓                                   │
│                                                        │
│  Applications can connect to:                          │
│  - shared-postgres-rw.cnpg-system.svc.cluster.local    │
│  - gitlab-pooler-rw.cnpg-system.svc.cluster.local      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. Infrastructure Requirements

✅ **Kubernetes Version**: 1.28+
✅ **Storage**: OpenEBS (local NVMe) with 500Gi+ available
✅ **Network**: Cilium CNI with ClusterMesh enabled
✅ **Secrets**: External-secrets operator with 1Password integration
✅ **Monitoring**: VictoriaMetrics operator installed
✅ **Certificates**: cert-manager for TLS certificates

### 2. 1Password Secrets

Create the following secrets in 1Password:

| Path | Fields | Description |
|------|--------|-------------|
| `kubernetes/infra/cloudnative-pg/superuser` | `username`, `password` | PostgreSQL superuser |
| `kubernetes/infra/cloudnative-pg/minio` | `accessKey`, `secretKey` | MinIO backup credentials |
| `kubernetes/infra/cloudnative-pg/gitlab` | `username`, `password`, `database` | GitLab database user |
| `kubernetes/infra/cloudnative-pg/harbor` | `username`, `password`, `database` | Harbor database user |
| `kubernetes/infra/cloudnative-pg/mattermost` | `username`, `password`, `database` | Mattermost database user |
| `kubernetes/infra/cloudnative-pg/keycloak` | `username`, `password`, `database` | Keycloak database user |
| `kubernetes/infra/cloudnative-pg/readonly` | `username`, `password` | Read-only analytics user |

Example 1Password item:
```json
{
  "title": "CNPG GitLab Database",
  "vault": "Kubernetes Infra",
  "fields": [
    {"label": "database", "value": "gitlab"},
    {"label": "username", "value": "gitlab_app"},
    {"label": "password", "value": "<generated-password>"}
  ]
}
```

### 3. MinIO Backup Bucket

Ensure MinIO bucket exists:

```bash
# Connect to MinIO
mc alias set minio http://172.16.11.3:9000 <access-key> <secret-key>

# Create bucket
mc mb minio/monosense-cnpg

# Verify
mc ls minio/
```

---

## Deployment Steps

### Phase 1: Install CRDs (Bootstrap)

**Duration:** 5 minutes
**Risk:** Low

1. **Add CNPG CRDs to bootstrap:**

```bash
# CRDs are already added to bootstrap/helmfile.d/00-crds.yaml
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | \
  yq ea 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply -f -
```

2. **Verify CRDs:**

```bash
kubectl get crds | grep cnpg
# Expected output:
# backups.postgresql.cnpg.io
# clusters.postgresql.cnpg.io
# poolers.postgresql.cnpg.io
# scheduledbackups.postgresql.cnpg.io
```

### Phase 2: Deploy CNPG Operator

**Duration:** 10 minutes
**Risk:** Low

1. **Operator is deployed via Flux infrastructure layer:**

```bash
# Verify HelmRepository
kubectl get helmrepository -n flux-system cloudnative-pg

# Verify HelmRelease
kubectl get helmrelease -n cnpg-system cloudnative-pg

# Check operator pods
kubectl get pods -n cnpg-system
# Expected: 2 pods (HA)
```

2. **Verify operator health:**

```bash
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=50
# Should see: "Starting CloudNativePG operator"
```

### Phase 3: Deploy Shared Cluster

**Duration:** 15 minutes
**Risk:** Low (new cluster, not in use)

1. **Flux will deploy shared-cluster automatically:**

```bash
# Watch cluster creation
kubectl get clusters.postgresql.cnpg.io -n cnpg-system -w

# Wait for cluster to be ready
kubectl wait --for=condition=Ready cluster/shared-postgres -n cnpg-system --timeout=10m
```

2. **Verify cluster status:**

```bash
kubectl get pods -n cnpg-system -l cnpg.io/cluster=shared-postgres
# Expected: 3 pods (1 primary, 2 replicas)

# Check cluster details
kubectl cnpg status shared-postgres -n cnpg-system
```

3. **Verify backups:**

```bash
# Check scheduled backup
kubectl get scheduledbackup -n cnpg-system

# Trigger manual backup (optional)
kubectl cnpg backup shared-postgres -n cnpg-system --immediate

# Verify backup in MinIO
mc ls minio/monosense-cnpg/shared-postgres/
```

### Phase 4: Deploy PgBouncer Poolers

**Duration:** 10 minutes
**Risk:** Low

1. **Flux deploys poolers automatically:**

```bash
# Watch pooler creation
kubectl get poolers -n cnpg-system -w

# Verify pooler pods
kubectl get pods -n cnpg-system -l cnpg.io/poolerName
# Expected: 3 pods per pooler (gitlab, harbor, mattermost, keycloak)
```

2. **Test pooler connectivity:**

```bash
# Port-forward to gitlab pooler
kubectl port-forward -n cnpg-system svc/gitlab-pooler-rw 5432:5432

# Connect via psql (in another terminal)
psql -h localhost -p 5432 -U gitlab_app -d gitlab
```

### Phase 5: Verify Monitoring

**Duration:** 5 minutes
**Risk:** None

1. **Check PodMonitors:**

```bash
kubectl get podmonitor -n cnpg-system
# Expected: shared-postgres, gitlab-pooler, harbor-pooler, etc.
```

2. **Check PrometheusRules:**

```bash
kubectl get prometheusrule -n cnpg-system
# Expected: cloudnative-pg-operator, shared-postgres-alerts
```

3. **Query metrics:**

```bash
# Port-forward to VictoriaMetrics
kubectl port-forward -n victoria-metrics svc/vmselect-victoria-metrics-stack 8481:8481

# Query CNPG metrics
curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=cnpg_pg_postmaster_start_time'
```

---

## Migration from Legacy gitlab-postgres

### Strategy: Blue-Green with Logical Replication

**Objective:** Zero-downtime migration from `gitlab-postgres` to `shared-postgres`

**Duration:** 4-6 hours (including validation)
**Risk:** Medium (production migration)
**Rollback Time:** < 5 minutes

### Step 1: Preparation (30 minutes)

1. **Backup current gitlab-postgres:**

```bash
kubectl cnpg backup gitlab-postgres -n cnpg-system --immediate
```

2. **Create gitlab database on shared-postgres:**

```bash
# This should already be configured via managed roles
# Verify database exists
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -c "\l gitlab"
```

3. **Verify credentials:**

```bash
kubectl get secret -n cnpg-system gitlab-db-credentials
```

### Step 2: Setup Logical Replication (1 hour)

1. **Enable logical replication on source (gitlab-postgres):**

```bash
kubectl exec -it -n cnpg-system gitlab-postgres-1 -- \
  psql -U postgres -d gitlab <<EOF
-- Create publication
CREATE PUBLICATION gitlab_pub FOR ALL TABLES;

-- Verify
\dRp+
EOF
```

2. **Create subscription on target (shared-postgres):**

```bash
# Get gitlab-postgres connection string
GITLAB_PG_HOST=$(kubectl get svc -n cnpg-system gitlab-postgres-rw -o jsonpath='{.spec.clusterIP}')

kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab <<EOF
-- Create subscription
CREATE SUBSCRIPTION gitlab_sub
  CONNECTION 'host=$GITLAB_PG_HOST port=5432 dbname=gitlab user=gitlab password=<password>'
  PUBLICATION gitlab_pub;

-- Verify
\dRs+
EOF
```

3. **Monitor replication lag:**

```bash
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab -c "SELECT * FROM pg_stat_subscription;"
```

Wait until `last_msg_receipt_time` is < 1 second behind.

### Step 3: Cutover (30 minutes)

1. **Put GitLab in maintenance mode:**

```bash
# This depends on your GitLab deployment
# Example for Helm-based GitLab:
kubectl scale deployment -n gitlab gitlab-webservice --replicas=0
kubectl scale deployment -n gitlab gitlab-sidekiq --replicas=0
```

2. **Wait for final sync:**

```bash
# Ensure replication is caught up
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab -c "SELECT * FROM pg_stat_subscription;"
# lag_bytes should be 0
```

3. **Update GitLab database connection:**

```bash
# Update GitLab database connection to use pooler
# Edit GitLab configuration:
DB_HOST: gitlab-pooler-rw.cnpg-system.svc.cluster.local
DB_PORT: 5432
DB_NAME: gitlab
DB_USER: gitlab_app
DB_PASSWORD: <from gitlab-db-credentials secret>
```

4. **Restart GitLab:**

```bash
kubectl scale deployment -n gitlab gitlab-webservice --replicas=2
kubectl scale deployment -n gitlab gitlab-sidekiq --replicas=1

# Watch for readiness
kubectl get pods -n gitlab -w
```

5. **Verify GitLab functionality:**

```bash
# Test GitLab UI login
# Test git clone/push operations
# Check background jobs
```

### Step 4: Cleanup (7 days later)

After 7-day validation period:

1. **Remove logical replication:**

```bash
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab -c "DROP SUBSCRIPTION gitlab_sub;"
```

2. **Archive old cluster:**

```bash
# Take final backup
kubectl cnpg backup gitlab-postgres -n cnpg-system --immediate

# Delete old cluster (keep manifests for rollback)
kubectl delete cluster gitlab-postgres -n cnpg-system
```

### Rollback Procedure

If issues are detected:

1. **Revert GitLab connection string** to original `gitlab-postgres-rw`
2. **Restart GitLab** pods
3. **Verify** functionality restored
4. **Investigate** issues before retry

---

## Operational Procedures

### Daily Operations

#### Check Cluster Health

```bash
# Cluster status
kubectl cnpg status shared-postgres -n cnpg-system

# Pod status
kubectl get pods -n cnpg-system -l cnpg.io/cluster=shared-postgres

# Check for alerts
kubectl get prometheusrules -n cnpg-system shared-postgres-alerts -o yaml
```

#### Backup Verification

```bash
# List backups
kubectl get backups -n cnpg-system

# Check scheduled backup status
kubectl get scheduledbackup -n cnpg-system

# Verify backup in MinIO
mc ls -r minio/monosense-cnpg/shared-postgres/
```

### Weekly Operations

#### Automated Restore Test

Already configured via ScheduledBackup with automated testing.

```bash
# Review last restore test results
kubectl logs -n cnpg-system -l job-name=shared-postgres-restore-test
```

#### Performance Review

```bash
# Query slow queries via pg_stat_statements
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab <<EOF
SELECT
  query,
  calls,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
EOF
```

### Monthly Operations

#### Vacuum Analysis

```bash
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -d gitlab <<EOF
SELECT
  schemaname,
  relname,
  n_dead_tup,
  n_live_tup,
  last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
EOF
```

#### Certificate Rotation

Automatic via cert-manager. Verify:

```bash
kubectl get certificate -n cnpg-system
# Check READY status and RENEWAL DATE
```

### Quarterly Operations

#### PostgreSQL Minor Version Upgrade

```bash
# Update cluster.yaml
imageName: ghcr.io/cloudnative-pg/postgresql:16.9  # New version

# Commit and let Flux apply
# CNPG performs rolling upgrade automatically
```

#### Disaster Recovery Drill

Full procedure documented in separate DR runbook.

---

## Troubleshooting

### Issue: Cluster Not Starting

**Symptoms:** Pods in CrashLoopBackOff

**Diagnosis:**

```bash
kubectl describe cluster shared-postgres -n cnpg-system
kubectl logs -n cnpg-system shared-postgres-1
```

**Common Causes:**
- PVC not bound (storage issue)
- Secret not found (ExternalSecret failure)
- Resource limits too low

### Issue: Replication Lag High

**Symptoms:** Alert `CNPGReplicationLagHigh`

**Diagnosis:**

```bash
kubectl exec -it -n cnpg-system shared-postgres-1 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**Resolution:**
- Check network connectivity between pods
- Check replica disk I/O performance
- Consider scaling replica resources

### Issue: Backup Failing

**Symptoms:** Alert `CNPGBackupFailed`

**Diagnosis:**

```bash
kubectl get backup -n cnpg-system
kubectl describe backup <backup-name> -n cnpg-system
```

**Common Causes:**
- MinIO credentials incorrect
- MinIO endpoint unreachable
- Insufficient storage space

### Issue: Connection Pool Exhausted

**Symptoms:** Application errors "connection pool full"

**Diagnosis:**

```bash
kubectl exec -it -n cnpg-system gitlab-pooler-rw-0 -- \
  psql -p 6432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
```

**Resolution:**
- Increase `default_pool_size` in Pooler spec
- Check for connection leaks in application
- Scale pooler replicas

---

## References

### Documentation
- [CloudNative-PG Official Docs](https://cloudnative-pg.io/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [PgBouncer Documentation](https://www.pgbouncer.org/)

### Internal Documentation
- Component README: `kubernetes/components/cnpg-database/README.md`
- Architecture Decision Record: `docs/architecture-decision-record.md`
- Security Guide: `docs/security/database-security.md`

### Support
- Platform Team: #platform-engineering Slack
- On-Call Runbook: PagerDuty Integration
- Issue Tracker: GitHub Issues

---

**Document Version:** 1.0
**Next Review:** 2025-11-15
**Owner:** Platform Engineering Team
**Status:** ✅ Production Ready
