# Taskfile Quick Reference
## Bootstrap Commands Cheat Sheet

**Last Updated:** 2025-10-15

---

## 🚀 Most Common Commands

```bash
# Bootstrap infra cluster (fully automated)
task bootstrap:infra

# Bootstrap apps cluster (fully automated)
task bootstrap:apps

# Check cluster status
task bootstrap:status CLUSTER=infra

# List all available tasks
task --list-all
```

---

## 📋 Complete Command Reference

### Bootstrap Commands

| Command | What It Does |
|---------|--------------|
| `task bootstrap:infra` | Bootstrap infra cluster (all 3 phases) |
| `task bootstrap:apps` | Bootstrap apps cluster (all 3 phases) |
| `task bootstrap:preflight CLUSTER=infra` | Run pre-flight checks only |
| `task bootstrap:dry-run CLUSTER=infra` | Show what would be done |

### Phase Commands

| Command | What It Does |
|---------|--------------|
| `task bootstrap:phase:0 CLUSTER=infra` | Apply prerequisites |
| `task bootstrap:phase:1 CLUSTER=infra` | Install CRDs |
| `task bootstrap:phase:2 CLUSTER=infra` | Deploy core infrastructure |
| `task bootstrap:phase:3 CLUSTER=infra` | Validate deployment |

### Status Commands

| Command | What It Does |
|---------|--------------|
| `task bootstrap:status CLUSTER=infra` | Show comprehensive cluster status |
| `task bootstrap:list-crds CLUSTER=infra` | List all VictoriaMetrics CRDs |

### Utility Commands

| Command | What It Does |
|---------|--------------|
| `task bootstrap:clean CLUSTER=infra` | Delete CRDs (DANGEROUS!) |

---

## 🎯 Common Workflows

### First-Time Cluster Bootstrap

```bash
# 1. Authenticate with 1Password (optional but recommended)
eval $(op signin)

# 2. Verify environment
task bootstrap:preflight CLUSTER=infra

# 3. Bootstrap cluster
task bootstrap:infra

# 4. Watch Flux reconciliation
flux get kustomizations --watch
```

### Re-Bootstrap Existing Cluster

```bash
# Safe to re-run - idempotent
task bootstrap:infra
```

### Bootstrap with Custom Context

```bash
task bootstrap:bootstrap CLUSTER=infra CONTEXT=my-prod-cluster
```

### Manual Phase-by-Phase Bootstrap

```bash
# Run each phase manually
task bootstrap:phase:0 CLUSTER=infra  # Prerequisites
task bootstrap:phase:1 CLUSTER=infra  # CRDs
task bootstrap:phase:2 CLUSTER=infra  # Core
task bootstrap:phase:3 CLUSTER=infra  # Validation
```

### Troubleshooting Failed Bootstrap

```bash
# Check status
task bootstrap:status CLUSTER=infra

# Check specific phase
task bootstrap:phase:1 CLUSTER=infra  # Re-run CRDs if needed

# Check Flux logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-instance
```

---

## 🔍 Pre-Flight Checks

### What's Checked

✅ Required tools: `kubectl`, `helmfile`, `yq`
✅ Optional tools: `flux`, `op`
✅ Cluster connectivity
✅ Kubernetes version
✅ Bootstrap files exist

### Example Output

```
🔍 Checking required tools...
  ✅ kubectl
  ✅ helmfile
  ✅ yq
  ✅ flux
  ⚠️  op (optional)

🔍 Checking cluster connectivity...
  ✅ Cluster infra (context: infra) is reachable
  ℹ️  Kubernetes version: v1.30.0

🔍 Checking bootstrap files...
  ✅ resources.yaml
  ✅ 00-crds.yaml
  ✅ 01-core.yaml
  ✅ values.yaml
```

---

## 📊 Status Output Example

```bash
task bootstrap:status CLUSTER=infra
```

```
==============================================
📊 Cluster Status: infra
==============================================

📋 CRD Status:
  VictoriaMetrics CRDs: 14
  Prometheus CRDs: 9

🔧 Core Components:
  Cilium pods: 6
  cert-manager pods: 3
  Flux pods: 5

📊 Flux Kustomizations:
NAME                          READY   MESSAGE
cluster-infra-infrastructure  True    Applied revision: main/abc123
cluster-infra-workloads       True    Applied revision: main/abc123

⚠️  PrometheusRules:
  Total PrometheusRules: 17
==============================================
```

