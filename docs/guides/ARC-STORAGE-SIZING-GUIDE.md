# GitHub Actions Runner Controller - Storage Sizing Guide

**Date:** 2025-10-23
**Context:** OpenEBS LocalPV with **512GB per node** constraint
**Cluster:** Apps cluster (**3 nodes**: 10.25.11.14-16)

---

## 🎯 Problem Statement

**Hardware Constraint:**
- Each node has 512GB NVMe allocated for OpenEBS LocalPV
- **3 nodes** total: apps-01 (10.25.11.14), apps-02 (10.25.11.15), apps-03 (10.25.11.16)
- Total cluster storage: 3 nodes × 512GB = **1.5TB**
- Storage is **node-local**, not cluster-aggregated

**Challenge:**
With `WaitForFirstConsumer` volume binding, PVCs are created on the node where the pod is scheduled. Without constraints, multiple runners could land on the same node, potentially exhausting local storage.

**Example Worst-Case (Without Topology Spread):**
```
3 runners × 75Gi = 225GB on a single node
512GB - 225GB = 287GB remaining ✅ Safe but unbalanced

With topology spread, worst case is:
2 runners × 75Gi = 150GB per node (balanced distribution)
512GB - 150GB = 362GB remaining ✅ Very safe
```

---

## 📊 Storage Calculation Matrix

### **Option Comparison**

| Configuration | Per Runner | Max Runners | Peak Total | Per Node Max* | Cluster % | Safe? |
|---------------|------------|-------------|------------|---------------|-----------|-------|
| **Maximum** | 75Gi | 6 | 450GB | 150GB† | 30% | ✅ Safe |
| **Balanced** (Recommended) | 75Gi | 4-5 | 300-375GB | 100-125GB† | 20-25% | ✅ Very Safe |
| **Conservative** | 50Gi | 3 | 150GB | 100GB† | 10% | ✅ Ultra Safe |

*Without topology constraints, worst-case all runners on one node
†With topology spread (maxSkew: 1), runners distribute evenly across 3 nodes

---

## 🏗️ Recommended Configuration (Balanced)

### **Key Settings:**

```yaml
minRunners: 1        # Baseline: 75GB always allocated on 1 node
maxRunners: 6        # Peak: 450GB distributed across 3 nodes
storage: 75Gi        # Per-runner allocation

# Topology spread ensures distribution across 3 nodes
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
```

### **How Topology Spread Works (3-Node Cluster):**

```
Scenario 1: 1 runner active (minRunners)
apps-01 (10.25.11.14): 1 runner (75GB used, 437GB free) ✅
apps-02 (10.25.11.15): Empty (512GB free)
apps-03 (10.25.11.16): Empty (512GB free)
Total: 75GB / 1.5TB (5% utilization)

Scenario 2: 3 runners active (moderate load)
apps-01: 1 runner (75GB used, 437GB free) ✅
apps-02: 1 runner (75GB used, 437GB free) ✅
apps-03: 1 runner (75GB used, 437GB free) ✅
Total: 225GB / 1.5TB (15% utilization)

Scenario 3: 6 runners active (maxRunners, heavy load)
apps-01: 2 runners (150GB used, 362GB free) ✅
apps-02: 2 runners (150GB used, 362GB free) ✅
apps-03: 2 runners (150GB used, 362GB free) ✅
Total: 450GB / 1.5TB (30% utilization)

Scheduler distributes evenly: maxSkew: 1 means no node can have >1 more runner
than others (e.g., cannot have Node1:3, Node2:2, Node3:1 - violates maxSkew)
```

### **Storage Breakdown (75Gi per runner):**

| Component | Estimated Size | Notes |
|-----------|----------------|-------|
| Base OS + Docker daemon | 5GB | Docker engine + base images |
| JDK 21 + Gradle cache | 12GB | ~/.gradle/caches |
| Docker image layers | 20GB | Base images + pilar images |
| Testcontainers images | 8GB | PostgreSQL, Keycloak, Jaeger |
| Build artifacts | 5GB | JARs, reports, logs |
| Workspace files | 5GB | Source code, temp files |
| **Buffer** | 20GB | Margin for larger builds |
| **Total** | **75GB** | Comfortable allocation |

