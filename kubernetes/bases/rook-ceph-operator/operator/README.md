# Rook-Ceph Operator

The Rook-Ceph operator manages Ceph storage clusters on Kubernetes, providing automated lifecycle management for distributed, highly-available storage. This operator is **shared across both infra and apps clusters** in your k8s-gitops repository.

## 📊 Overview

**Chart Version**: v1.18.6 (October 2024 - Latest Stable)
**Ceph Version**: v19.2.3 (Squid release)
**Repository**: https://charts.rook.io/release
**Namespace**: `rook-ceph`
**Deployment Pattern**: Shared operator manifests, cluster-specific CephCluster resources

---

## 🏗️ Your GitOps Architecture

### Directory Structure

```
kubernetes/
├── bases/rook-ceph-operator/operator/       # ← YOU ARE HERE (shared operator)
│   ├── helmrelease.yaml                     # Operator deployment (HelmRelease)
│   ├── prometheusrule.yaml                  # 6 operator alerts
│   ├── podmonitor.yaml                      # Metrics scraping
│   ├── kustomization.yaml                   # Kustomize base
│   └── README.md                            # This file
│
├── infrastructure/storage/rook-ceph/
│   ├── operator/
│   │   └── ks.yaml                          # Flux Kustomization (deploys operator)
│   └── cluster/
│       ├── ks.yaml                          # Flux Kustomization (deploys cluster)
│       ├── cephcluster.yaml                 # CephCluster CR (MON, MGR, OSD)
│       ├── cephblockpool.yaml               # rook-ceph-block pool
│       ├── storageclass.yaml                # StorageClass definition
│       ├── toolbox.yaml                     # Ceph toolbox pod
│       ├── prometheusrule.yaml              # Cluster-level alerts
│       └── kustomization.yaml
│
└── clusters/
    ├── infra/
    │   ├── cluster-settings.yaml            # Infra cluster config
    │   └── infrastructure.yaml              # References ./kubernetes/infrastructure
    └── apps/
        ├── cluster-settings.yaml            # Apps cluster config
        └── infrastructure.yaml              # References ./kubernetes/infrastructure
```

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Flux watches git repository                                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. cluster-{infra,apps}-infrastructure Kustomization           │
│    path: ./kubernetes/infrastructure                            │
│    postBuild.substituteFrom: cluster-settings                   │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. rook-ceph-operator Kustomization                             │
│    path: ./kubernetes/bases/rook-ceph-operator/operator         │
│    healthChecks: HelmRelease, Deployment                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Operator HelmRelease creates:                                │
│    - Operator Deployment (1 replica)                            │
│    - CSI RBD Provisioner (2 replicas)                           │
│    - CSI CephFS Provisioner (2 replicas)                        │
│    - Discovery DaemonSet (all nodes)                            │
│    - ValidatingWebhookConfiguration                             │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. rook-ceph-cluster Kustomization (depends on operator)        │
│    path: ./kubernetes/infrastructure/storage/rook-ceph/cluster  │
│    postBuild.substituteFrom: cluster-settings                   │
│    healthChecks: CephCluster, CephBlockPool                     │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. CephCluster CR creates:                                      │
│    - 3x MON pods (quorum)                                       │
│    - 2x MGR pods (active/standby)                               │
│    - Nx OSD pods (per disk)                                     │
│    - Toolbox pod (ceph CLI access)                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Configuration

### Operator Configuration (Hardcoded)

**File**: `kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml`

```yaml
spec:
  chart:
    spec:
      chart: rook-ceph
      version: v1.18.6  # ← Hardcoded (stable operator version)
  values:
    crds:
      enabled: true

    resources:
      limits: {cpu: 500m, memory: 512Mi}
      requests: {cpu: 100m, memory: 128Mi}

    logLevel: INFO  # ← Hardcoded (INFO for production)

    monitoring:
      enabled: true

    csi:
      enableCSIHostNetwork: true  # Required for Talos Linux
      provisionerReplicas: 2       # HA configuration

    enableDiscoveryDaemon: true
    discoveryDaemonResources:
      limits: {cpu: 200m, memory: 128Mi}
      requests: {cpu: 50m, memory: 64Mi}
```

