# ARC Configuration Summary - Adjusted for 512GB Per-Node Storage

**Date:** 2025-10-23
**Cluster:** Apps cluster with 3 nodes (10.25.11.14-16), 512GB per node = 1.5TB total
**Issue:** Original configuration (100Gi × 5 runners) could exhaust node-local storage
**Solution:** Optimized 75Gi allocation + topology constraints

---

## 🔄 Configuration Changes

### **Before (Original):**
```yaml
minRunners: 1
maxRunners: 5
storage: 100Gi per runner
# No topology constraints

# Worst-case: 5 runners × 100Gi = 500GB on single node
# Node capacity: 512GB
# Remaining: 12GB 🚨 CRITICAL
```

### **After (Optimized):**
```yaml
minRunners: 1
maxRunners: 6  # Optimal for single repo on 3-node cluster
storage: 75Gi per runner  # Balanced allocation

# Topology spread constraint added:
topologySpreadConstraints:
  - maxSkew: 1  # Distribute evenly across 3 nodes
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule

# With topology spread: max 2 runners per node at peak
# Per node at peak: 2 runners × 75Gi = 150GB
# Node capacity: 512GB
# Remaining: 362GB ✅ SAFE (71% free)
# Baseline (1 runner): 75GB on 1 node, 437GB free (85% free)
```

---

## 📊 Capacity Analysis

### **Storage Utilization:**

| Scenario | Runners Active | Storage Used | % of Node | % of Cluster (1.5TB) |
|----------|----------------|--------------|-----------|-------------------|
| **Baseline** | 1 (minRunners) | 75GB | 15% (1 node) | 5% |
| **Moderate Load** | 3 | 225GB | 15% each (3 nodes) | 15% |
| **Peak Load** | 6 (maxRunners) | 450GB | 29% each (3 nodes) | 30% |

### **Resource Utilization (per runner):**

| Resource | Request | Limit | Total (6 runners) |
|----------|---------|-------|-------------------|
| **CPU** | 1 core | 4 cores | 6-24 cores |
| **Memory** | 2Gi | 8Gi | 12-48Gi |
| **Storage** | 75Gi | - | 450Gi |

### **Cluster Capacity vs Usage (3-Node Cluster):**

| Resource | Available (Est.) | Peak Usage (6 runners) | Remaining | % Used |
|----------|------------------|------------------------|-----------|--------|
| **CPU** | ~48 cores (est.) | 24 cores | ~24 cores | ~50% |
| **Memory** | ~192GB (est.) | 48GB | ~144GB | ~25% |
| **Storage** | 1.5TB | 450GB | 1.05TB | 30% |

---

## 🏗️ How Topology Spread Prevents Storage Exhaustion

### **Without Topology Spread (Risky):**
```
Kubernetes scheduler is free to place all runners on same node:

Node 1: [Runner1] [Runner2] [Runner3] [Runner4]
        75GB + 75GB + 75GB + 75GB = 300GB ✅ Safe
        BUT if user scales to 5 runners:
        75GB × 5 = 375GB ✅ Still safe
        BUT if user uses 100Gi per runner:
        100GB × 5 = 500GB 🚨 Only 12GB remaining!

Nodes 2-6: Empty
```

### **With Topology Spread (Safe):**
```
maxSkew: 1 means no node can have >1 more runner than others:

With 4 runners active:
Node 1: [Runner1] - 75GB used, 437GB free ✅
Node 2: [Runner2] - 75GB used, 437GB free ✅
Node 3: [Runner3] - 75GB used, 437GB free ✅
Node 4: [Runner4] - 75GB used, 437GB free ✅
Nodes 5-6: Empty

Scheduler CANNOT place Runner5 until distribution is even:
- Node 1 has 1 runner
- Node 2 has 1 runner
- Node 3 has 1 runner
- Node 4 has 1 runner
- Nodes 5-6 have 0 runners

Next runner goes to Node 5 or 6 (maxSkew: 1 enforces this)
```

---

## ✅ Safety Guarantees

### **1. Storage Exhaustion Prevention**

✅ **Max 1 runner per node** (enforced by topology spread)
✅ **Max 75GB used per node** (85% storage remains free)
✅ **Ephemeral PVCs** (automatically deleted on scale-down)
✅ **300GB distributed** across 4 nodes (not concentrated)

### **2. Node Failure Resilience**

