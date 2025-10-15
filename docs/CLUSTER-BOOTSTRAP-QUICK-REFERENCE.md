# Cluster Bootstrap Quick Reference
## Complete End-to-End Commands

**Last Updated:** 2025-10-15

---

## 🚀 Most Common Commands

```bash
# Create complete infra cluster (Talos → K8s → Flux)
task cluster:create-infra

# Create complete apps cluster
task cluster:create-apps

# Check cluster status
task cluster:status-infra

# Health check
task cluster:health CLUSTER=infra

# List all available cluster tasks
task --list | grep cluster
```

---

## 📋 Complete Command Reference

### Cluster Creation

| Command | What It Does | Time |
|---------|--------------|------|
| `task cluster:create-infra` | Create complete infra cluster from scratch | ~15-20 min |
| `task cluster:create-apps` | Create complete apps cluster from scratch | ~15-20 min |
| `task cluster:preflight CLUSTER=infra` | Run pre-flight checks only | ~10 sec |
| `task cluster:dry-run CLUSTER=infra` | Preview what will be done | ~5 sec |

### Status & Monitoring

| Command | What It Does |
|---------|--------------|
| `task cluster:status CLUSTER=infra` | Show complete status (all layers) |
| `task cluster:status-infra` | Show infra cluster status |
| `task cluster:status-apps` | Show apps cluster status |
| `task cluster:health CLUSTER=infra` | Quick health check |
| `task cluster:list-nodes CLUSTER=infra` | List all nodes |

### Validation

| Command | What It Does |
|---------|--------------|
| `task cluster:validate:all CLUSTER=infra` | Validate all layers |
| `task cluster:validate:talos CLUSTER=infra` | Validate Talos only |
| `task cluster:validate:kubernetes CLUSTER=infra` | Validate Kubernetes only |
| `task cluster:validate:crds CLUSTER=infra` | Validate CRDs only |
| `task cluster:validate:networking CLUSTER=infra` | Validate networking only |
| `task cluster:validate:flux CLUSTER=infra` | Validate Flux only |

### Cluster Destruction

| Command | What It Does |
|---------|--------------|
| `task cluster:destroy-infra` | Destroy complete infra cluster (WIPE!) |
| `task cluster:destroy-apps` | Destroy complete apps cluster (WIPE!) |
| `task cluster:soft-destroy CLUSTER=infra` | Remove K8s apps (keep Talos) |

---

## 🎯 Common Workflows

### First-Time Cluster Creation

```bash
# 1. Authenticate with 1Password (optional)
eval $(op signin)

# 2. Run pre-flight checks
task cluster:preflight CLUSTER=infra

# 3. Create complete cluster
task cluster:create-infra

# 4. Monitor Flux reconciliation
flux get kustomizations --watch
```

### Check Cluster Health

```bash
# Quick health check
task cluster:health CLUSTER=infra

# Complete status
task cluster:status CLUSTER=infra

# Watch Flux
flux get kustomizations --watch
```

### Destroy and Recreate Cluster

```bash
# Destroy completely (wipe disks)
task cluster:destroy-infra

# Wait for nodes to reboot (~2 minutes)
sleep 120

# Recreate cluster
task cluster:create-infra
```

### Soft Destroy and Re-Bootstrap

```bash
# Soft destroy (keep Talos, remove K8s)
task cluster:soft-destroy CLUSTER=infra

# Re-bootstrap Kubernetes only
task bootstrap:infra
```

---

## ⚡ 5-Layer Architecture

```
┌────────────────────────────────────────┐
│ Layer 1: Talos Cluster (~5 min)       │
│ - Bootstrap first control plane        │
│ - Bootstrap etcd                       │
│ - Add remaining control planes         │
│ - Wait for cluster health              │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Layer 2: Kubernetes Wait (~2 min)     │
│ - Wait for API server                  │
│ - Wait for nodes Ready                 │
│ - Verify etcd health                   │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Layer 3: CRD Bootstrap (~1 min)       │
│ - Install prerequisites                │
│ - Extract & apply VictoriaMetrics CRDs│
│ - Extract & apply cert-manager CRDs   │
│ - Extract & apply external-secrets CRDs│
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Layer 4: Core Infrastructure (~5-8min)│
│ - Deploy Cilium CNI                    │
│ - Deploy CoreDNS                       │
│ - Deploy cert-manager                  │
│ - Deploy external-secrets              │
│ - Deploy Flux                          │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Layer 5: Validation (~30 sec)         │
│ - Validate Talos                       │
│ - Validate Kubernetes                  │
│ - Validate CRDs                        │
│ - Validate networking                  │
│ - Validate Flux                        │
└────────────────────────────────────────┘

Total Time: ~15-20 minutes
```

---

## 🔧 Manual Layer Control

```bash
# Run specific layers manually
task cluster:layer:1-talos CLUSTER=infra
task cluster:layer:2-kubernetes CLUSTER=infra
task cluster:layer:3-crds CLUSTER=infra
task cluster:layer:4-infrastructure CLUSTER=infra
task cluster:layer:5-validation CLUSTER=infra
```

---

## 🛠️ Node Configuration

### Infra Cluster

