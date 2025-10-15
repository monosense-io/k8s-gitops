# GitHub Actions Runner Controller - Deployment Guide

## Overview

This directory contains the deployment configuration for GitHub Actions Runner Controller (ARC), enabling self-hosted GitHub Actions runners in your Kubernetes cluster.

**Architecture:**
- **Controller**: Webhook server that receives job notifications from GitHub
- **Runner Scale Sets**: Auto-scaling runner pods that execute workflow jobs
- **Authentication**: GitHub App with fine-grained permissions
- **Storage**: OpenEBS local hostpath for fast I/O (25Gi per runner)
- **Scaling**: 0-3 runners (scale from zero, cost-effective)
- **RBAC**: Scoped GitOps permissions (not cluster-admin)

## Prerequisites

### ✅ Infrastructure Requirements

These components must be deployed and operational before deploying ARC:

1. **Flux GitOps** - Already bootstrapped ✓
2. **External Secrets Operator** - `kubernetes/infrastructure/security/external-secrets/` ✓
3. **1Password Connect** - ClusterSecretStore configured ✓
4. **OpenEBS** - `kubernetes/infrastructure/storage/openebs/` ✓
5. **Cilium** - LoadBalancer support for webhook ingress ✓

### ⚠️ External Setup Required

Complete these steps before deploying:

#### 1. Create GitHub App

1. Navigate to: **GitHub Organization/Repo → Settings → Developer settings → GitHub Apps → New GitHub App**

2. **App Configuration:**
   ```
   Name: k8s-gitops-runner
   Description: Self-hosted GitHub Actions runners for GitOps automation
   Homepage URL: https://github.com/YOUR-ORG/k8s-gitops
   Webhook: ✅ Active
   Webhook URL: https://PENDING-WILL-SET-AFTER-DEPLOY/webhook
   Webhook Secret: [generate random string, save it]
   ```

3. **Repository Permissions:**
   ```
   ✅ Actions: Read & Write
   ✅ Administration: Read & Write
   ✅ Checks: Read & Write
   ✅ Contents: Read
   ✅ Metadata: Read (default)
   ✅ Workflows: Read & Write
   ```

4. **Subscribe to Events:**
   ```
   ✅ Workflow job
   ```

5. **Installation:**
   ```
   ⚪ Only on this account
   ```

6. **Actions:**
   - Click **Create GitHub App**
   - Click **Generate a private key** (downloads `.pem` file)
   - Click **Install App** → Select your repository
   - Note the **Installation ID** from URL: `https://github.com/settings/installations/{INSTALLATION_ID}`

7. **Collect Credentials:**
   ```
   App ID: [from app settings page]
   Installation ID: [from URL above]
   Private Key: [content of downloaded .pem file]
   ```

#### 2. Store Credentials in 1Password

Create a new item in your 1Password vault:

```
Item Name: actions-runner-github-app
Vault: [your infrastructure vault]

Fields:
┌──────────────────────────────────────────────┐
│ github_app_id: 123456                        │
│ github_app_installation_id: 789012           │
│ github_app_private_key:                      │
│   -----BEGIN RSA PRIVATE KEY-----           │
│   MIIEpAIBAAKCAQEA...                        │
│   -----END RSA PRIVATE KEY-----             │
└──────────────────────────────────────────────┘
```

**CRITICAL:** Backup the `.pem` file securely outside the cluster!

## Configuration

### Update Flux Variables

**File:** `kubernetes/clusters/infra/flux-system/kustomization.yaml` (or your postBuild.substitute location)

Add these variables:

```yaml
postBuild:
  substitute:
    # ... existing variables ...

    # GitHub Actions Runner Configuration
    GITHUB_CONFIG_URL: "https://github.com/YOUR-ORG/k8s-gitops"  # ⚠️ UPDATE THIS
    EXTERNAL_SECRET_STORE: "onepassword"                        # Usually already set
    OPENEBS_STORAGE_CLASS: "openebs-hostpath"                   # Usually already set
```

**Important:** Update `GITHUB_CONFIG_URL` to match your repository!

## Deployment

### Step 1: Commit and Push

```bash
# From repository root
cd /Users/monosense/iac/k8s-gitops

# Review what will be deployed
git status

# Add all files
git add kubernetes/bases/actions-runner-controller
git add kubernetes/workloads/platform/cicd
git add kubernetes/workloads/platform/kustomization.yaml

# Commit
git commit -m "feat(cicd): Add GitHub Actions Runner Controller

- Add base definitions for controller and runner scale sets
- Implement k8s-gitops runner instance with scoped RBAC
- Configure autoscaling (0-3 runners) with 25Gi storage
- Integrate with External Secrets and OpenEBS
- Deploy to infra cluster via platform workloads

Resolves: Self-hosted runners for GitOps automation"

# Push to trigger Flux reconciliation
git push
```