---

## ⚡ Phase Details

### Phase 0: Prerequisites (~30 sec)
- Applies namespaces
- Creates secrets (with 1Password if available)
- Waits for namespaces to be Active

### Phase 1: CRDs (~1-2 min)
- Extracts CRDs from Helm charts
- Applies VictoriaMetrics, cert-manager, external-secrets CRDs
- Waits for CRDs to be Established

### Phase 2: Core Infrastructure (~5-10 min)
- Deploys Cilium, CoreDNS, Spegel
- Deploys cert-manager, external-secrets (apps only)
- Deploys Flux Operator + Instance
- Waits for Flux to be ready

### Phase 3: Validation (~10-30 sec)
- Verifies CRDs installed (expects 14+ VM CRDs)
- Checks Flux Kustomizations are Ready
- Counts PrometheusRule resources

**Total Time:** ~10-15 minutes for complete bootstrap

---

## 🛠️ Required Tools

```bash
# Install all required tools (macOS)
brew install kubectl helmfile yq flux 1password-cli

# Verify installation
kubectl version --client
helmfile version
yq --version
flux version --client
op --version
```

---

## 🔐 1Password Setup

```bash
# Sign in to 1Password
eval $(op signin)

# Verify authentication
op account list

# Bootstrap will automatically inject secrets
task bootstrap:infra
```

**Without 1Password:**
Bootstrap still works but skips secret injection. You'll need to create secrets manually.

---

## 🚨 Common Issues

### Issue: Tool Not Found

```bash
# Install missing tool
brew install helmfile  # or kubectl, yq, etc.
```

### Issue: Cannot Connect to Cluster

```bash
# Check and switch context
kubectl config get-contexts
kubectl config use-context infra
```

### Issue: CRD Wait Timeout

```bash
# Check CRD status
kubectl get crd prometheusrules.monitoring.coreos.com

# Re-run CRD phase
task bootstrap:phase:1 CLUSTER=infra
```

### Issue: Flux Not Ready

```bash
# Check Flux pods
kubectl get pods -n flux-system

# Check logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-instance

# Re-run core phase
task bootstrap:phase:2 CLUSTER=infra
```

---

## 📁 File Structure

```
bootstrap/
├── prerequisites/
│   └── resources.yaml          # Namespaces, secrets
├── helmfile.d/
│   ├── 00-crds.yaml           # CRD extraction
│   └── 01-core.yaml           # Core infrastructure
└── clusters/
    ├── infra/values.yaml      # Infra cluster values
    └── apps/values.yaml       # Apps cluster values
```

---

## 🔗 Related Commands

### Flux Commands

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Force reconciliation
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Check Flux health
flux check
```

### kubectl Commands

```bash
# List CRDs
kubectl get crd | grep victoriametrics

# List PrometheusRules
kubectl get prometheusrules -A

# Check pods
kubectl get pods -A
```

### helmfile Commands

```bash
# List releases
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra list

# Template (dry-run)
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template

# Diff changes
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra diff
```

---

## 💡 Pro Tips

1. **Always run pre-flight checks first**
   ```bash
   task bootstrap:preflight CLUSTER=infra
   ```

2. **Use dry-run to preview changes**
   ```bash
   task bootstrap:dry-run CLUSTER=infra
   ```

3. **Monitor status in separate terminal**
   ```bash
   watch -n 2 'task bootstrap:status CLUSTER=infra'
   ```

4. **Check Flux after bootstrap**
   ```bash
   flux get kustomizations --watch
   ```

5. **Backup before major changes**
   ```bash
   kubectl get crd -o yaml > crds-backup.yaml
   ```

---

## 📚 Full Documentation

- [Taskfile Bootstrap Guide](./TASKFILE-BOOTSTRAP-GUIDE.md) - Complete guide
- [CRD Bootstrap Implementation Plan](./CRD-BOOTSTRAP-IMPLEMENTATION-PLAN.md) - Design details
- [CRD Bootstrap Best Practices](./CRD-BOOTSTRAP-BEST-PRACTICES.md) - Best practices

---

## 🆘 Getting Help

```bash
# List all tasks
task --list-all

# Show task description
task --summary bootstrap:infra

# View Taskfile source
cat .taskfiles/bootstrap/Taskfile.yaml
```

---

**Quick Reference Version:** 1.0
**Last Updated:** 2025-10-15
