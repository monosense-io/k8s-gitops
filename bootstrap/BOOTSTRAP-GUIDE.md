# Greenfield Bootstrap Guide - Flux Operator

This guide walks through the complete bootstrap process for a greenfield Talos Kubernetes cluster using the flux-operator pattern.

## Architecture Overview

```
Day 0 (Helmfile Bootstrap):
  1. Prerequisites (manual) → External Secrets namespace + 1Password secret
  2. Helmfile sync → Cilium → CoreDNS → Spegel → cert-manager → flux-operator → flux-instance
  3. Helmfile hook → Apply GitRepository + Kustomization

Day 1+ (Flux-managed):
  4. Flux reconciles → kubernetes/infrastructure/ → All infrastructure components
  5. Flux reconciles → kubernetes/workloads/ → All workload components
  6. Flux self-manages → Updates to gitops/ directory are applied by Flux itself
```

## Prerequisites

Before starting, ensure you have:

- ✅ **Talos cluster running** - Nodes bootstrapped and ready
- ✅ **kubeconfig** - Access to cluster API
- ✅ **1Password Connect** - Running at `https://op-connect.monosense.io`
- ✅ **1Password CLI** - For injecting secrets (optional)
- ✅ **Helmfile** - Version >= 0.150.0
- ✅ **Kubectl** - Latest version
- ✅ **Flux CLI** - For validation (optional)

### Verify Prerequisites

```bash
# Check Talos cluster
talosctl version
kubectl cluster-info

# Check tools
helmfile --version
kubectl version --client
flux --version

# Verify 1Password Connect (optional)
curl -s https://op-connect.monosense.io/health | jq
```

## Step 1: Prepare Prerequisites

### Option A: Using 1Password CLI (Recommended)

```bash
# Inject 1Password credentials and apply
op inject -i bootstrap/prerequisites/resources.yaml | kubectl apply -f -
```

### Option B: Manual Secret Creation

```bash
# Get credentials from 1Password
export OP_TOKEN="<your-op-connect-token>"
export OP_CREDS="<your-op-credentials-json>"

# Create secret manually
kubectl create namespace external-secrets
kubectl create namespace flux-system

kubectl create secret generic onepassword-connect \
  --namespace external-secrets \
  --from-literal=token="$OP_TOKEN" \
  --from-literal=1password-credentials.json="$OP_CREDS"
```

### Option C: Pre-populated YAML

```bash
# Edit the file and replace placeholders
vi bootstrap/prerequisites/resources.yaml

# Apply manually
kubectl apply -f bootstrap/prerequisites/resources.yaml
```

## Step 2: Bootstrap Cluster with Helmfile

### For Infra Cluster

```bash
# Navigate to bootstrap directory
cd bootstrap

# Dry-run first (recommended)
helmfile -e infra diff

# Bootstrap the cluster
helmfile -e infra sync

# Monitor progress
watch -n 2 'kubectl get pods -A | grep -v Running'
```

### For Apps Cluster

```bash
# Navigate to bootstrap directory
cd bootstrap

# Bootstrap the apps cluster
helmfile -e apps sync

# Monitor progress
watch -n 2 'kubectl get pods -A | grep -v Running'
```

### What Helmfile Does

The helmfile will:

1. **Install Cilium CNI** (kube-system)
   - Pod networking and service load balancing
   - Gateway API support
   - BGP control plane (if enabled)

2. **Install CoreDNS** (kube-system)
   - Cluster DNS resolution
   - Custom cluster IP configuration

3. **Install Spegel** (kube-system)
   - Local registry mirror for faster image pulls
   - Reduces external registry dependencies

4. **Install cert-manager** (cert-manager)
   - Certificate lifecycle management
   - Required for many infrastructure components

5. **Install External Secrets** (external-secrets)
   - 1Password integration
   - Secret synchronization from external sources

6. **Install flux-operator** (flux-system)
   - Flux lifecycle manager
   - Manages Flux controllers

7. **Install flux-instance** (flux-system)
   - Deploys all 6 Flux controllers:
     - source-controller
     - kustomize-controller
     - helm-controller
     - notification-controller
     - image-reflector-controller
     - image-automation-controller