**Why Hardcoded?**
Operators are foundational infrastructure. Hardcoded values ensure stability and prevent accidental configuration drift. Cluster resources (CephCluster, pools) use variables for per-cluster flexibility.

### cluster-settings Variables (Documentation Only)

Both `kubernetes/clusters/infra/cluster-settings.yaml` and `kubernetes/clusters/apps/cluster-settings.yaml` define:

```yaml
# Rook-Ceph Operator Configuration (DOCUMENTATION ONLY - not used for templating)
ROOK_CEPH_OPERATOR_VERSION: "v1.18.6"    # Documents current chart version
ROOK_CEPH_OPERATOR_REPLICAS: "1"         # Documents operator replica count
ROOK_CEPH_LOG_LEVEL: "INFO"              # Documents log level
ROOK_CEPH_CSI_ENABLE_RBD: "true"         # Documents RBD driver enabled
ROOK_CEPH_CSI_ENABLE_CEPHFS: "true"      # Documents CephFS driver enabled
ROOK_CEPH_CSI_LOG_LEVEL: "3"             # Documents CSI log level

# Ceph Cluster Configuration (ACTIVELY USED via postBuild substitution)
ROOK_CEPH_NAMESPACE: "rook-ceph"
ROOK_CEPH_CLUSTER_NAME: "rook-ceph"
ROOK_CEPH_IMAGE_TAG: "v19.2.3"           # ← Used in cephcluster.yaml
ROOK_CEPH_MON_COUNT: "3"                 # ← Used in cephcluster.yaml
ROOK_CEPH_OSD_DEVICE_CLASS: "ssd"        # ← Used in cephcluster.yaml
ROOK_CEPH_BLOCKPOOL_NAME: "rook-ceph-block"
BLOCK_SC: "rook-ceph-block"
```

**Important**: Only cluster resources (`cephcluster.yaml`, `cephblockpool.yaml`, etc.) use variable substitution via `postBuild.substituteFrom`. Operator HelmRelease values are hardcoded.

---

## 🔧 Operations & Runbooks

### Checking Operator Status

#### View Flux Kustomization

```bash
# Check operator Kustomization status
flux get kustomization rook-ceph-operator -n flux-system

# Check cluster Kustomization status
flux get kustomization rook-ceph-cluster -n flux-system

# Watch all Rook Kustomizations
flux get kustomizations -A | grep rook
```

#### View HelmRelease

```bash
# Check operator HelmRelease status
kubectl get helmrelease -n rook-ceph rook-ceph-operator

# Describe HelmRelease for details
kubectl describe helmrelease -n rook-ceph rook-ceph-operator

# Get HelmRelease YAML
kubectl get helmrelease -n rook-ceph rook-ceph-operator -o yaml
```

#### View Operator Pod

```bash
# Check operator deployment
kubectl get deployment -n rook-ceph rook-ceph-operator

# Check operator pods
kubectl get pod -n rook-ceph -l app=rook-ceph-operator

# View operator logs
kubectl logs -n rook-ceph deploy/rook-ceph-operator --tail=100 -f

# Check operator image version
kubectl get deployment -n rook-ceph rook-ceph-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Checking CSI Drivers

#### RBD Driver (Block Storage)

```bash
# Check RBD provisioner deployment
kubectl get deployment -n rook-ceph csi-rbdplugin-provisioner

# Check RBD provisioner pods
kubectl get pod -n rook-ceph -l app=csi-rbdplugin-provisioner

# View RBD provisioner logs
kubectl logs -n rook-ceph deploy/csi-rbdplugin-provisioner -c csi-provisioner

# Check RBD node plugin (runs on all nodes)
kubectl get daemonset -n rook-ceph csi-rbdplugin