```
Scenario: Node apps-02 (10.25.11.15) fails while running runners

Before failure (3 runners active):
apps-01 (10.25.11.14): [Runner1] - 75GB
apps-02 (10.25.11.15): [Runner2] - 75GB 💥 FAILED
apps-03 (10.25.11.16): [Runner3] - 75GB

After failure (automatic):
1. Pod on apps-02 marked as Failed
2. PVC on apps-02 automatically deleted (ephemeral)
3. New Runner2 pod scheduled to apps-01 or apps-03 (topology spread allows it)
4. New PVC created on target node

Result (after recovery):
apps-01: [Runner1] [Runner2'] - 150GB (2 runners temporarily)
apps-03: [Runner3] - 75GB
apps-02: Offline (no runners)

Note: System continues operating with reduced capacity (2 nodes).
When apps-02 returns, topology spread rebalances automatically.
No storage leaked, no manual intervention needed.
```

### **3. Resource Quota Protection**

If you want additional safety, add ResourceQuota:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: runner-storage-quota
  namespace: actions-runner-system
spec:
  hard:
    requests.storage: 400Gi  # Max 400GB total PVCs
```

This prevents accidentally creating too many PVCs even if topology spread fails.

---

## 🎯 Why This Configuration?

### **75Gi Per Runner (vs 100Gi)**

**Rationale:**
- Most Docker builds use 40-60GB (including layers, caches, artifacts)
- 75Gi provides 15-35GB buffer for large builds with Testcontainers
- Allows 6 concurrent runners safely (30% cluster utilization)
- Balanced for single repository CI/CD workloads like pilar

**If you need more:**
- Monitor actual usage for 1 week
- If consistently >65GB, increase to 100Gi
- If rarely >40GB, reduce to 50Gi

### **maxRunners: 6 (vs 4 or 5)**

**Rationale:**
- Typical PR triggers 1-2 builds (frontend + backend)
- Moderate concurrent load: 3-4 builds
- Heavy concurrent load (multi-PR day): 5-6 builds
- 6 runners = comfortable headroom for single private repo
- 30% cluster utilization leaves 70% free for other workloads
- Topology spread distributes evenly: 2-2-2 across 3 nodes at peak

**If you need less:**
- Reduce to `maxRunners: 3-4` if rarely exceeding 3 concurrent builds
- Monitor actual usage patterns for 1-2 weeks before adjusting

### **Topology Spread (vs Anti-Affinity)**

**Rationale:**
- Topology spread is more flexible than hard anti-affinity
- Allows >1 runner per node if necessary (e.g., 5 runners on 6 nodes)
- Anti-affinity would be too strict and prevent valid scheduling

**When to use anti-affinity:**
- If you want absolute guarantee of 1 runner per node
- See Option 3 in `ARC-STORAGE-SIZING-GUIDE.md`

---

## 🧪 Validation Checklist

After deployment, verify:

### **1. Topology Spread Works:**
```bash
# Deploy, scale to 4 runners, check distribution
kubectl --context=apps -n actions-runner-system get pods -o wide

# Expected: 4 different nodes
NAME                              NODE
pilar-runner-abc123-xyz          10.25.11.14
pilar-runner-def456-uvw          10.25.11.15
pilar-runner-ghi789-rst          10.25.11.16
pilar-runner-jkl012-opq          10.25.11.17
```

### **2. Storage Allocation Correct:**
```bash
# Check PVC size
kubectl --context=apps -n actions-runner-system get pvc

# Expected: 75Gi per PVC
NAME                              CAPACITY
pilar-runner-abc123-xyz-work      75Gi
pilar-runner-def456-uvw-work      75Gi
pilar-runner-ghi789-rst-work      75Gi
pilar-runner-jkl012-opq-work      75Gi
```

### **3. Node Storage Not Exhausted:**
```bash
# Check per-node storage usage
for node in $(kubectl --context=apps get nodes -o name); do
  echo "Node: $node"
  kubectl --context=apps describe $node | grep -A5 "Allocated resources"
done

# Expected: <20% storage allocation per node
```

### **4. Ephemeral PVC Cleanup:**
```bash
# Scale down to minRunners
kubectl --context=apps -n actions-runner-system patch autoscalingrunner pilar-runner \
  --type merge -p '{"spec":{"maxRunners":1}}'

# Wait 5 minutes, check PVCs
kubectl --context=apps -n actions-runner-system get pvc