---

## 🔧 Configuration Options

### **Option 1: Conservative (Ultra-Safe)**

**When to use:** You want zero risk of storage issues.

```yaml
minRunners: 1
maxRunners: 3
storage: 50Gi

# No topology constraints needed (150GB max even if all on one node)
```

**Capacity:**
- Baseline: 50GB (1 runner)
- Peak: 150GB (3 runners)
- Worst-case single node: 150GB / 512GB = **29% utilization**
- Cluster total: 150GB / 1.5TB = **10% utilization**

**Pros:**
- Safe even without topology spread
- Low resource footprint
- Can co-locate with other storage-heavy workloads

**Cons:**
- 50Gi might be tight for large Docker builds with many layers
- May require periodic cleanup or pruning

**Recommended for:**
- Testing/validation phase
- Clusters with other storage-intensive workloads
- When you want maximum safety margin

---

### **Option 2: Balanced with Topology (Recommended)**

**When to use:** You want good performance with safety guarantees for most workloads.

```yaml
minRunners: 1
maxRunners: 6
storage: 75Gi

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: pilar-runner
```

**Capacity:**
- Baseline: 75GB (1 runner on 1 node)
- Peak: 450GB distributed (6 runners × 75GB across 3 nodes)
- Per node max: 150GB (2 runners per node at peak)
- Cluster total: 450GB / 1.5TB = **30% utilization**

**Pros:**
- 75Gi comfortable for most Docker builds with Testcontainers
- Topology spread prevents node overload
- Good balance of performance and safety
- Allows 6 concurrent builds (suitable for single repo with moderate activity)
- 70% cluster capacity remains available for other workloads

**Cons:**
- Slightly more complex (topology constraint)
- At max scale (6 runners), each node hosts 2 runners

**Recommended for:**
- Production deployments
- Single repository CI/CD (like pilar)
- Most use cases

---

### **Option 3: Maximum Storage with Anti-Affinity**

**When to use:** You need maximum storage per runner and want hard isolation (1 runner per node max).

```yaml
minRunners: 1
maxRunners: 3  # One per node (hard limit due to anti-affinity on 3-node cluster)
storage: 100Gi

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: pilar-runner
        topologyKey: kubernetes.io/hostname

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: pilar-runner
```

**Capacity:**
- Baseline: 100GB (1 runner on 1 node)
- Peak: 300GB distributed (3 runners × 100GB, one per node)
- Per node: 100GB exactly (1 runner max via anti-affinity)
- Per node remaining: 412GB (80% free)
- Cluster total: 300GB / 1.5TB = **20% utilization**

**Pros:**
- Maximum storage per runner (100Gi) for very large builds
- Hard guarantee: never >1 runner per node
- Excellent per-node resource isolation

**Cons:**
- **Limited concurrency:** Max 3 concurrent builds (one per node)
- More complex scheduling (anti-affinity + topology spread)
- If 1 node fails, max runners reduced to 2
- **May be overkill** for most single-repo workloads

**Recommended for:**
- Extremely large Docker builds requiring >75GB
- When strict per-node isolation is required
- Multi-repository scenarios with large builds

---

## 🧪 Validation & Monitoring

### **Pre-Deployment Checks**

```bash
# 1. Verify OpenEBS storage class
kubectl --context=apps get storageclass openebs-local-nvme -o yaml

# Expected output should show:
# provisioner: openebs.io/local
# volumeBindingMode: WaitForFirstConsumer

# 2. Check per-node storage capacity
kubectl --context=apps get nodes -o json | \
  jq '.items[] | {name: .metadata.name, storage: .status.capacity.storage}'

# Expected: ~512GB per node

# 3. Check existing PVC usage
kubectl --context=apps get pvc -A | grep openebs-local-nvme
```

### **Post-Deployment Monitoring**