# View RBD node plugin logs
kubectl logs -n rook-ceph ds/csi-rbdplugin -c csi-rbdplugin --tail=50
```

#### CephFS Driver (Filesystem Storage)

```bash
# Check CephFS provisioner deployment
kubectl get deployment -n rook-ceph csi-cephfsplugin-provisioner

# Check CephFS provisioner pods
kubectl get pod -n rook-ceph -l app=csi-cephfsplugin-provisioner

# View CephFS provisioner logs
kubectl logs -n rook-ceph deploy/csi-cephfsplugin-provisioner -c csi-provisioner

# Check CephFS node plugin
kubectl get daemonset -n rook-ceph csi-cephfsplugin
```

### Checking Discovery Daemon

```bash
# Check discovery daemon DaemonSet
kubectl get daemonset -n rook-ceph rook-discover

# Check discovery daemon pods (should be on all nodes)
kubectl get pod -n rook-ceph -l app=rook-discover

# View discovered devices ConfigMap
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml

# View discovery daemon logs
kubectl logs -n rook-ceph ds/rook-discover --tail=100
```

### Checking Ceph Cluster Status

```bash
# Check CephCluster CR
kubectl get cephcluster -n rook-ceph

# Describe CephCluster for status
kubectl describe cephcluster -n rook-ceph rook-ceph

# Check Ceph health via toolbox
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status

# Check Ceph cluster details
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail

# Check OSD status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd status

# Check pool usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df

# Check MON quorum
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph mon stat
```

### Force Flux Reconciliation

```bash
# Force operator reconciliation
flux reconcile kustomization rook-ceph-operator -n flux-system --with-source

# Force cluster reconciliation
flux reconcile kustomization rook-ceph-cluster -n flux-system --with-source

# Force HelmRelease reconciliation
flux reconcile helmrelease rook-ceph-operator -n rook-ceph --with-source

# Reconcile entire infrastructure stack
flux reconcile kustomization cluster-infra-infrastructure -n flux-system --with-source
```

### Debugging PVC Issues

#### PVC Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -A | grep Pending

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check if StorageClass exists
kubectl get storageclass rook-ceph-block

# Check CephBlockPool exists
kubectl get cephblockpool -n rook-ceph rook-ceph-block

# Check CSI provisioner logs
kubectl logs -n rook-ceph deploy/csi-rbdplugin-provisioner -c csi-provisioner --tail=100

# Check Ceph pool capacity
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool stats rook-ceph-block
```

#### Volume Mount Failures

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check CSI node plugin logs on the node
kubectl logs -n rook-ceph ds/csi-rbdplugin -c csi-rbdplugin --tail=100

# Check if RBD kernel module loaded
kubectl exec -n rook-ceph ds/csi-rbdplugin -c driver-registrar -- lsmod | grep rbd

# Test Ceph connectivity from toolbox
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph mon dump

# Check Ceph authentication secrets
kubectl get secret -n rook-ceph | grep csi
```

### Node Disk Preparation

#### Check Node Disks (via Talos)

```bash
# SSH into node or use talosctl
talosctl -n <node-ip> disks

# Check block devices
kubectl debug node/<node-name> -it --image=busybox -- lsblk

# Check for existing filesystems
kubectl debug node/<node-name> -it --image=busybox -- blkid
```

#### Clean Disks for Ceph (Talos)

**⚠️ WARNING: This destroys all data on the disk!**

```bash
# Via talosctl
talosctl -n <node-ip> reset --graceful=false --reboot --system-labels-to-wipe STATE,EPHEMERAL

# Or manually via debug pod
kubectl debug node/<node-name> -it --image=alpine -- sh

# Inside debug pod
apk add util-linux parted
wipefs --all /dev/nvme0n1
sgdisk --zap-all /dev/nvme0n1
```

#### Verify Disk Detected

```bash
# Check discovery daemon found the disk
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml

# Force rediscovery
kubectl delete pod -n rook-ceph -l app=rook-discover
```

---

## 🔄 Upgrade Procedures

### Upgrading the Operator

**Procedure**:

1. **Edit HelmRelease** locally:
   ```bash
   # Edit file
   vim kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml

   # Change version line 30:
   #   version: v1.18.6 → v1.19.0
   ```

2. **Update cluster-settings** documentation:
   ```bash
   # Edit both cluster-settings files
   vim kubernetes/clusters/infra/cluster-settings.yaml
   vim kubernetes/clusters/apps/cluster-settings.yaml

   # Change line 77 (infra) / line 75 (apps):
   #   ROOK_CEPH_OPERATOR_VERSION: "v1.19.0"
   ```

3. **Commit and push**:
   ```bash
   git add kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml \
           kubernetes/clusters/infra/cluster-settings.yaml \
           kubernetes/clusters/apps/cluster-settings.yaml

   git commit -m "chore(storage): upgrade Rook operator v1.18.6 → v1.19.0"
   git push
   ```

4. **Monitor Flux reconciliation**:
   ```bash
   # Watch Flux apply changes
   flux get kustomizations -A --watch

   # Or force immediate reconciliation
   flux reconcile kustomization rook-ceph-operator -n flux-system --with-source
   ```

5. **Verify operator upgraded**:
   ```bash
   kubectl get deployment -n rook-ceph rook-ceph-operator \
     -o jsonpath='{.spec.template.spec.containers[0].image}'

   kubectl get pod -n rook-ceph -l app=rook-ceph-operator
   ```

### Upgrading Ceph Version

**Prerequisites**:
- Operator already upgraded to compatible version
- Cluster must be HEALTH_OK
- All PGs active+clean
- No backfilling or recovery in progress

**Procedure**:

1. **Verify cluster health**:
   ```bash
   kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
   kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail
   ```

2. **Edit CephCluster CR**:
   ```bash
   vim kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml

   # Change spec.cephVersion.image:
   #   image: quay.io/ceph/ceph:${ROOK_CEPH_IMAGE_TAG}
   ```

3. **Update cluster-settings**:
   ```bash
   vim kubernetes/clusters/infra/cluster-settings.yaml
   vim kubernetes/clusters/apps/cluster-settings.yaml

   # Change ROOK_CEPH_IMAGE_TAG:
   #   ROOK_CEPH_IMAGE_TAG: v19.2.4
   ```

4. **Commit and push**:
   ```bash
   git add kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml \
           kubernetes/clusters/infra/cluster-settings.yaml \
           kubernetes/clusters/apps/cluster-settings.yaml

   git commit -m "chore(storage): upgrade Ceph v19.2.3 → v19.2.4"
   git push
   ```

5. **Monitor upgrade progress**:
   ```bash
   # Watch CephCluster phase
   kubectl get cephcluster -n rook-ceph -w

   # Monitor Ceph status during upgrade
   watch kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status

   # Check operator logs
   kubectl logs -n rook-ceph deploy/rook-ceph-operator -f
   ```

**Upgrade Order** (automatic, handled by operator):
1. MON (monitors) - one at a time, wait for quorum
2. MGR (managers) - one at a time, wait for active mgr
3. OSD (storage daemons) - one at a time per failure domain
4. MDS (metadata servers) - if using CephFS
5. RGW (object gateways) - if using object storage

---

## 📊 Monitoring & Alerting

### Metrics Endpoints

**Operator Metrics**: `http://rook-ceph-operator.rook-ceph.svc.cluster.local:9090/metrics`

**PodMonitor**: `kubernetes/bases/rook-ceph-operator/operator/podmonitor.yaml`
- Scrape interval: 30s
- Scrape timeout: 10s
- Port: http-metrics (9090)

### Configured Alerts

**File**: `kubernetes/bases/rook-ceph-operator/operator/prometheusrule.yaml`

