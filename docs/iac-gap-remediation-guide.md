# Infrastructure as Code Gap Remediation Guide

**Document Version:** 1.0
**Date:** 2025-10-14
**Status:** Implementation Ready
**Validation Reference:** Infrastructure Validation Section 2

---

## Overview

This guide provides step-by-step instructions to implement the Infrastructure as Code improvements identified during the infrastructure validation. These implementations address gaps in:
1. CI/CD automation
2. High availability protection (PodDisruptionBudgets)
3. Documentation standards
4. GitHub repository governance

**Estimated Total Time:** 3-4 hours
**Priority:** High (Week 1-2 of Phase 1)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Enable GitHub Actions CI/CD](#step-1-enable-github-actions-cicd)
3. [Step 2: Implement PodDisruptionBudgets](#step-2-implement-poddisruptionbudgets)
4. [Step 3: Enable Branch Protection](#step-3-enable-branch-protection)
5. [Step 4: Test and Validate](#step-4-test-and-validate)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- Git access to repository with write permissions
- GitHub account with admin access to repository
- kubectl access to clusters (for PDB testing)

### Repository State
- All files have been created in the repository:
  - `.github/workflows/validate-infrastructure.yaml`
  - `kubernetes/components/pdb/*.yaml`
  - `docs/naming-conventions.md`
  - `docs/iac-gap-remediation-guide.md` (this file)

---

## Step 1: Enable GitHub Actions CI/CD

**Duration:** 30 minutes
**Priority:** High

### 1.1 Commit GitHub Actions Workflow

The CI/CD workflow has been created at `.github/workflows/validate-infrastructure.yaml`.

```bash
# Review the workflow
cat .github/workflows/validate-infrastructure.yaml

# Commit the workflow
git add .github/workflows/validate-infrastructure.yaml
git commit -m "feat(ci): add infrastructure validation workflow

- Validate Kubernetes manifests with Flux CLI
- Lint YAML files with yamllint
- Validate schemas with kubeconform
- Scan for secrets with Gitleaks
- Scan container images with Trivy
- Validate Talos configs

Implements: Infrastructure Validation Section 2 - IaC Gap #1"

git push origin main
```

### 1.2 Verify Workflow Execution

```bash
# Navigate to GitHub repository
open "https://github.com/$(git config --get remote.origin.url | sed 's/.*://;s/.git$//')/actions"

# Or use GitHub CLI
gh workflow list
gh run list --workflow=validate-infrastructure.yaml
```

**Expected Result:** Workflow runs successfully on push to main

### 1.3 Fix Any Validation Errors

If the workflow fails:

```bash
# Check workflow logs
gh run view --log

# Common issues and fixes:
# - Flux build errors: Check Kustomization paths
# - YAML lint errors: Fix formatting issues
# - Schema validation: Update CRD skip list if needed
```

---

## Step 2: Implement PodDisruptionBudgets

**Duration:** 1-2 hours
**Priority:** High

### 2.1 Understand PDB Component Structure

PDBs have been created as Kustomize components:
```
kubernetes/components/pdb/
├── kustomization.yaml
├── cilium-pdb.yaml
├── rook-ceph-mon-pdb.yaml
├── rook-ceph-mgr-pdb.yaml
└── victoria-metrics-pdb.yaml
```

### 2.2 Integrate PDBs into Infrastructure Stack

**Option A: Add to infrastructure Kustomization (Recommended)**

```bash
# Edit infra cluster infrastructure kustomization
cat <<EOF >> kubernetes/infrastructure/kustomization.yaml

components:
  - ../components/pdb
EOF
```

**Option B: Create dedicated PDB overlay**

```bash
# Create PDB overlay in infrastructure
mkdir -p kubernetes/infrastructure/common/pdb

cat <<EOF > kubernetes/infrastructure/common/pdb/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../components/pdb
EOF

# Add to main infrastructure kustomization
cat <<EOF >> kubernetes/infrastructure/kustomization.yaml

resources:
  - common/pdb
EOF
```

### 2.3 Commit PDB Implementation

```bash
git add kubernetes/components/pdb/
git add kubernetes/infrastructure/kustomization.yaml

git commit -m "feat(k8s): add PodDisruptionBudgets for HA services

Implements PDBs for:
- Cilium agent and operator
- Rook Ceph MON (minAvailable: 2/3 for quorum)
- Rook Ceph MGR (minAvailable: 1/2)
- Victoria Metrics components

Ensures minimum availability during node maintenance and upgrades.

Implements: Infrastructure Validation Section 2 - IaC Gap #2"

git push origin main
```

### 2.4 Verify PDB Deployment

```bash
# After Flux reconciles, check PDBs
kubectl get pdb -n kube-system
kubectl get pdb -n rook-ceph
kubectl get pdb -n observability

# Check PDB status
kubectl describe pdb cilium -n kube-system
```

**Expected Output:**
```
NAME             MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
cilium           N/A             1                 1                     5m
cilium-operator  1               N/A               1                     5m
```

### 2.5 Test PDB Protection

```bash
# Simulate node drain to test PDB
NODE_NAME="infra-01"

# Check current pod distribution
kubectl get pods -A -o wide | grep $NODE_NAME

# Attempt drain (will respect PDBs)
kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --dry-run=client

# Expected: Should show warnings if PDB would be violated
```

---

## Step 3: Enable Branch Protection

**Duration:** 15 minutes
**Priority:** High

### 3.1 Enable Branch Protection Rules

Navigate to GitHub repository settings:

```
Settings → Branches → Add branch protection rule
```

**Configuration:**
```yaml
Branch name pattern: main

Protection rules:
  ✅ Require a pull request before merging
     - Required approvals: 1 (or 0 for single-person projects)
     - Dismiss stale pull request approvals when new commits are pushed
     - Require review from Code Owners (optional)

  ✅ Require status checks to pass before merging
     - Require branches to be up to date before merging
     - Status checks required:
       ✅ validate-kubernetes-manifests
       ✅ lint-yaml
       ✅ validate-schemas
       ✅ check-secrets
       ✅ validate-talos-configs

  ✅ Require conversation resolution before merging

  ⚠️ Include administrators (optional for home lab)

  ✅ Require linear history
```

### 3.2 Verify Branch Protection

```bash
# Test by pushing directly to main (should fail)
echo "test" > test.txt
git add test.txt
git commit -m "test: direct push to main"
git push origin main

# Expected: Push rejected due to branch protection

# Clean up
git reset --hard HEAD~1
```

### 3.3 Create Pull Request Workflow

```bash
# Create feature branch
git checkout -b feature/test-pr

# Make changes
echo "# Test PR" >> README.md
git add README.md
git commit -m "docs: test pull request workflow"

# Push branch
git push origin feature/test-pr

# Create PR using GitHub CLI
gh pr create \
  --title "Test: PR workflow with CI checks" \
  --body "Testing branch protection and CI/CD validation"

# Wait for CI checks to complete
gh pr checks

# Merge PR after checks pass
gh pr merge --squash
```

---

## Step 4: Test and Validate

**Duration:** 30 minutes

### 4.1 End-to-End CI/CD Test

```bash
# Create test branch
git checkout -b test/cicd-validation

# Make intentional error (invalid YAML)
cat <<EOF >> kubernetes/test-invalid.yaml
apiVersion: v1
kind: Pod
metadata
  name: test  # Missing colon - syntax error
EOF

git add kubernetes/test-invalid.yaml
git commit -m "test: invalid YAML for CI validation"
git push origin test/cicd-validation

# Create PR
gh pr create --title "Test: CI should catch this error" --body "Intentional YAML syntax error"

# Check CI results
gh pr checks

# Expected: YAML lint check should fail
# Clean up
git checkout main
git branch -D test/cicd-validation
gh pr close <PR-number>
```

### 4.2 Test PDB During Maintenance

```bash
# Check Ceph MON distribution
kubectl get pods -n rook-ceph -l app=rook-ceph-mon -o wide

# Drain node with 1 MON (should succeed - 2/3 remain)
kubectl drain infra-01 --ignore-daemonsets --delete-emptydir-data --timeout=5m

# Check PDB status during drain
kubectl get pdb rook-ceph-mon -n rook-ceph -w

# Uncordon node
kubectl uncordon infra-01

# Attempt to drain node with 2 MONs (should block - violates quorum)
# This validates PDB is working correctly
```

---

## Verification

### CI/CD Verification Checklist

- [ ] GitHub Actions workflow runs on every push to main
- [ ] Workflow validates all Kubernetes manifests successfully
- [ ] YAML linting catches formatting issues
- [ ] Schema validation detects invalid CRDs
- [ ] Secret scanning detects leaked credentials
- [ ] Container image scanning reports vulnerabilities
- [ ] Talos config validation succeeds
- [ ] Workflow fails on errors (doesn't false-pass)
- [ ] GitHub PR checks block merge on failure

### PDB Verification Checklist

- [ ] PDBs deployed in all target namespaces
- [ ] `kubectl get pdb -A` shows all expected PDBs
- [ ] PDB allowed disruptions match expected values
- [ ] Node drain respects PDBs (tested)
- [ ] Flux reconciles PDBs without drift
- [ ] PDB status shows current allowed disruptions

### Documentation Verification

- [ ] Naming conventions documented
- [ ] PDB usage patterns documented
- [ ] CI/CD workflow documented
- [ ] Branch protection documented
- [ ] Team understands new processes

---

## Troubleshooting

### Issue: GitHub Actions Workflow Fails

**Symptoms:**
- CI checks fail on valid manifests
- Flux validation errors

**Resolution:**
```bash
# Run Flux validation locally
flux build kustomization cluster-infra-infrastructure \
  --path ./kubernetes/infrastructure \
  --kustomization-file ./kubernetes/clusters/infra/infrastructure.yaml

# Check for path mismatches
# Verify postBuild.substitute variables are defined
```

### Issue: PDB Not Working

**Symptoms:**
- Node drain evicts pods despite PDB
- `kubectl get pdb` shows 0 allowed disruptions always

**Resolution:**
```bash
# Check if PDB selectors match pod labels
kubectl get pod -n rook-ceph -l app=rook-ceph-mon --show-labels

# Verify PDB is targeting correct pods
kubectl describe pdb rook-ceph-mon -n rook-ceph

# Check for pod controller issues
kubectl get deployment,statefulset,daemonset -n rook-ceph
```

### Issue: Branch Protection Too Strict

**Symptoms:**
- Can't push urgent hotfixes
- CI checks block critical changes

**Resolution:**
1. **Temporary bypass (emergencies only):**
   - GitHub Settings → Branches → Edit rule
   - Temporarily disable "Include administrators"
   - Make emergency push
   - Re-enable protection immediately

2. **Use emergency PR workflow:**
   ```bash
   # Create emergency PR with override label
   gh pr create --title "[EMERGENCY] Critical fix" --label emergency
   # Merge after single approval
   ```

### Issue: Flux Doesn't Reconcile PDBs

**Symptoms:**
- PDBs not appearing in cluster
- Flux shows no errors

**Resolution:**
```bash
# Force Flux reconciliation
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Check Flux logs
flux logs --level=error

# Verify component is included
kubectl get kustomization -n flux-system cluster-infra-infrastructure -o yaml | grep -A5 components
```

---

## Post-Implementation

### Ongoing Maintenance

1. **Monitor CI/CD Health:**
   ```bash
   # Weekly check of recent workflow runs
   gh run list --workflow=validate-infrastructure.yaml --limit 20
   ```

2. **Review PDB Effectiveness:**
   ```bash
   # Monthly: Check PDB violations/adjustments
   kubectl get events -A | grep PodDisruptionBudget
   ```

3. **Update Documentation:**
   - Document any new naming patterns
   - Update this guide with lessons learned
   - Maintain runbooks for common issues

### Success Metrics

**CI/CD:**
- 100% of PRs run through CI validation
- < 5% false positive rate
- Average validation time < 3 minutes

**PDBs:**
- Zero service outages during node maintenance
- Zero quorum losses for Ceph MONs
- Zero unplanned pod evictions

**Developer Experience:**
- PR cycle time < 30 minutes (including CI)
- < 10% of PRs blocked by CI failures
- Team understands and follows naming conventions

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Flux CI/CD Best Practices](https://fluxcd.io/flux/guides/ci-cd/)
- [Naming Conventions](./naming-conventions.md)

---

**Status:** ✅ Implementation Ready
**Next Review:** After Phase 1 deployment
**Owner:** Platform Team