```bash
# 1. Check runner pod distribution across nodes
kubectl --context=apps -n actions-runner-system get pods -o wide

# Expected: Runners spread across different nodes

# 2. Check PVC allocation per node
kubectl --context=apps get pvc -A -o json | \
  jq -r '.items[] | select(.spec.storageClassName=="openebs-local-nvme") |
  [.metadata.name, .spec.resources.requests.storage] | @tsv'

# 3. Monitor actual storage usage inside runner
RUNNER_POD=$(kubectl --context=apps -n actions-runner-system get pods -l app=pilar-runner -o jsonpath='{.items[0].metadata.name}')

kubectl --context=apps -n actions-runner-system exec $RUNNER_POD -c dind -- \
  df -h /var/lib/docker

# Example output:
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/nvme0n1p1   75G   18G   57G  24% /var/lib/docker

# 4. Check Docker image layer usage
kubectl --context=apps -n actions-runner-system exec $RUNNER_POD -c dind -- \
  docker system df -v

# 5. Monitor PVC usage via metrics (if available)
kubectl --context=apps -n actions-runner-system get pvc -o json | \
  jq '.items[].status.capacity.storage'
```

### **Alerting Recommendations**

Set up alerts for:

1. **Per-Node Storage Threshold**
   ```promql
   (node_filesystem_size_bytes{mountpoint="/var/mnt/openebs"} -
    node_filesystem_free_bytes{mountpoint="/var/mnt/openebs"}) /
   node_filesystem_size_bytes{mountpoint="/var/mnt/openebs"} > 0.80
   ```
   Alert at: **80% node storage utilization**

2. **Per-PVC Storage Threshold**
   ```promql
   kubelet_volume_stats_used_bytes{namespace="actions-runner-system"} /
   kubelet_volume_stats_capacity_bytes{namespace="actions-runner-system"} > 0.85
   ```
   Alert at: **85% PVC utilization**