| Alert | Severity | Trigger | For | Description |
|-------|----------|---------|-----|-------------|
| `RookCephOperatorDown` | critical | `up{job="rook-ceph-operator"} == 0` | 5m | Operator pod unavailable |
| `RookCephOperatorReconcileErrors` | warning | `increase(rook_ceph_operator_reconcile_errors_total[5m]) > 0` | 10m | CRD reconciliation failures |
| `RookCephCRDMissing` | critical | CRD not registered in API server | 5m | Rook CRDs missing |
| `RookCephDiscoveryDaemonDown` | warning | `up{job="rook-ceph-discovery"} == 0` | 10m | Discovery daemon issues |
| `RookCephOperatorCrashLooping` | warning | Pod restart rate > 0 | 5m | Operator restarting frequently |
| `RookCephOperatorHighMemory` | warning | Memory usage > 80% of limit | 10m | Operator memory pressure |

### Viewing Alerts in VictoriaMetrics

```bash
# Port-forward to VMAlert
kubectl port-forward -n observability svc/vmalert-victoria-metrics-k8s-stack 8080:8080

# Open browser
open http://localhost:8080/vmalert/alerts
```

### Query Operator Metrics

```bash
# Port-forward to VictoriaMetrics
kubectl port-forward -n observability svc/vmselect-victoria-metrics-k8s-stack 8481:8481

# Query operator metrics
curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=rook_ceph_operator_reconcile_errors_total'

# Query operator uptime
curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=up{job="rook-ceph-operator"}'
```

---

## 🌍 Multi-Cluster Deployment

### Cluster Isolation

Each cluster has an **independent Ceph storage cluster**:

#### Infra Cluster

**Context**: Platform services
**Ceph Cluster**: `rook-ceph` (namespace: `rook-ceph`)
**Storage Pool**: `rook-ceph-block` (3x replication)
**Use Cases**:
- CloudNative-PG PostgreSQL (shared-postgres)
- VictoriaMetrics time-series storage
- VictoriaLogs log storage
- Grafana dashboards and configs

**Verification**:
```bash
# Set context to infra cluster
kubectl config use-context admin@infra

# Check CephCluster
kubectl get cephcluster -n rook-ceph

# Check storage usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df
```

#### Apps Cluster

**Context**: Application workloads
**Ceph Cluster**: `rook-ceph` (namespace: `rook-ceph`)
**Storage Pool**: `rook-ceph-block` (3x replication)
**Use Cases**:
- GitLab repository storage
- Harbor registry blob storage
- Mattermost file uploads
- SynergyFlow application data

**Verification**:
```bash
# Set context to apps cluster
kubectl config use-context admin@apps

# Check CephCluster
kubectl get cephcluster -n rook-ceph

# Check storage usage
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df
```

### No Cross-Cluster Federation

- ❌ **No Ceph cluster federation** between infra and apps
- ❌ **No cross-cluster PV access** (each cluster is independent)
- ✅ **Operator manifests are shared** (DRY principle via bases/)
- ✅ **Configuration is consistent** (same chart version, resources)

---

## 🔒 Security

### Pod Security Admission

**Namespace**: `rook-ceph`
**Enforcement**: `privileged` (required for host access)

**Why Privileged?**
- Operator needs cluster-admin for CRD management
- OSDs need host network, host PID, privileged containers
- Discovery daemon needs `/dev` access for disk scanning
- CSI drivers need privileged access for volume mounting

**File**: `kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml:5-9`

### RBAC

ServiceAccounts created by operator:

| ServiceAccount | Purpose |
|----------------|---------|
| `rook-ceph-system` | Operator permissions (CRD reconciliation) |
| `rook-ceph-osd` | OSD daemon permissions |
| `rook-ceph-mgr` | MGR daemon permissions |
| `rook-csi-rbd-provisioner-sa` | RBD volume provisioning |
| `rook-csi-cephfs-provisioner-sa` | CephFS volume provisioning |

---

## 🧰 Troubleshooting

### Operator Not Starting

**Symptoms**: Operator pod stuck in Pending, CrashLoopBackOff, or Error