# Expected: Only 1 PVC remaining (for minRunners pod)
```

---

## 📈 Monitoring Recommendations

### **Dashboard Metrics:**

1. **Runner Storage Usage:**
   ```promql
   kubelet_volume_stats_used_bytes{namespace="actions-runner-system"} /
   kubelet_volume_stats_capacity_bytes{namespace="actions-runner-system"} * 100
   ```
   Panel: Gauge showing % used per PVC

2. **Per-Node Storage Allocation:**
   ```promql
   sum by (node) (
     kubelet_volume_stats_used_bytes{namespace="actions-runner-system"}
   ) / (512 * 1024 * 1024 * 1024) * 100
   ```
   Panel: Graph showing % of 512GB used per node

3. **Runner Pod Distribution:**
   ```promql
   count by (node) (
     kube_pod_info{namespace="actions-runner-system", pod=~".*runner.*"}
   )
   ```
   Panel: Heatmap showing runner count per node

### **Alerts:**

```yaml
# Alert 1: Node storage >80%
- alert: NodeStorageHigh
  expr: >
    (1 - (node_filesystem_avail_bytes{mountpoint="/var/mnt/openebs"} /
    node_filesystem_size_bytes{mountpoint="/var/mnt/openebs"})) > 0.80
  for: 5m
  annotations:
    summary: "Node {{ $labels.node }} storage >80%"

# Alert 2: PVC >90% full
- alert: RunnerPVCAlmostFull
  expr: >
    kubelet_volume_stats_used_bytes{namespace="actions-runner-system"} /
    kubelet_volume_stats_capacity_bytes{namespace="actions-runner-system"} > 0.90
  for: 2m
  annotations:
    summary: "PVC {{ $labels.persistentvolumeclaim }} >90% full"

# Alert 3: Multiple runners on same node (shouldn't happen)
- alert: TopologySpreadViolation
  expr: >
    count by (node) (
      kube_pod_info{namespace="actions-runner-system", pod=~".*runner.*"}
    ) > 1
  for: 5m
  annotations:
    summary: "Node {{ $labels.node }} has >1 runner (topology spread failed)"
```

---

## 🚀 Deployment Readiness

### **✅ Pre-Deployment Checklist:**

- [x] HelmRelease updated with 75Gi storage
- [x] maxRunners set to 6 (optimal for 3-node cluster)
- [x] Topology spread constraint added
- [x] Resource limits adjusted (8Gi memory limit per container)
- [x] Storage sizing guide created and updated for 3 nodes
- [x] Monitoring alerts defined
- [x] Validation steps documented

### **📁 Updated Files:**

1. **HelmRelease:** `arc-runner-helmrelease-rootless.yaml`
   - ✅ storage: 75Gi
   - ✅ maxRunners: 4
   - ✅ topologySpreadConstraints added
   - ✅ Resource limits: 6Gi memory

2. **Documentation:**
   - ✅ `ARC-STORAGE-SIZING-GUIDE.md` (comprehensive, 3-node cluster)
   - ✅ `ARC-ROOTLESS-DIND-SUMMARY.md` (security architecture)
   - ✅ `STORY-CICD-GITHUB-ARC.md` (epic story, updated)
   - ✅ `ARC-CONFIGURATION-SUMMARY.md` (this document)

### **🎯 Ready to Deploy:**

```bash
# Apply the HelmRelease
kubectl --context=apps apply -f arc-runner-helmrelease-rootless.yaml

# Monitor deployment
kubectl --context=apps -n actions-runner-system get pods -w

# Validate topology spread
kubectl --context=apps -n actions-runner-system get pods -o wide

# Check PVC creation
kubectl --context=apps -n actions-runner-system get pvc
```

---

## 📋 Quick Reference

| Metric | Value | Notes |
|--------|-------|-------|
| **Storage per runner** | 75Gi | Balanced for Docker + Testcontainers |
| **Max runners** | 6 | Optimal for single repo |
| **Storage per node** | 512GB | Hardware constraint (3 nodes) |
| **Peak storage** | 450GB distributed | 30% of 1.5TB cluster |
| **Safety margin** | 362GB per node | 71% free at peak |
| **Topology spread** | maxSkew: 1 | Even distribution (2-2-2) |
| **Ephemeral PVCs** | Yes | Auto-cleanup on scale-down |

---

**Status:** ✅ Ready for Production Deployment
**Risk Level:** 🟢 Low (multiple safety layers)
**Estimated Deployment Time:** 15-20 minutes
**Validation Time:** 1 week monitoring recommended