### Step 2: Monitor Deployment

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Expected output:
# NAME                    READY   MESSAGE
# platform                True    Applied revision: main/abc123
# ...

# Check namespace creation
kubectl get namespace actions-runner-system

# Check controller deployment
kubectl -n actions-runner-system get pods -w

# Expected: actions-runner-controller pod running within 2-3 minutes
```

### Step 3: Get LoadBalancer IP

```bash
kubectl -n actions-runner-system get svc actions-runner-controller

# Expected output:
# NAME                        TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# actions-runner-controller   LoadBalancer   10.43.x.x      192.168.1.100    443:xxxxx/TCP

# Note the EXTERNAL-IP
```

### Step 4: Update GitHub App Webhook

1. Navigate to: **GitHub App Settings → General → Webhook**
2. Update **Webhook URL** to: `https://[EXTERNAL-IP]/webhook`
3. Click **Save changes**
4. Click **Recent Deliveries** → **Redeliver** on test ping
5. Verify delivery succeeds (green checkmark)

### Step 5: Verify Runner Registration

```bash
# Check AutoscalingRunnerSet CRD
kubectl -n actions-runner-system get autoscalingrunnerset

# Expected output:
# NAME                DESIRED   RUNNING   IDLE   MIN   MAX   AGE
# k8s-gitops-runner   0         0         0      0     3     5m
```

**GitHub UI Verification:**
1. Navigate to: **Repository → Settings → Actions → Runners**
2. Should see: **k8s-gitops-runner** (scale set)
3. Status: **Idle** (green) or **Offline** initially

## Testing

### Create Test Workflow

Create `.github/workflows/test-runner.yml`:

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test-runner:
    runs-on: k8s-gitops-runner  # Must match scale set name
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Test runner environment
        run: |
          echo "🎉 Running on self-hosted Kubernetes runner!"
          echo "Runner: $RUNNER_NAME"
          echo "OS: $RUNNER_OS"
          echo "Arch: $RUNNER_ARCH"
          uname -a

      - name: Test kubectl access
        run: |
          kubectl version --client
          kubectl get namespaces

      - name: Test Flux access
        run: |
          flux --version || echo "flux not installed, install in workflow"
          kubectl get kustomizations -n flux-system

      - name: Test workspace
        run: |
          df -h $GITHUB_WORKSPACE
          echo "Workspace path: $GITHUB_WORKSPACE"
```

### Run Test Workflow

1. Go to: **Actions tab** in GitHub
2. Select: **Test Self-Hosted Runner**
3. Click: **Run workflow** → **Run workflow**
4. Observe:
   - Workflow enters queue
   - Runner pod created (watch: `kubectl -n actions-runner-system get pods -w`)
   - Workflow executes
   - Pod deleted after completion

**Expected Timeline:**
- Queue → Runner start: 30-60 seconds (cold start)
- Workflow execution: ~1-2 minutes
- Pod cleanup: 30 seconds after completion

### Monitor Scaling

Terminal 1 - Watch pods:
```bash
watch kubectl -n actions-runner-system get pods
```

Terminal 2 - Watch scale set:
```bash
watch kubectl -n actions-runner-system get autoscalingrunnerset
```

Terminal 3 - Controller logs:
```bash
kubectl -n actions-runner-system logs -l app.kubernetes.io/name=actions-runner-controller -f
```

## Validation Checklist

- [ ] Controller pod running (1/1 Ready)
- [ ] LoadBalancer service has external IP
- [ ] GitHub App webhook configured and delivering
- [ ] Runner scale set registered in GitHub UI
- [ ] Test workflow completes successfully
- [ ] Runner pod scales up on job queue
- [ ] Runner pod scales down after job completion
- [ ] Storage PVC created and bound
- [ ] External Secret created k8s secret
- [ ] No errors in controller logs

## Troubleshooting

### Controller Pod Crashing

**Check logs:**
```bash
kubectl -n actions-runner-system logs -l app.kubernetes.io/name=actions-runner-controller --tail=100
```

**Common causes:**
- GitHub App credentials invalid
- ExternalSecret not creating secret
- Network connectivity to GitHub API

**Resolution:**
```bash
# Verify secret exists
kubectl -n actions-runner-system get secret k8s-gitops-runner-secret -o yaml

# Check External Secret status
kubectl -n actions-runner-system describe externalsecret k8s-gitops-runner

# Test GitHub API connectivity from pod
kubectl -n actions-runner-system run test-github --rm -it --image=curlimages/curl -- \
  curl -v https://api.github.com
```

### Runners Not Scaling

**Check controller logs:**
```bash
kubectl -n actions-runner-system logs -l app.kubernetes.io/name=actions-runner-controller | grep -i webhook
```

**Common causes:**
- Webhook not reaching controller (firewall/LoadBalancer)
- GitHub App not installed on repository
- Wrong `runs-on` label in workflow

**Resolution:**
```bash
# Test webhook endpoint
curl -k https://[LOADBALANCER-IP]/webhook