3. **Runner Pod Distribution Skew**
   ```promql
   count by (node) (kube_pod_info{namespace="actions-runner-system", pod=~".*runner.*"}) > 2
   ```
   Alert if: **>2 runners on same node** (shouldn't happen with topology spread)

---

## 🔄 Dynamic Adjustment Strategy

### **Week 1: Monitor Baseline**

```bash
# After first week, check actual storage usage
kubectl --context=apps -n actions-runner-system exec <runner-pod> -c dind -- \
  du -sh /var/lib/docker

# Decision matrix:
# If usage < 30GB → Reduce to storage: 50Gi
# If usage 30-60GB → Keep storage: 75Gi ✅
# If usage > 60GB → Increase to storage: 100Gi
```

### **Week 2-4: Optimize Configuration**

```yaml
# Based on usage patterns, adjust:

# If builds mostly run during business hours (9am-5pm):
minRunners: 0  # Scale to zero overnight
# Schedule: Scale up at 8am, down at 6pm via external automation

# If builds are bursty (PRs trigger multiple jobs):
maxRunners: 5  # Allow more concurrency
storage: 60Gi  # Reduce per-runner if usage is low

# If builds are sequential (one at a time):
maxRunners: 2  # Reduce max runners
storage: 100Gi  # Increase per-runner allocation
```

### **Month 2+: Fine-Tuning**

1. **Implement cleanup automation:**
   ```yaml
   # Add env to DinD container
   env:
     - name: DOCKER_PRUNE_UNTIL
       value: "24h"  # Prune images older than 24h
   ```

2. **Add storage expansion logic:**
   ```yaml
   # If hitting limits consistently
   storage: 100Gi  # Increase allocation
   maxRunners: 3   # Reduce max concurrency
   ```

3. **Consider node-specific scheduling:**
   ```yaml
   # If some nodes have more storage
   nodeSelector:
     storage-tier: "high"  # Target nodes with more capacity
   ```

---

## 🚨 Troubleshooting

### **Issue 1: PVC Creation Fails (Out of Space)**

**Symptoms:**
```
Events: Failed to provision volume: not enough space on node
```

**Diagnosis:**
```bash
# Check node storage
kubectl --context=apps describe node <node-name> | grep -A5 "Allocated resources"

# Check existing PVCs on node
kubectl --context=apps get pvc -A -o wide | grep <node-name>
```

**Solutions:**
1. **Reduce runner storage:** `storage: 50Gi`
2. **Reduce max runners:** `maxRunners: 3`
3. **Add topology spread** (if not already present)
4. **Clean up old PVCs manually:**
   ```bash
   kubectl --context=apps -n actions-runner-system delete pvc <old-pvc>
   ```

---

### **Issue 2: All Runners on Same Node**

**Symptoms:**
```bash
kubectl get pods -o wide
# All runner pods show same node
```

**Diagnosis:**
```bash
# Check if topology spread is configured
kubectl --context=apps -n actions-runner-system get pod <runner-pod> -o yaml | \
  grep -A10 topologySpreadConstraints
```

**Solution:**
Add topology spread constraint to HelmRelease (see Option 2 above)

---

### **Issue 3: Runner Storage Full During Build**

**Symptoms:**
```
Error: no space left on device
docker: Error response from daemon: write /var/lib/docker/...: no space left on device
```

**Diagnosis:**
```bash
# Check actual usage
kubectl exec <runner-pod> -c dind -- df -h /var/lib/docker

# Check Docker system usage
kubectl exec <runner-pod> -c dind -- docker system df -v
```

**Solutions:**
1. **Increase storage:** `storage: 100Gi` or `storage: 125Gi`
2. **Enable aggressive pruning:**
   ```bash
   # In workflow, add cleanup step
   - name: Docker cleanup
     run: |
       docker system prune -af --volumes
       docker image prune -af
   ```
3. **Use Docker layer caching optimization:**
   ```dockerfile
   # In Dockerfile, order layers by change frequency
   # Less frequently changed layers first
   COPY pom.xml .
   RUN mvn dependency:go-offline
   COPY src/ .
   RUN mvn package
   ```

---

## 📋 Summary & Recommendations

### **Immediate Actions:**

1. ✅ **Deploy with Option 2 (Balanced):**
   - 75Gi per runner
   - maxRunners: 6
   - minRunners: 1 (warm pool)
   - Topology spread enabled

2. ✅ **Monitor for 1 week:**
   - Check actual storage usage per runner
   - Validate topology spread distributes evenly
   - Measure build completion times vs GitHub-hosted
   - Track concurrent workflow patterns

3. ✅ **Adjust after baseline:**
   - If usage consistently < 50GB → reduce to 50Gi, increase maxRunners
   - If usage consistently > 65GB → keep 75Gi or increase to 100Gi
   - If rarely exceeding 3 concurrent builds → reduce maxRunners to 4-5
   - If topology spread fails → investigate node taints/affinities

### **Long-Term Strategy:**

- **Month 1:** Establish baseline usage patterns
- **Month 2:** Optimize based on data
- **Month 3:** Implement cleanup automation
- **Month 6:** Re-evaluate hardware capacity if needed

### **Capacity Planning:**

With **Option 2 (Balanced - Recommended)** configuration:
- Current: 450GB / 1.5TB = **30% utilization**
- Headroom for growth: **1.05TB available** (70% free)
- Can add moderate additional workloads using OpenEBS
- DragonflyDB already uses ~150GB (included in calculations)

---

## 🔗 References

- **Main Epic:** `STORY-CICD-GITHUB-ARC.md`
- **HelmRelease:** `arc-runner-helmrelease-rootless.yaml`
- **Security Guide:** `ARC-ROOTLESS-DIND-SUMMARY.md`
- **OpenEBS Docs:** https://openebs.io/docs/user-guides/localpv-hostpath

---

**Last Updated:** 2025-10-23
**Cluster:** 3 nodes (10.25.11.14-16), 512GB OpenEBS per node, 1.5TB total
**Configuration:** Balanced (75Gi × 6 runners with topology spread, maxSkew: 1)
**Status:** ✅ Recommended for production deployment
