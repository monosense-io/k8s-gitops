# DragonflyDB Operations Runbook

**Component:** DragonflyDB (Redis-compatible cache)
**Version:** v1.34.2
**Operator:** v1.3.0
**Namespace:** `dragonfly-system`
**Last Updated:** 2025-11-01

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Daily Operations](#daily-operations)
4. [Monitoring & Alerts](#monitoring--alerts)
5. [Scaling Operations](#scaling-operations)
6. [Backup & Restore](#backup--restore)
7. [Troubleshooting](#troubleshooting)
8. [Performance Tuning](#performance-tuning)
9. [Security](#security)
10. [Disaster Recovery](#disaster-recovery)

---

## Overview

### Purpose
DragonflyDB provides Redis-compatible caching and session storage for platform workloads (GitLab, Harbor, Mattermost).

### Key Features
- **3-node HA cluster** (1 primary + 2 replicas)
- **Automatic failover** via operator
- **Cross-cluster access** via Cilium ClusterMesh
- **Snapshot backups** every 6 hours
- **Memory-efficient** (~30% less than Redis)

### Critical Configuration
```yaml
Image: ghcr.io/dragonflydb/dragonfly:v1.34.2
Replicas: 3
Memory: 1Gi request, 2Gi limit per pod (6Gi total)
CPU: 500m request, 2000m limit per pod
Storage: 10Gi per pod (30Gi total) on openebs-local-nvme
MaxMemory: 1.5Gi (90% of limit for graceful eviction)
Cache Mode: Enabled (eviction-based for cache workloads)
```

---

## Architecture

### Components
```
┌─────────────────────────────────────────────────────┐
│              dragonfly-system namespace             │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ dragonfly-0  │  │ dragonfly-1  │  │dragonfly │ │
│  │  (primary)   │  │  (replica)   │  │    -2    │ │
│  │              │  │              │  │(replica) │ │
│  │ 2Gi / 2 CPU  │  │ 2Gi / 2 CPU  │  │ 2Gi/2CPU │ │
│  │ 10Gi PVC     │  │ 10Gi PVC     │  │ 10Gi PVC │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│         │                 │                 │      │
│         └─────────────────┴─────────────────┘      │
│                          │                         │
│                 ┌────────▼────────┐                │
│                 │ dragonfly-global│                │
│                 │    Service      │                │
│                 │  (ClusterMesh)  │                │
│                 └─────────────────┘                │
└─────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼────────────────┐
          │               │                │
    ┌─────▼──────┐  ┌────▼────┐  ┌───────▼────┐
    │   GitLab   │  │ Harbor  │  │ Mattermost │
    │ (apps NS)  │  │(apps NS)│  │  (apps NS) │
    └────────────┘  └─────────┘  └────────────┘
```

### Replication
- **Primary:** Accepts all writes
- **Replicas:** Async replication from primary
- **Failover:** Automatic promotion on primary failure
- **Replication Lag:** Monitored via Prometheus

---

## Daily Operations

### Check Cluster Status

```bash
# Check Dragonfly CR status
kubectl -n dragonfly-system get dragonfly dragonfly -o wide

# Check pods
kubectl -n dragonfly-system get pods -l app=dragonfly

# Identify primary and replicas
kubectl -n dragonfly-system get pods -l dragonflydb.io/role=primary
kubectl -n dragonfly-system get pods -l dragonflydb.io/role=replica

# Check pod distribution across nodes
kubectl -n dragonfly-system get pods -l app=dragonfly -o wide
```

### Check Service Endpoints

```bash
# Verify service endpoints
kubectl -n dragonfly-system get svc dragonfly-global
kubectl -n dragonfly-system get endpoints dragonfly-global

# Test DNS resolution (from any pod)
nslookup dragonfly-global.dragonfly-system.svc.cluster.local
```

### Monitor Metrics

```bash
# Check metrics endpoint (replace POD_NAME)
kubectl -n dragonfly-system exec dragonfly-0 -- \
  wget -qO- http://localhost:6379/metrics | head -20

# Key metrics to watch
kubectl -n dragonfly-system exec dragonfly-0 -- \
  wget -qO- http://localhost:6379/metrics | grep -E "dragonfly_memory|dragonfly_commands|dragonfly_connected"
```

---

## Monitoring & Alerts

### Prometheus Metrics

Key metrics exposed on port 6379 at `/metrics`:

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `dragonfly_memory_used_bytes` | Current memory usage | >80% (warning), >90% (critical) |
| `dragonfly_disk_used_bytes` | Disk space used | >80% (warning), >90% (critical) |
| `dragonfly_commands_processed_total` | Commands processed | >10k/sec (warning) |
| `dragonfly_connected_clients` | Active connections | Monitor trends |
| `dragonfly_replication_lag_seconds` | Replica lag | >10s (warning) |
| `dragonfly_role` | Instance role (0=replica, 1=primary) | Alert on no primary |

### Active Alerts

9 production alerts configured in `prometheusrule.yaml`:

**Availability:**
- `DragonflyDown` - Instance unreachable for 5m (critical)
- `DragonflyNoPrimary` - No primary for 2m (critical)
- `DragonflyReplicaCountLow` - <3 replicas for 10m (warning)

**Performance:**
- `DragonflyMemoryHigh` - >80% memory for 10m (warning)
- `DragonflyMemoryCritical` - >90% memory for 5m (critical)
- `DragonflyDiskNearFull` - >80% disk for 15m (warning)
- `DragonflyCommandRateHigh` - >10k cmd/s for 10m (warning)

**Replication:**
- `DragonflyReplicationLagHigh` - >10s lag for 5m (warning)
- `DragonflyReplicationBroken` - Primary has no replicas for 5m (critical)

### Query Metrics in VictoriaMetrics

```bash
# Memory usage
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_memory_used_bytes" | jq .

# Commands per second
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=rate(dragonfly_commands_processed_total[5m])" | jq .

# Replication lag
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_replication_lag_seconds" | jq .
```

---

## Scaling Operations

### Vertical Scaling (Resources)

**Update cluster-settings.yaml:**
```yaml
DRAGONFLY_MEMORY_LIMIT: "4Gi"        # Double memory
DRAGONFLY_MAXMEMORY: "3221225472"    # 3Gi (90% of 4Gi)
DRAGONFLY_CPU_LIMIT: "4000m"         # Double CPU
```

**Important:** Update maxmemory proportionally (90% of memory limit)

### Horizontal Scaling (Replicas)

**Not Recommended** - 3 replicas is optimal for:
- HA with quorum (2/3 available during maintenance)
- Replication overhead (primary handles 2 replicas)
- Resource efficiency

**If Needed:**
```yaml
DRAGONFLY_REPLICAS: "5"  # Only if workload justifies it
```

### Storage Expansion

```yaml
DRAGONFLY_DATA_SIZE: "20Gi"  # Per-pod increase
```

**Note:** Requires PVC expansion (supported by OpenEBS local-nvme)

---

## Backup & Restore

### Automated Snapshots

**Configuration:**
```yaml
snapshot:
  dir: /data
  cron: "0 */6 * * *"  # Every 6 hours

args:
  - --dbfilename=dump          # Static filename (prevents disk filling!)
  - --save_schedule=           # Disabled (cron handles snapshots)
```

**Critical:** `--dbfilename=dump` ensures only ONE snapshot file exists (prevents disk exhaustion)

### Manual Backup

```bash
# Trigger snapshot on primary
PRIMARY_POD=$(kubectl -n dragonfly-system get pods \
  -l dragonflydb.io/role=primary -o jsonpath='{.items[0].metadata.name}')

kubectl -n dragonfly-system exec ${PRIMARY_POD} -- \
  redis-cli -a $(kubectl -n dragonfly-system get secret dragonfly-auth \
    -o jsonpath='{.data.password}' | base64 -d) BGSAVE

# Check snapshot status
kubectl -n dragonfly-system exec ${PRIMARY_POD} -- \
  redis-cli -a PASSWORD LASTSAVE

# Verify snapshot file
kubectl -n dragonfly-system exec ${PRIMARY_POD} -- ls -lh /data/
```

### Backup to External Storage

```bash
# Copy snapshot from pod to local
kubectl -n dragonfly-system cp ${PRIMARY_POD}:/data/dump ./dragonfly-backup-$(date +%Y%m%d).dump

# Upload to S3 (example)
aws s3 cp ./dragonfly-backup-$(date +%Y%m%d).dump \
  s3://my-backups/dragonfly/
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl -n dragonfly-system cp ./dragonfly-backup.dump ${PRIMARY_POD}:/data/dump

# Restart pod to load snapshot
kubectl -n dragonfly-system delete pod ${PRIMARY_POD}

# Verify data restored
kubectl -n dragonfly-system exec ${PRIMARY_POD} -- \
  redis-cli -a PASSWORD DBSIZE
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl -n dragonfly-system describe pod dragonfly-0

# Check logs
kubectl -n dragonfly-system logs dragonfly-0 --tail=100

# Common issues:
# - PVC not bound (check storage class)
# - Memory/CPU limits too low
# - Authentication secret missing
# - Image pull failures
```

### High Memory Usage

```bash
# Check current memory
kubectl -n dragonfly-system exec dragonfly-0 -- \
  redis-cli -a PASSWORD INFO memory

# Check eviction stats (cache mode)
kubectl -n dragonfly-system exec dragonfly-0 -- \
  redis-cli -a PASSWORD INFO stats | grep evicted

# Force eviction (if needed)
# Increase maxmemory pressure or reduce data
```

### Replication Lag

```bash
# Check lag on replica
kubectl -n dragonfly-system exec dragonfly-1 -- \
  redis-cli -a PASSWORD INFO replication

# Check primary replication stats
kubectl -n dragonfly-system exec ${PRIMARY_POD} -- \
  redis-cli -a PASSWORD INFO replication | grep lag

# Possible causes:
# - Network issues between pods
# - Primary overloaded (high command rate)
# - Large dataset sync in progress
```

### Connection Issues

```bash
# Test connection from client pod
kubectl -n gitlab-system run -it --rm redis-cli \
  --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local \
    -a PASSWORD PING

# Check NetworkPolicy
kubectl -n dragonfly-system get ciliumnetworkpolicies

# Check ClusterMesh status (for cross-cluster access)
cilium clustermesh status
```

### Disk Space Issues

```bash
# Check PVC usage
kubectl -n dragonfly-system exec dragonfly-0 -- df -h /data

# List snapshot files (should be only ONE file: dump)
kubectl -n dragonfly-system exec dragonfly-0 -- ls -lh /data/

# If multiple snapshot files exist (BAD!):
# - Check --dbfilename=dump is set
# - Manually remove old snapshots
kubectl -n dragonfly-system exec dragonfly-0 -- \
  find /data -name "dump-*" -mtime +7 -delete
```

---

## Performance Tuning

### Thread Configuration

```yaml
args:
  - --proactor_threads=0  # Auto-detect (recommended)
  # Manual: Set to number of CPU cores for fine control
```

### Cache Mode Optimization

```yaml
args:
  - --cache_mode=true           # Enable eviction
  - --maxmemory=1610612736      # 90% of memory limit
```

**When cache is full:**
- Evicts least-recently-used (LRU) keys
- Prevents OOM conditions
- Recommended for GitLab/Harbor cache workloads

### Snapshot Tuning

```yaml
snapshot:
  cron: "0 */6 * * *"  # Every 6 hours (default)
  # Adjust based on data change frequency:
  # - High churn: "0 */2 * * *" (every 2h)
  # - Low churn: "0 0 * * *" (daily)
```

### Connection Pooling

**Client-side recommendations:**
- GitLab: Use Redis Sentinel protocol with primary DNS
- Harbor: Direct connection to dragonfly-global service
- Connection pool size: 10-50 per application instance

---

## Security

### Authentication

```bash
# Password stored in ExternalSecret
kubectl -n dragonfly-system get secret dragonfly-auth

# Rotate password (update 1Password vault)
# ExternalSecret will sync automatically within 1h
```

### Network Policies

**Allowed ingress:**
- `gitlab-system` namespace (GitLab cache)
- `harbor` namespace (Harbor cache)
- `observability` namespace (metrics scraping)

**Denied:** All other namespaces

```bash
# Verify network policy
kubectl -n dragonfly-system get ciliumnetworkpolicies
kubectl -n dragonfly-system describe cnp dragonfly-allow-clients
```

### Pod Security

**PSA Enforcement:** `restricted` level
- Non-root user (UID 10001)
- Read-only root filesystem
- No privilege escalation
- All capabilities dropped

---

## Disaster Recovery

### Scenario: Complete Cluster Loss

1. **Restore from Backup:**
   ```bash
   # Deploy new Dragonfly cluster (Flux will reconcile)
   # Copy latest backup to primary pod
   kubectl -n dragonfly-system cp backup.dump dragonfly-0:/data/dump

   # Restart primary to load data
   kubectl -n dragonfly-system delete pod dragonfly-0
   ```

2. **Verify Data:**
   ```bash
   # Check key count
   kubectl -n dragonfly-system exec dragonfly-0 -- \
     redis-cli -a PASSWORD DBSIZE

   # Sample keys
   kubectl -n dragonfly-system exec dragonfly-0 -- \
     redis-cli -a PASSWORD KEYS '*' | head -10
   ```

3. **Verify Replication:**
   ```bash
   # Wait for replicas to sync
   kubectl -n dragonfly-system get pods -w

   # Check replication status
   kubectl -n dragonfly-system exec dragonfly-0 -- \
     redis-cli -a PASSWORD INFO replication
   ```

### Scenario: Primary Failure

**Automatic Failover:**
- Operator promotes replica to primary
- Service endpoint updates automatically
- No manual intervention needed

**Verify failover:**
```bash
# Check new primary
kubectl -n dragonfly-system get pods -l dragonflydb.io/role=primary

# Verify service points to new primary
kubectl -n dragonfly-system describe svc dragonfly-global
```

### Scenario: Data Corruption

```bash
# 1. Stop writes (drain applications)
# 2. Restore from last known good backup
# 3. Verify data integrity
# 4. Resume application traffic
```

---

## Emergency Contacts

| Role | Responsibility | Escalation |
|------|---------------|------------|
| **Platform Team** | First responder | Slack: #platform-ops |
| **SRE On-Call** | Critical incidents | PagerDuty |
| **Database Team** | Data recovery | Slack: #database-ops |

---

## References

- [DragonflyDB Official Docs](https://www.dragonflydb.io/docs)
- [Kubernetes Operator Docs](https://www.dragonflydb.io/docs/managing-dragonfly/operator)
- [Story 25: Implementation](../../docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md)
- [Monitoring Dashboards](http://grafana.observability.svc.cluster.local)

---

**Document Version:** 1.0
**Last Review:** 2025-11-01
**Next Review:** 2025-12-01