**Diagnosis**:
```bash
kubectl get pod -n rook-ceph -l app=rook-ceph-operator
kubectl describe pod -n rook-ceph -l app=rook-ceph-operator
kubectl logs -n rook-ceph deploy/rook-ceph-operator --tail=100
```

**Common Causes**:
1. Insufficient node resources (needs 128Mi memory)
2. Image pull errors (check registry access)
3. Old CRDs from previous Rook installation
4. RBAC issues (ServiceAccount/ClusterRole not bound)

**Solutions**:
```bash
# Check HelmRelease status
kubectl get helmrelease -n rook-ceph rook-ceph-operator -o yaml

# Force Flux reconciliation
flux reconcile helmrelease -n rook-ceph rook-ceph-operator --with-source

# Check RBAC
kubectl get serviceaccount -n rook-ceph rook-ceph-system
kubectl get clusterrolebinding | grep rook
```

### CephCluster Not Initializing

**Symptoms**: CephCluster stuck in Progressing, no MON/MGR pods

**Diagnosis**:
```bash
kubectl get cephcluster -n rook-ceph
kubectl describe cephcluster -n rook-ceph rook-ceph
kubectl logs -n rook-ceph deploy/rook-ceph-operator | grep -i error
```

**Common Causes**:
1. Disks not clean (have existing filesystem)
2. Insufficient nodes (<3 nodes for MON quorum)
3. Network connectivity issues
4. Node labels/taints blocking OSD placement

**Solutions**:
```bash
# Check discovered devices
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml

# Check node readiness
kubectl get nodes -o wide

# Force disk rediscovery
kubectl delete pod -n rook-ceph -l app=rook-discover

# Check CephCluster events
kubectl get events -n rook-ceph --sort-by='.lastTimestamp' | grep CephCluster
```

### CSI Driver Issues (PVC Stuck Pending)

**Symptoms**: PVC remains Pending with `storageClassName: rook-ceph-block`

**Diagnosis**:
```bash
kubectl describe pvc <pvc-name> -n <namespace>
kubectl logs -n rook-ceph deploy/csi-rbdplugin-provisioner -c csi-provisioner --tail=100
```

**Common Causes**:
1. CSI provisioner not running
2. CephBlockPool missing or not ready
3. Ceph cluster full or near capacity
4. RBAC permissions missing for CSI provisioner

**Solutions**:
```bash
# Check CSI provisioner pods
kubectl get pod -n rook-ceph -l app=csi-rbdplugin-provisioner

# Check CephBlockPool exists
kubectl get cephblockpool -n rook-ceph rook-ceph-block

# Check Ceph capacity
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df

# Restart CSI provisioner
kubectl rollout restart deploy -n rook-ceph csi-rbdplugin-provisioner
```

---

## 📚 Additional Resources

### Your GitOps Files

- **This Operator**: `kubernetes/bases/rook-ceph-operator/operator/`
- **Operator Kustomization**: `kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml`
- **Cluster Resources**: `kubernetes/infrastructure/storage/rook-ceph/cluster/`
- **Infra Settings**: `kubernetes/clusters/infra/cluster-settings.yaml`
- **Apps Settings**: `kubernetes/clusters/apps/cluster-settings.yaml`

### Documentation

- [Rook-Ceph Official Docs](https://rook.io/docs/rook/latest-release/)
- [Ceph Documentation](https://docs.ceph.com/en/latest/)
- [Rook GitHub](https://github.com/rook/rook)
- [Rook Helm Charts](https://charts.rook.io/release)

### Your Stories

- Story 15: STORY-STO-ROOK-CEPH-OPERATOR (infra cluster operator)
- Story 16: STORY-STO-ROOK-CEPH-CLUSTER (infra CephCluster)
- Story 30: STORY-STO-APPS-ROOK-CEPH-OPERATOR (apps cluster operator)

---

**Maintained by**: Platform Engineering
**Last Updated**: 2025-11-08 (Story 30 - Cluster-Specific)
**Status**: Production-Ready (Manifests-First)
**Chart Version**: v1.18.6 (Latest Stable)