8. **Apply GitRepository + Kustomization** (via postsync hook)
   - Creates GitRepository pointing to this repo
   - Creates initial Kustomization for cluster config
   - Flux begins managing the cluster

## Step 3: Verify Bootstrap

### Check All Pods Running

```bash
# All namespaces
kubectl get pods -A

# Expected namespaces with pods:
# - kube-system: cilium, coredns, spegel
# - cert-manager: cert-manager, webhook, cainjector
# - external-secrets: external-secrets
# - flux-system: flux-operator, source-controller, kustomize-controller, helm-controller, notification-controller
```

### Check Flux Status

```bash
# Using Flux CLI
flux check
flux get all -A

# Expected output:
# ✔ flux-instance ready
# ✔ GitRepository/flux-system ready
# ✔ Kustomization/cluster-config ready
```

### Check Flux Operator

```bash
# Check flux-operator deployment
kubectl get deployment -n flux-system flux-operator
kubectl logs -n flux-system deployment/flux-operator --tail=50

# Check flux-instance
kubectl get fluxinstance -n flux-system
kubectl describe fluxinstance -n flux-system flux
```

### Check GitOps Sync

```bash
# Check GitRepository
kubectl get gitrepository -n flux-system flux-system -o yaml

# Check Kustomizations
kubectl get kustomizations -n flux-system

# Expected Kustomizations:
# - cluster-config (points to kubernetes/clusters/{cluster}/)
# - cluster-infra-infrastructure (points to kubernetes/infrastructure/)
# - cluster-infra-workloads (points to kubernetes/workloads/)
```

## Step 4: Monitor Reconciliation

### Watch Flux Reconciliation

```bash
# Watch all Flux resources
flux get all -A --watch

# Watch specific Kustomization
flux get kustomization cluster-infra-infrastructure --watch

# Check reconciliation logs
flux logs --all-namespaces --follow
```

### Check Infrastructure Deployment

```bash
# Watch pods across all namespaces
watch -n 2 'kubectl get pods -A'

# Check HelmReleases
kubectl get helmreleases -A

# Check for any errors
kubectl get kustomizations -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\t"}{.status.conditions[?(@.type=="Ready")].message}{"\n"}{end}'
```

## Step 5: Verify Monitoring (Optional)

### Check Prometheus Scraping

```bash
# Verify ServiceMonitors created
kubectl get servicemonitors -n flux-system

# Check PrometheusRules
kubectl get prometheusrules -n flux-system

# Expected resources:
# - ServiceMonitor for flux-operator
# - ServiceMonitor for each Flux controller
# - PrometheusRule for flux-instance alerts
```

### Flux Metrics

```bash
# Port-forward to source-controller
kubectl port-forward -n flux-system svc/source-controller 8080:80

# Query metrics
curl http://localhost:8080/metrics | grep flux_
```

## Step 6: Configure GitHub Webhook (Optional)

For instant reconciliation instead of polling:

1. **Get Webhook URL**:
```bash
kubectl get httproute -n flux-system flux-webhook -o jsonpath='{.spec.hostnames[0]}'
# Expected: flux-webhook.monosense.io
```

2. **Get Webhook Secret**:
```bash
# After External Secrets reconciles
kubectl get secret -n flux-system github-webhook-token-secret -o jsonpath='{.data.token}' | base64 -d
```

3. **Configure GitHub**:
   - Go to repository Settings → Webhooks
   - URL: `https://flux-webhook.monosense.io/hook/flux-system`
   - Content type: `application/json`
   - Secret: (paste the token from step 2)
   - Events: Just the push event
   - Active: ✓

4. **Test Webhook**:
```bash
# Push a change to the repo
git commit --allow-empty -m "test: webhook"
git push

# Watch for immediate reconciliation
flux get kustomizations --watch
```

## Troubleshooting

### Helmfile Fails

```bash
# Check specific release
helmfile -e infra status

# Re-sync specific release
helmfile -e infra -l name=cilium sync

# Clean up and retry
helmfile -e infra destroy
helmfile -e infra sync
```

### Flux Not Starting

