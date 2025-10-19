# Rook-Ceph Backup and Disaster Recovery Guide

This document outlines the backup strategy, disaster recovery procedures, and recovery runbooks for the Rook-Ceph cluster deployed on the infra Kubernetes cluster.

## Table of Contents

1. [Overview](#overview)
2. [Backup Strategy](#backup-strategy)
3. [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
4. [Recovery Procedures](#recovery-procedures)
5. [Testing and Validation](#testing-and-validation)
6. [Monitoring and Alerting](#monitoring-and-alerting)

---

## Overview

### Cluster Information

- **Cluster Name**: rook-ceph
- **Namespace**: rook-ceph
- **Storage Class**: rook-ceph-block
- **Replication Factor**: 3 (default)
- **Monitor Count**: 3
- **OSD Devices**: 3 NVMe SSDs (one per node)

### Backup Objectives

- **RPO (Recovery Point Objective)**: < 1 hour
- **RTO (Recovery Time Objective)**: < 4 hours
- **Data Retention**: 30 days minimum

---

## Backup Strategy

### 1. Ceph Cluster State Backups

#### A. Configuration Backup

**Frequency**: Daily (automated via scheduled jobs)

**What to backup**:
- Ceph configuration files (`/etc/ceph/ceph.conf`)
- Keyring files (admin, mon, osd)
- Crush maps
- Pool definitions
- OSD crush weights

**Backup Method**:

```bash
#!/bin/bash
# Backup Ceph cluster configuration
BACKUP_DIR="/backups/ceph-config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p ${BACKUP_DIR}/${TIMESTAMP}

# Export crush map
ceph osd getcrushmap -o ${BACKUP_DIR}/${TIMESTAMP}/crushmap.bin

# Export configuration
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l app=rook-ceph-mon -o jsonpath='{.items[0].metadata.name}') \
  -- ceph config generate-minimal-conf > ${BACKUP_DIR}/${TIMESTAMP}/ceph.conf

# Export pool definitions
for pool in $(ceph osd pool ls); do
  ceph osd pool get ${pool} all > ${BACKUP_DIR}/${TIMESTAMP}/pool_${pool}.json
done

# Compress backup
tar -czf ${BACKUP_DIR}/ceph-config-${TIMESTAMP}.tar.gz ${BACKUP_DIR}/${TIMESTAMP}
rm -rf ${BACKUP_DIR}/${TIMESTAMP}

# Upload to S3/object storage
aws s3 cp ${BACKUP_DIR}/ceph-config-${TIMESTAMP}.tar.gz s3://backups-bucket/ceph-config/
```

#### B. Cluster Manifest Backup

**Frequency**: Per deployment (captured in Git)

**What to backup**:
- CephCluster custom resource
- CephBlockPool definitions
- StorageClass definitions
- NetworkPolicy rules
- ServiceMonitor configurations

**Backup Method**: All manifests are version-controlled in the Git repository at:
```
kubernetes/infrastructure/storage/rook-ceph/
kubernetes/bases/rook-ceph-cluster/
```

**Recovery**: Reapply manifests via Flux

```bash
# Force Flux reconciliation
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization storage -n flux-system
```

### 2. Volume Data Backups

#### A. RBD Volume Snapshots

**Frequency**: Hourly (configurable per application)

**Tool**: VolumeSnapshot CRD with `ceph-block-snapshot` class

**Example Snapshot Creation**:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: app-db-snapshot-001
  namespace: default
spec:
  volumeSnapshotClassName: ceph-block-snapshot
  source:
    persistentVolumeClaimName: app-db-pvc
```

**Snapshot Retention**: Managed by application namespace policies

**Recovery from Snapshot**:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-db-restored
  namespace: default
spec:
  storageClassName: rook-ceph-block
  dataSource:
    name: app-db-snapshot-001
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

#### B. CloudNative-PG Backups

CloudNative-PG instances in the platform namespace use S3 backups configured via:
- **Backup Bucket**: monosense-cnpg (in Ceph RGW or external S3)
- **Schedule**: 0 2 * * * (Daily at 2 AM UTC)

Recovery from CNPG backups is documented in the CloudNative-PG section.

---

## Disaster Recovery Scenarios

### Scenario 1: Single OSD Failure

**Severity**: Low
**Expected Impact**: Degraded performance, recovery in progress
**Recovery Time**: 30-60 minutes

#### Symptoms:
```bash
ceph health detail
# Output: HEALTH_WARN: 1 osds down
# Output: Degraded data ...
```

#### Automatic Recovery:
1. Kubernetes detects pod failure
2. Rook operator respins OSD pod on same or different node
3. Ceph cluster automatically rebalances PGs to healthy OSDs
4. Monitor with: `ceph health` and `ceph osd tree`

#### Manual Intervention (if needed):

```bash
# List failed OSDs
ceph osd tree | grep down

# Mark OSD out if stuck
ceph osd out osd.X

# Remove OSD from cluster
ceph osd purge osd.X --yes-i-really-mean-it

# Wipe device
talosctl -n <node-ip> wipe disk --method FAST nvmeXnY

# Rook will auto-recreate OSD on available device
```

---

### Scenario 2: Single Node Failure

**Severity**: Medium
**Expected Impact**: Unavailability of volumes on affected node, cluster rebalance
**Recovery Time**: 60-120 minutes

#### Symptoms:
- OSDs on failed node offline
- Kubernetes evacuates all pods
- PVCs become pending

#### Recovery Steps:

1. **Identify failed node**:
```bash
kubectl get nodes
# Look for NotReady status
```

2. **Check cluster health**:
```bash
ceph health detail
ceph osd tree
```

3. **Wait for automatic rebalance** (do not force):
- Rook detects missing OSDs
- Ceph marks OSDs down after 300 seconds (configurable)
- Rebalancing begins automatically
- Replicas are rebuilt from other OSDs

4. **Monitor progress**:
```bash
watch ceph health
watch 'ceph osd tree | grep -E "(down|up)"'
```

5. **Replace failed node**:
```bash
# Wipe disks on replacement node
talosctl -n <new-node-ip> wipe disk --method FAST nvme0n1

# Node will join cluster and Ceph will replicate data
```

---

### Scenario 3: MON Quorum Loss (2 of 3 monitors down)

**Severity**: Critical
**Expected Impact**: Cluster read-only or offline
**Recovery Time**: Immediate (after starting failed monitors)

#### Symptoms:
```bash
ceph health detail
# Output: HEALTH_WARN: no monitors available, retrying
# Output: HEALTH_ERR: 2 mons down
```

#### Recovery Steps:

1. **Check Mon pod status**:
```bash
kubectl -n rook-ceph get pods -l app=rook-ceph-mon
```

2. **If pods are crashing**:
```bash
# Check logs
kubectl -n rook-ceph logs -f deployment/rook-ceph-mon-a

# Restart pod
kubectl -n rook-ceph delete pod rook-ceph-mon-a-0
# Rook will respawn it
```

3. **Force mon restart** (last resort):
```bash
# Delete all mon pods
kubectl -n rook-ceph delete pods -l app=rook-ceph-mon

# Rook will recreate them
# Monitor with: kubectl -n rook-ceph get pods -l app=rook-ceph-mon --watch
```

4. **Verify quorum restored**:
```bash
ceph mon stat
# Output: e2: 3 mons at {a=<ip>:6789/0, b=<ip>:6789/0, c=<ip>:6789/0}, quorum 0,1,2
```

---

### Scenario 4: Complete Cluster Loss

**Severity**: Critical
**Expected Impact**: Total data loss (unless backups exist)
**Recovery Time**: 2-4 hours for full restoration

#### Symptoms:
- All Ceph pods offline
- No Ceph services responding
- Cluster completely unavailable

#### Prevention:
- Maintain offsite backups of critical data
- Test disaster recovery procedures monthly
- Keep configuration backups in Git

#### Recovery Procedure:

1. **Assess cluster state**:
```bash
ceph health
# Likely: HEALTH_ERR: unable to check health, no mon available
```

2. **Option A: Full cluster restore from backup**

   a. **Wipe all devices**:
   ```bash
   for node in infra-01 infra-02 infra-03; do
     talosctl -n <node-ip> wipe disk --method FAST nvme*
   done
   ```

   b. **Restore configuration**:
   ```bash
   # Extract backed-up configuration
   tar -xzf ceph-config-<timestamp>.tar.gz

   # Restore crush map
   kubectl -n rook-ceph exec -it <mon-pod> -- ceph osd setcrushmap -i crushmap.bin

   # Recreate pools
   kubectl -n rook-ceph exec -it <mon-pod> -- ceph osd pool create <pool-name> <pg-num>
   ```

   c. **Restore manifests**:
   ```bash
   # Rollback to last known good Git commit
   git checkout <commit-id>

   # Flux will reconcile and recreate Ceph cluster
   flux reconcile kustomization storage -n flux-system
   ```

   d. **Monitor recovery**:
   ```bash
   watch ceph health
   # Will show: HEALTH_OK after all PGs are active+clean
   ```

3. **Option B: Accept data loss and start fresh** (if backups not available)

   a. Delete CephCluster resource:
   ```bash
   kubectl -n rook-ceph delete cephcluster rook-ceph
   ```

   b. Wipe all devices:
   ```bash
   for node in infra-01 infra-02 infra-03; do
     talosctl -n <node-ip> wipe disk --method FAST nvme*
   done
   ```

   c. Recreate cluster:
   ```bash
   # Recreate via Flux
   flux reconcile kustomization storage -n flux-system --with-source
   ```

---

## Recovery Procedures

### Procedure 1: Restore Volume from Snapshot

**Objective**: Recover a PVC from a VolumeSnapshot

```bash
# 1. List available snapshots
kubectl get volumesnapshots -n <app-namespace>

# 2. Create new PVC from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-volume
  namespace: <app-namespace>
spec:
  storageClassName: rook-ceph-block
  dataSource:
    name: <snapshot-name>
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: <size>Gi
EOF

# 3. Verify PVC is bound
kubectl get pvc restored-volume -n <app-namespace>

# 4. Attach to pod and verify data
kubectl run -it --rm debug --image=ubuntu:latest --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"restored-volume"}}],"containers":[{"name":"debug","image":"ubuntu:latest","volumeMounts":[{"mountPath":"/data","name":"vol"}],"stdin":true,"tty":true}]}}' bash
```

### Procedure 2: Migrate Volume to New Cluster

**Objective**: Move a Ceph volume to a different Rook-Ceph cluster

```bash
# 1. Create snapshot in source cluster
kubectl -n rook-ceph get volumesnapshot
kubectl exec -it <mon-pod> -n rook-ceph -- rbd snap create <image>@migration-snap

# 2. Export volume
rbd export <pool>/<image>@migration-snap image-export.img

# 3. Import into target cluster
rbd import image-export.img <target-pool>/<new-image>

# 4. Create PVC in target cluster
# (same procedure as Restore from Snapshot)
```

### Procedure 3: Rebuild Failed OSD

**Objective**: Replace a failed OSD with a new one

```bash
# 1. Identify failed device
ceph osd tree | grep down

# 2. Mark OSD out
ceph osd out osd.X

# 3. Wipe device on target node
talosctl -n <node-ip> wipe disk --method FAST nvmeXnY

# 4. Verify wipe
talosctl -n <node-ip> ls -la /dev/ | grep nvme

# 5. Rook auto-detects and creates new OSD
kubectl -n rook-ceph get pods | grep osd

# 6. Monitor recovery
watch ceph health
```

---

## Testing and Validation

### Monthly Disaster Recovery Drill

```bash
#!/bin/bash
# Monthly backup restoration test

echo "=== Monthly Disaster Recovery Drill ==="
echo "Date: $(date)"

# 1. Verify backup existence
echo "✓ Checking backups..."
aws s3 ls s3://backups-bucket/ceph-config/ | tail -1

# 2. Test config restore on staging cluster
echo "✓ Testing configuration restore..."
tar -tzf $(ls -t /backups/ceph-config/*.tar.gz | head -1) | head -10

# 3. Verify Git history for manifests
echo "✓ Checking Git history..."
git log --oneline kubernetes/infrastructure/storage/rook-ceph/ | head -5

# 4. Test volume snapshot restore
echo "✓ Testing snapshot restore..."
kubectl get volumesnapshots --all-namespaces | wc -l

echo "=== Drill Complete ==="
```

### Health Checks

```bash
# Daily health verification
ceph health detail
ceph osd tree
ceph status

# MON quorum status
ceph mon stat

# OSD status
ceph osd ls-tree

# Pool and PG status
ceph df
ceph pg stat

# Volume replication
kubectl -n rook-ceph exec -it <mon-pod> -- ceph -s
```

---

## Monitoring and Alerting

### PrometheusRules

Alerting rules are defined in:
- `kubernetes/infrastructure/storage/rook-ceph/cluster/prometheusrule.yaml`
- `kubernetes/infrastructure/storage/rook-ceph/operator/prometheusrule.yaml`

### Critical Alerts

| Alert | Severity | Recovery Action |
|-------|----------|-----------------|
| CephHealthError | Critical | Follow Scenario 3-4 procedures |
| CephMonQuorumAtRisk | Warning | Replace failed MON node |
| CephOSDCriticallyFull | Critical | Add capacity or evict data |
| CephPGsDegraded | Warning | Allow automatic rebalance |
| CephOSDDown | Warning | Check node/pod status, follow Scenario 1 |

### Dashboard Access

```bash
# Get MGR pod
kubectl -n rook-ceph get pod -l app=rook-ceph-mgr

# Access dashboard
kubectl -n rook-ceph port-forward svc/rook-ceph-mgr-dashboard 8443:8443

# Get admin password
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath='{.data.password}' | base64 -d

# Access: https://localhost:8443
```

---

## Contact and Escalation

- **On-Call**: Check PagerDuty for current on-call engineer
- **Slack**: #platform-incidents
- **Critical Issues**: Escalate to Platform Lead
- **Documentation**: See `kubernetes/infrastructure/storage/` for implementation guides

---

## Appendix: Useful Commands

```bash
# Ceph Status
ceph health detail
ceph -s
ceph osd tree
ceph pg stat

# Monitor Rook
kubectl -n rook-ceph get all
kubectl -n rook-ceph logs -f deployment/rook-ceph-operator

# Volume Management
kubectl get pvc --all-namespaces
kubectl get volumesnapshots --all-namespaces

# Disk Operations
talosctl -n <ip> ls /dev/ | grep nvme
talosctl -n <ip> lsblk

# Backup Operations
aws s3 ls s3://backups-bucket/
aws s3 sync s3://backups-bucket/ceph-config/ /local/backup/path/
```

---

**Last Updated**: $(date +%Y-%m-%d)
**Maintained By**: Platform Team
**Next Review**: 30 days from now