| Node | IP | Role |
|------|-----|------|
| infra-01 | 10.25.11.11 | Control Plane (Bootstrap) |
| infra-02 | 10.25.11.12 | Control Plane |
| infra-03 | 10.25.11.13 | Control Plane |

**Config files:** `talos/infra/*.yaml`

### Apps Cluster

| Node | IP | Role |
|------|-----|------|
| apps-01 | 10.25.11.14 | Control Plane (Bootstrap) |
| apps-02 | 10.25.11.15 | Control Plane |
| apps-03 | 10.25.11.16 | Control Plane |

**Config files:** `talos/apps/*.yaml`

---

## 🚨 Troubleshooting Quick Fixes

### Issue: etcd Bootstrap Fails

```bash
# Check Talos health
talosctl --nodes 10.25.11.11 health

# Retry bootstrap
talosctl --nodes 10.25.11.11 bootstrap

# Check etcd logs
talosctl --nodes 10.25.11.11 logs etcd
```

### Issue: API Server Not Responding

```bash
# Regenerate kubeconfig
task talos:generate-kubeconfig

# Check API server logs
talosctl --nodes 10.25.11.11 logs kube-apiserver
```

### Issue: Nodes NotReady

```bash
# Check Cilium
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Check Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium
```

### Issue: Flux Not Reconciling

```bash
# Check Flux status
flux get kustomizations -A

# Force reconciliation
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Check Flux logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-instance
```

---

## 📊 Status Output Example

```bash
task cluster:status-infra
```

```
==============================================
📊 Complete Cluster Status: infra
==============================================

🔧 Talos Layer:
  Nodes:
    - 10.25.11.11: ✅ Online (Talos v1.7.0)
    - 10.25.11.12: ✅ Online (Talos v1.7.0)
    - 10.25.11.13: ✅ Online (Talos v1.7.0)

  Etcd:
    MEMBER                  HEALTHY   TOOK
    10.25.11.11:2379       true      3.5ms
    10.25.11.12:2379       true      3.8ms
    10.25.11.13:2379       true      3.2ms

🖥️  Kubernetes Layer:
NAME       STATUS   ROLES           AGE   VERSION
infra-01   Ready    control-plane   10m   v1.30.0
infra-02   Ready    control-plane   9m    v1.30.0
infra-03   Ready    control-plane   9m    v1.30.0

📦 Core Components:
NAMESPACE     NAME                  READY   STATUS
kube-system   cilium-xxxxx         1/1     Running
kube-system   coredns-xxxxx        1/1     Running

📊 Flux Layer:
NAME                          READY   MESSAGE
cluster-infra-infrastructure  True    Applied revision: main/abc123

⚠️  CRDs:
  VictoriaMetrics CRDs: 14
  Prometheus CRDs: 9
==============================================
```

---

## 💡 Pro Tips

1. **Always run pre-flight checks first**
   ```bash
   task cluster:preflight CLUSTER=infra
   ```

2. **Monitor in separate terminal**
   ```bash
   watch -n 2 'task cluster:status CLUSTER=infra'
   ```

3. **Use soft destroy for faster iteration**
   ```bash
   task cluster:soft-destroy CLUSTER=infra
   task bootstrap:infra  # Much faster than full destroy
   ```

4. **Check health after changes**
   ```bash
   task cluster:health CLUSTER=infra
   ```

5. **Watch Flux after bootstrap**
   ```bash
   flux get kustomizations --watch
   ```

---

## 🔗 Related Commands

### Talos Commands

```bash
# Apply config to single node
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra

# Generate kubeconfig
task talos:generate-kubeconfig

# Upgrade Talos on node
task talos:upgrade-node NODE=10.25.11.11

# Reset node (DANGEROUS!)
task talos:reset-node NODE=10.25.11.11
```

### Bootstrap Commands (K8s/CRD Only)

```bash
# Bootstrap Kubernetes (without Talos)
task bootstrap:infra

# Individual bootstrap phases
task bootstrap:phase:0 CLUSTER=infra  # Prerequisites
task bootstrap:phase:1 CLUSTER=infra  # CRDs
task bootstrap:phase:2 CLUSTER=infra  # Core infra
task bootstrap:phase:3 CLUSTER=infra  # Validation

# Bootstrap status
task bootstrap:status CLUSTER=infra
```

### Flux Commands

```bash
# Check Flux
flux check

# Get Kustomizations
flux get kustomizations -A

# Reconcile
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Get sources
flux get sources all -A
```

---

## 📚 Full Documentation

- [Complete Cluster Bootstrap Guide](./COMPLETE-CLUSTER-BOOTSTRAP-GUIDE.md) - Full guide
- [Taskfile Bootstrap Guide](./TASKFILE-BOOTSTRAP-GUIDE.md) - CRD/K8s bootstrap
- [CRD Implementation Plan](./CRD-BOOTSTRAP-IMPLEMENTATION-PLAN.md) - Architecture

---

## 🆘 Getting Help

```bash
# List all cluster tasks
task --list | grep cluster

# List all bootstrap tasks
task --list | grep bootstrap

# Show task description
task --summary cluster:create-infra

# View source
cat .taskfiles/cluster/Taskfile.yaml
```

---

**Quick Reference Version:** 1.0
**Last Updated:** 2025-10-15