# Check AutoscalingRunnerSet
kubectl -n actions-runner-system describe autoscalingrunnerset k8s-gitops-runner

# Manually trigger webhook from GitHub App settings → Recent Deliveries
```

### Permission Denied Errors

**Check workflow logs for:**
```
Error: Unauthorized: You must be logged in to the server
```

**Resolution:**
```bash
# Verify ServiceAccount exists
kubectl -n actions-runner-system get sa k8s-gitops-runner

# Check ClusterRoleBinding
kubectl get clusterrolebinding k8s-gitops-runner -o yaml

# If needed, escalate to cluster-admin (understand security implications!)
# Edit: kubernetes/workloads/platform/cicd/actions-runner/runners/k8s-gitops/rbac.yaml
# Change roleRef.name to: cluster-admin
```

### Storage Issues

**Check PVC:**
```bash
kubectl -n actions-runner-system get pvc
kubectl -n actions-runner-system describe pvc
```

**Common causes:**
- OpenEBS not deployed
- No available hostpath capacity on nodes

**Resolution:**
```bash
# Verify OpenEBS pods running
kubectl -n openebs-system get pods

# Check node storage capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,STORAGE:.status.capacity.ephemeral-storage

# Reduce storage if needed (edit helmrelease.yaml)
# Change: storage: 15Gi  (from 25Gi)
```

## Operations

### Scaling Adjustment

**Increase max runners:**

Edit `kubernetes/workloads/platform/cicd/actions-runner/runners/k8s-gitops/helmrelease.yaml`:

```yaml
maxRunners: 5  # Change from 3 to 5
```

Commit and push. Flux will reconcile automatically.

### Runner Image Update

**Update to specific version:**

```yaml
image: ghcr.io/actions/actions-runner:2.320.0
```

**Or pin by digest:**

```yaml
image: ghcr.io/actions/actions-runner:2.320.0@sha256:abc123...
```

### Emergency Stop

**Stop all runners:**

```bash
kubectl -n actions-runner-system scale autoscalingrunnerset k8s-gitops-runner \
  --replicas=0
```

**Or suspend via Flux:**

```bash
flux suspend kustomization cicd-actions-runner-runners
```

## Architecture Decisions

### Why Scoped RBAC (Not cluster-admin)?

**Our implementation uses GitOps-scoped permissions:**
- ✅ Reduced blast radius if compromised
- ✅ Follows principle of least privilege
- ✅ Can expand incrementally as needed

**Buroa uses cluster-admin:**
- Required for Talos OS upgrades (os:admin role)
- Full cluster management automation
- Higher security risk

**To escalate to cluster-admin:**
Edit `rbac.yaml` ClusterRoleBinding:
```yaml
roleRef:
  kind: ClusterRole
  name: cluster-admin  # Change from k8s-gitops-runner
```

### Why minRunners: 0?

**Scale from zero:**
- ✅ Cost-effective (no idle runners)
- ✅ Pay only for actual usage
- ❌ Cold start delay (30-60s)

**If you prefer warm pool (minRunners: 1):**
- ✅ Instant job execution
- ✅ No cold start delay
- ❌ Resources consumed 24/7

Edit `helmrelease.yaml`: `minRunners: 1`

## Next Steps

### Production Enhancements

1. **Custom Runner Image**
   - Pre-install tools (kubectl, flux, kustomize, etc.)
   - Build and push to Harbor registry
   - Update `image:` in helmrelease.yaml

2. **Monitoring**
   - Add ServiceMonitor for metrics
   - Create Prometheus alerts
   - Build Grafana dashboard

3. **Security Hardening**
   - Implement NetworkPolicy
   - Add PodDisruptionBudget
   - Regular vulnerability scanning
   - Rotate GitHub App credentials quarterly

4. **Multi-Cluster**
   - Deploy to apps cluster
   - Create runner scale sets for different repos
   - Separate infrastructure vs application CI/CD

## Resources

- **Official Docs:** https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller
- **ARC Repository:** https://github.com/actions/actions-runner-controller
- **Base Definitions:** `kubernetes/bases/actions-runner-controller/`
- **Buroa Reference:** Analyzed implementation from buroa/k8s-gitops

## Support

For issues or questions:
1. Check controller logs
2. Review GitHub App webhook deliveries
3. Consult troubleshooting section above
4. Review ARC GitHub issues

---

**Deployed:** TBD
**Version:** ARC 0.12.1
**Runner Image:** ghcr.io/actions/actions-runner:latest
**Scaling:** 0-3 runners
**Storage:** 25Gi per runner (openebs-hostpath)