```bash
# Check flux-operator logs
kubectl logs -n flux-system deployment/flux-operator --tail=100

# Check flux-instance status
kubectl describe fluxinstance -n flux-system flux

# Verify flux-instance pods
kubectl get pods -n flux-system -l app.kubernetes.io/part-of=flux
```

### GitRepository Not Syncing

```bash
# Check GitRepository status
kubectl describe gitrepository -n flux-system flux-system

# Common issues:
# - Git URL not accessible
# - Branch doesn't exist
# - Path doesn't exist

# Fix and reconcile
flux reconcile source git flux-system
```

### Kustomization Failures

```bash
# Check Kustomization status
kubectl describe kustomization -n flux-system cluster-infra-infrastructure

# View detailed error
kubectl get kustomization -n flux-system cluster-infra-infrastructure -o yaml

# Common issues:
# - Invalid YAML syntax
# - Missing resources
# - Dependency not ready
# - Variable substitution failed

# Force reconcile
flux reconcile kustomization cluster-infra-infrastructure --with-source
```

### HelmRelease Issues

```bash
# Check HelmRelease status
kubectl get helmreleases -A

# Describe specific HelmRelease
kubectl describe helmrelease -n <namespace> <name>

# Force reconcile
flux reconcile helmrelease -n <namespace> <name>
```

## Rollback Procedures

### Rollback Entire Bootstrap

```bash
# Delete everything installed by helmfile
helmfile -e infra destroy

# Clean up flux resources
kubectl delete namespace flux-system --force --grace-period=0

# Re-bootstrap
helmfile -e infra sync
```

### Rollback Single Component

```bash
# Suspend Flux reconciliation
flux suspend kustomization cluster-infra-infrastructure

# Manually revert component
kubectl delete helmrelease -n <namespace> <name>

# Re-apply from git
git revert <commit>
git push

# Resume Flux
flux resume kustomization cluster-infra-infrastructure
```

## Post-Bootstrap Checklist

- [ ] All helmfile releases deployed successfully
- [ ] flux-operator running
- [ ] flux-instance ready
- [ ] All 6 Flux controllers running
- [ ] GitRepository synced
- [ ] Initial Kustomizations reconciled
- [ ] Infrastructure components deploying
- [ ] No failing Kustomizations
- [ ] No failing HelmReleases
- [ ] Prometheus monitoring configured
- [ ] GitHub webhook configured (optional)
- [ ] Team notified of successful bootstrap

## Next Steps

After successful bootstrap:

1. **Review Infrastructure Deployment**
   ```bash
   flux get kustomizations
   kubectl get helmreleases -A
   ```

2. **Configure Additional Secrets**
   - Update ExternalSecret resources for apps
   - Verify 1Password integration

3. **Deploy Workloads**
   - Workloads will auto-deploy via Flux
   - Monitor with `flux get kustomizations --watch`

4. **Set Up Monitoring**
   - Verify Grafana dashboards
   - Configure alerting rules
   - Set up notification providers

5. **Documentation**
   - Document any cluster-specific configurations
   - Update runbooks
   - Train team on Flux workflows

## Architecture Comparison

### Before (Traditional Flux)
```
flux bootstrap github → Installs Flux → Flux manages everything
```

### After (Flux Operator)
```
helmfile sync → Installs flux-operator + flux-instance → Flux manages everything (including itself)
```

### Benefits
- ✅ Precise control over bootstrap order
- ✅ CNI installed before Flux (critical for Talos)
- ✅ Flux as operator pattern (better lifecycle management)
- ✅ Same helmfile for multiple clusters (infra, apps)
- ✅ Flux self-manages upgrades via GitOps
- ✅ Repeatable, declarative bootstrap

## Additional Resources

- **Flux Operator Docs**: https://fluxcd.control-plane.io/operator/
- **Helmfile Docs**: https://helmfile.readthedocs.io/
- **Talos + Flux**: https://www.talos.dev/v1.6/kubernetes-guides/configuration/gitops/
- **Repository**: https://github.com/monosense-io/k8s-gitops

---

**Last Updated**: 2025-10-15
**Tested On**: Talos v1.8.x, Kubernetes v1.31.x
