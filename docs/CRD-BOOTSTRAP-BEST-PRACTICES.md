# CRD Bootstrap Best Practices & Recommendations
## Platform Engineering Guidelines for Multi-Cluster Kubernetes

**Author:** Alex - DevOps Infrastructure Specialist
**Date:** 2025-10-15
**Audience:** Platform Engineers, SREs, DevOps Teams

---

## Overview

This document provides best practices and recommendations for implementing CustomResourceDefinition (CRD) bootstrap patterns in Kubernetes, based on research of production-grade GitOps repositories and enterprise SRE practices.

---

## Core Principles

### 1. **CRDs First, Applications Second**

**Principle:**
CustomResourceDefinitions MUST be installed before any resources that depend on them.

**Why:**
- Kubernetes API server rejects resources for which CRDs don't exist
- Race conditions cause deployment failures and GitOps reconciliation loops
- Dependency order violations create unpredictable cluster state

**Implementation:**
```
Phase 1: Install CRDs (cluster-scoped metadata)
Phase 2: Deploy applications that create custom resources
```

**Anti-Pattern:**
```
❌ Deploy operator with crds: CreateReplace
❌ Simultaneously deploy resources depending on operator CRDs
❌ Rely on timing/retries to resolve race conditions
```

---

### 2. **Separate CRD Lifecycle from Application Lifecycle**

**Principle:**
CRDs should be managed independently from the operators/controllers that use them.

**Why:**
- CRDs are cluster-wide primitives (like built-in resources)
- Upgrading operators shouldn't risk CRD corruption
- Multiple applications may depend on same CRDs
- Helm's CRD management has limitations (can't upgrade/delete)

**Implementation:**
- Use separate Helm chart for CRDs (e.g., `victoria-metrics-operator-crds`)
- Deploy CRDs during bootstrap/infrastructure phase
- Deploy operators/applications in subsequent phase
- Upgrade CRDs explicitly with validation

**Helm CRD Limitations:**
| Operation | Helm Behavior | Impact |
|-----------|---------------|--------|
| Install | CRDs installed if `crds/` directory exists | ✅ Works |
| Upgrade | CRDs **NOT** upgraded | ⚠️ Stale CRDs |
| Uninstall | CRDs **NOT** deleted | ⚠️ Manual cleanup required |

**Solution:** Use dedicated CRD charts or CRD extraction pattern.

---

### 3. **Make Bootstrap Idempotent and Repeatable**

**Principle:**
Bootstrap process should be executable multiple times without side effects.

**Why:**
- Disaster recovery requires re-bootstrap capability
- Development/staging environments need consistent deployment
- Infrastructure-as-Code principles require deterministic outcomes
- Testing bootstrap process should not require cluster rebuild

**Implementation:**
- Use `kubectl apply` (not `create`) for declarative resources
- Use helmfile with `--wait` and `--cleanup-on-fail`
- Validate prerequisites before starting bootstrap
- Provide rollback mechanisms

**Example - Idempotent Script:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Prerequisites check
kubectl get namespace external-secrets 2>/dev/null || \
  kubectl create namespace external-secrets

# CRD installation (idempotent)
helmfile -f 00-crds.yaml template | kubectl apply -f -

# Wait for CRDs to be established
kubectl wait --for condition=established \
  crd/prometheusrules.monitoring.coreos.com \
  --timeout=60s

# Core infrastructure (idempotent via helmfile)
helmfile -f 01-core.yaml sync
```

---

### 4. **Explicit Over Implicit Dependencies**

**Principle:**
Declare dependencies explicitly rather than relying on timing or retries.

**Why:**
- Implicit dependencies hide infrastructure complexity
- Timing-based solutions are fragile and environment-specific
- Explicit dependencies enable validation and testing
- Clear dependencies improve troubleshooting

**Implementation:**

**Helmfile Dependencies:**
```yaml
releases:
  - name: coredns
    needs: ['kube-system/cilium']  # Explicit dependency

  - name: cert-manager
    needs: ['kube-system/coredns']  # Explicit dependency

  - name: external-secrets
    needs: ['cert-manager/cert-manager']  # Explicit dependency
```

**Flux Kustomization Dependencies:**
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
spec:
  dependsOn:
    - name: flux-repositories  # Explicit dependency
      namespace: flux-system
  path: ./kubernetes/infrastructure
```

**Anti-Pattern:**
```yaml
# ❌ No dependencies declared
# ❌ Relies on Flux retry logic
# ❌ Hope that resources apply in correct order
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
spec:
  path: ./kubernetes/infrastructure  # Contains PrometheusRules
  # Missing: dependsOn for CRD installation
```

---

### 5. **Version Pinning for Stability**

**Principle:**
Pin CRD versions explicitly, upgrade consciously and with validation.

**Why:**
- CRD schema changes can break existing custom resources
- Kubernetes API compatibility requires careful CRD versioning
- Automated CRD upgrades risk production outages
- Rollback of CRD changes is complex (can't delete without deleting CRs)

**Implementation:**
```yaml
# ✅ GOOD: Explicit version pinning
releases:
  - name: victoria-metrics-operator-crds
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds
    version: 0.56.0  # Explicit version

# ❌ BAD: Automatic version resolution
releases:
  - name: victoria-metrics-operator-crds
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds
    # No version specified - uses latest
```

**CRD Upgrade Process:**
1. Review CRD changelog for breaking changes
2. Test upgrade in development environment
3. Validate existing custom resources against new schema
4. Backup existing custom resources
5. Upgrade CRDs
6. Verify custom resources still work
7. Upgrade operators/controllers to match CRD version

---

### 6. **Multi-Cluster Consistency**

**Principle:**
Maintain consistent CRD versions across all clusters in a fleet.

**Why:**
- GitOps manifests should work across all clusters
- Custom resource portability requires consistent CRDs
- Troubleshooting is easier with consistent infrastructure
- Multi-cluster workloads require API compatibility

**Implementation:**
```yaml
# Shared CRD helmfile used by all clusters
environments:
  infra:
    values:
      - ../clusters/infra/values.yaml
  apps:
    values:
      - ../clusters/apps/values.yaml
  staging:
    values:
      - ../clusters/staging/values.yaml
  production:
    values:
      - ../clusters/production/values.yaml

releases:
  - name: victoria-metrics-operator-crds
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds
    version: 0.56.0  # Same version across all clusters
```

**Validation:**
```bash
# Verify CRD versions match across clusters
for cluster in infra apps staging production; do
  echo "Cluster: $cluster"
  kubectl --context $cluster get crd prometheusrules.monitoring.coreos.com \
    -o jsonpath='{.metadata.resourceVersion}'
  echo
done
```

---

## Implementation Patterns

### Pattern 1: CRD Extraction with Helmfile

**Use Case:** Extract CRDs from Helm charts that bundle CRDs with applications

**Implementation:**
```yaml
helmDefaults:
  args: ['--include-crds', '--no-hooks']
  postRenderer: bash
  postRendererArgs: [-c, "yq ea --exit-status 'select(.kind == \"CustomResourceDefinition\")'"]

releases:
  - name: victoria-metrics-operator-crds
    namespace: observability
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-k8s-stack
    version: 0.38.3
```

**Usage:**
```bash
helmfile template | kubectl apply -f -
```

**Benefits:**
- ✅ Reuses existing charts
- ✅ No separate CRD charts needed
- ✅ Guaranteed compatibility between CRDs and application

**Drawbacks:**
- ⚠️ Requires yq tool
- ⚠️ More complex helmfile configuration

---

### Pattern 2: Dedicated CRD Charts

**Use Case:** Official CRD charts provided by project maintainers

**Implementation:**
```yaml
releases:
  - name: victoria-metrics-operator-crds
    namespace: observability
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds
    version: 0.56.0
```

**Usage:**
```bash
helmfile sync
```

**Benefits:**
- ✅ Simpler configuration
- ✅ Official support from maintainers
- ✅ Explicit CRD versioning
- ✅ No additional tools required

**Drawbacks:**
- ⚠️ Not all projects provide CRD-only charts
- ⚠️ Need to manage CRD chart version separately

**When to Use:**
- ✅ CRD-only chart exists (e.g., cert-manager, VictoriaMetrics)
- ✅ Want simplest implementation
- ✅ Need official support/updates

---

### Pattern 3: Flux HelmRelease with CRD Policy

**Use Case:** Flux-managed CRD installation with explicit policy

**Implementation:**
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-metrics-operator-crds
  namespace: flux-system
spec:
  install:
    crds: Create      # Create CRDs on install
  upgrade:
    crds: CreateReplace  # Update CRDs on upgrade
  chart:
    spec:
      chart: victoria-metrics-operator-crds
      sourceRef:
        kind: HelmRepository
        name: victoriametrics
      version: 0.56.0
```

**Benefits:**
- ✅ Fully GitOps-managed
- ✅ Flux handles lifecycle
- ✅ Declarative configuration

**Drawbacks:**
- ⚠️ CRDs installed AFTER Flux bootstraps
- ⚠️ Not suitable for infrastructure CRDs needed during bootstrap

**When to Use:**
- ✅ CRDs only needed by workloads (not infrastructure)
- ✅ Fully committed to GitOps workflow
- ✅ Can tolerate delayed CRD availability

---

### Pattern 4: Kustomize CRD Components

**Use Case:** CRDs as reusable Kustomize components

**Implementation:**
```yaml
# kubernetes/components/crds/victoria-metrics/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.56.0/config/crd/bases/operator.victoriametrics.com_vmagents.yaml
  - https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.56.0/config/crd/bases/operator.victoriametrics.com_vmalerts.yaml
  # ... (other CRDs)
```

**Usage:**
```yaml
# kubernetes/infrastructure/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../components/crds/victoria-metrics
```

**Benefits:**
- ✅ Reusable across clusters
- ✅ Direct from source repository
- ✅ No Helm required

**Drawbacks:**
- ⚠️ Manual URL updates for version changes
- ⚠️ Network dependency during build
- ⚠️ No validation of CRD completeness

---

## Production Checklist

### Pre-Deployment

- [ ] **CRD Inventory:** Document all required CRDs and their sources
- [ ] **Version Compatibility:** Verify CRD versions match operator versions
- [ ] **Schema Validation:** Test CRDs with example custom resources
- [ ] **Backup Plan:** Document rollback procedure
- [ ] **Dependencies:** Map CRD dependencies for all infrastructure components
- [ ] **Testing:** Validate bootstrap process in development environment
- [ ] **Documentation:** Update runbooks with new bootstrap procedure

### During Deployment

- [ ] **Prerequisites:** Apply namespace and secret prerequisites first
- [ ] **CRD Installation:** Install CRDs before applications
- [ ] **CRD Verification:** Wait for CRDs to reach `Established` condition
- [ ] **Monitoring:** Watch for CRD-related errors in Flux/Helm
- [ ] **Validation:** Verify PrometheusRules and other CRs apply successfully

### Post-Deployment

- [ ] **Health Checks:** Verify all CRDs are present and healthy
- [ ] **Custom Resources:** Confirm CRs are created and functioning
- [ ] **Monitoring:** Check metrics/alerts for CRD-related issues
- [ ] **Documentation:** Update cluster documentation with CRD versions
- [ ] **Backup:** Backup CRD definitions and custom resources
- [ ] **Automation:** Update CI/CD pipelines with new bootstrap process

---

## Common Pitfalls & Solutions

### Pitfall 1: Helm CRD Upgrade Limitations

**Problem:**
Helm does not upgrade CRDs in the `crds/` directory during `helm upgrade`.

**Symptom:**
```
Error: CRD schema validation failed - field X not found in v1 schema
```

**Solution:**
- Use dedicated CRD charts with `crds: CreateReplace` policy
- Or manually upgrade CRDs: `kubectl replace -f crds/`
- Or use CRD extraction pattern with `helmfile template | kubectl apply`

**Prevention:**
- Separate CRD lifecycle from application lifecycle
- Monitor CRD versions vs application versions
- Include CRD upgrade in deployment checklist

---

### Pitfall 2: CRD Deletion Destroys Data

**Problem:**
Deleting a CRD deletes ALL custom resources of that kind cluster-wide.

**Symptom:**
```bash
kubectl delete crd prometheusrules.monitoring.coreos.com
# ⚠️ DANGER: Deletes ALL PrometheusRule resources in ALL namespaces!
```

**Solution:**
- **NEVER** delete CRDs unless intentionally destroying all CRs
- Use `kubectl replace -f` to update CRDs instead of delete/create
- Backup all custom resources before CRD operations

**Prevention:**
- Add safeguards to scripts preventing accidental CRD deletion
- Use RBAC to restrict CRD deletion permissions
- Document CRD deletion impact in runbooks

---

### Pitfall 3: Circular Dependencies

**Problem:**
Infrastructure components depend on monitoring CRDs, but monitoring depends on infrastructure.

**Example:**
```
Cilium deployment → needs PrometheusRule CRD
Victoria Metrics → provides PrometheusRule CRD → needs Cilium networking
```

**Solution:**
- Install monitoring CRDs during bootstrap (Phase 1)
- Deploy infrastructure with monitoring resources (Phase 2)
- Deploy monitoring operator/stack (Phase 3)
- Monitoring operator adopts existing resources

**Implementation:**
```yaml
# Phase 1: CRDs
helmfile -f 00-crds.yaml template | kubectl apply -f -

# Phase 2: Infrastructure (can reference PrometheusRule)
helmfile -f 01-core.yaml sync

# Phase 3: Monitoring (Flux deploys victoria-metrics)
# Operator recognizes existing PrometheusRules
```

---

### Pitfall 4: Multi-Cluster Version Drift

**Problem:**
Different CRD versions across clusters cause manifest incompatibility.

**Symptom:**
```
PrometheusRule works in cluster A but fails in cluster B
```

**Solution:**
- Use centralized CRD helmfile for all clusters
- Pin CRD versions explicitly
- Implement validation checks across clusters
- Use Renovate/Dependabot for synchronized updates

**Validation Script:**
```bash
#!/usr/bin/env bash
# Check CRD version consistency across clusters

CLUSTERS=("infra" "apps" "staging" "production")
CRDS=("prometheusrules.monitoring.coreos.com" "servicemonitors.monitoring.coreos.com")

for crd in "${CRDS[@]}"; do
  echo "Checking: $crd"
  for cluster in "${CLUSTERS[@]}"; do
    version=$(kubectl --context "$cluster" get crd "$crd" \
      -o jsonpath='{.spec.versions[?(@.storage==true)].name}' 2>/dev/null)
    echo "  $cluster: $version"
  done
  echo
done
```

---

## Monitoring & Observability

### CRD Health Metrics

**Key Metrics to Track:**

1. **CRD Established Condition:**
```prometheus
# Alert if CRD is not established
kube_customresourcedefinition_established{crd="prometheusrules.monitoring.coreos.com"} != 1
```

2. **Custom Resource Count:**
```prometheus
# Track number of custom resources
kube_customresource_count{customresourcedefinition="prometheusrules.monitoring.coreos.com"}
```

3. **CRD Schema Validation Failures:**
```bash
# Check for validation errors in API server logs
kubectl logs -n kube-system kube-apiserver-* | grep "CRD validation failed"
```

### Alerts

**PrometheusRule Example:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: crd-health
spec:
  groups:
    - name: crd.rules
      interval: 30s
      rules:
        - alert: CRDNotEstablished
          expr: |
            kube_customresourcedefinition_established != 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: CRD {{ $labels.crd }} is not established
            description: |
              CustomResourceDefinition {{ $labels.crd }} has not reached
              Established condition for 5 minutes.

        - alert: CRDMissing
          expr: |
            absent(kube_customresourcedefinition_info{crd="prometheusrules.monitoring.coreos.com"})
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: Required CRD is missing
            description: |
              PrometheusRule CRD is missing from the cluster.
              Infrastructure monitoring will fail.
```

---

## Upgrade Strategy

### CRD Version Upgrade Process

**1. Pre-Upgrade Planning**
- [ ] Review CRD changelog for breaking changes
- [ ] Identify affected custom resources
- [ ] Plan downtime window if needed
- [ ] Prepare rollback procedure
- [ ] Notify stakeholders

**2. Testing Phase**
```bash
# Test in development cluster
kubectl config use-context dev

# Backup existing CRDs
kubectl get crd -o yaml > crds-backup.yaml

# Backup custom resources
kubectl get prometheusrules -A -o yaml > prometheusrules-backup.yaml

# Apply new CRD version
helmfile -f 00-crds.yaml -e dev template | kubectl apply -f -

# Validate custom resources still work
kubectl get prometheusrules -A
```

**3. Production Deployment**
```bash
# Backup production
kubectl config use-context production
kubectl get crd -o yaml > crds-production-backup.yaml
kubectl get prometheusrules -A -o yaml > prometheusrules-production-backup.yaml

# Apply new CRDs
helmfile -f 00-crds.yaml -e production template | kubectl apply -f -

# Verify
kubectl get crd prometheusrules.monitoring.coreos.com -o yaml | grep -A5 versions
kubectl get prometheusrules -A  # Should show all existing rules
```

**4. Validation**
- [ ] Verify CRD status: `kubectl get crd`
- [ ] Check custom resource health
- [ ] Monitor API server logs for validation errors
- [ ] Test creating new custom resources
- [ ] Verify operator functionality

**5. Rollback (if needed)**
```bash
# Restore previous CRD version
kubectl apply -f crds-production-backup.yaml

# Verify rollback successful
kubectl get crd prometheusrules.monitoring.coreos.com -o yaml | grep -A5 versions
```

---

## Automation & CI/CD Integration

### GitHub Actions Example

```yaml
name: Validate CRD Bootstrap

on:
  pull_request:
    paths:
      - 'bootstrap/helmfile.d/00-crds.yaml'
      - 'bootstrap/helmfile.d/01-core.yaml'

jobs:
  validate-crds:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Tools
        run: |
          # Install helmfile
          wget https://github.com/helmfile/helmfile/releases/download/v0.165.0/helmfile_0.165.0_linux_amd64.tar.gz
          tar xf helmfile_0.165.0_linux_amd64.tar.gz
          sudo mv helmfile /usr/local/bin/

          # Install yq
          wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          sudo mv yq_linux_amd64 /usr/local/bin/yq
          chmod +x /usr/local/bin/yq

          # Install kubectl
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

      - name: Extract CRDs
        run: |
          cd bootstrap
          helmfile -f helmfile.d/00-crds.yaml -e infra template > /tmp/crds.yaml

      - name: Validate CRD Manifests
        run: |
          # Verify only CRDs were extracted
          if grep -v "kind: CustomResourceDefinition" /tmp/crds.yaml | grep -q "^kind:"; then
            echo "ERROR: Non-CRD manifests found in CRD helmfile output"
            exit 1
          fi

          # Validate YAML syntax
          kubectl --dry-run=client apply -f /tmp/crds.yaml

      - name: Check Required CRDs
        run: |
          # Verify required CRDs are present
          required_crds=(
            "prometheusrules.monitoring.coreos.com"
            "servicemonitors.monitoring.coreos.com"
            "vmagents.operator.victoriametrics.com"
            "vmalerts.operator.victoriametrics.com"
          )

          for crd in "${required_crds[@]}"; do
            if ! grep -q "name: $crd" /tmp/crds.yaml; then
              echo "ERROR: Required CRD $crd not found"
              exit 1
            fi
          done

          echo "✅ All required CRDs present"
```

---

## Documentation Best Practices

### What to Document

**1. CRD Inventory:**
```markdown
| CRD | Source Chart | Version | Used By | Critical |
|-----|-------------|---------|---------|----------|
| prometheusrules.monitoring.coreos.com | victoria-metrics-operator-crds | v0.56.0 | Infrastructure, Workloads | ✅ Yes |
| servicemonitors.monitoring.coreos.com | victoria-metrics-operator-crds | v0.56.0 | Infrastructure, Workloads | ✅ Yes |
| vmagents.operator.victoriametrics.com | victoria-metrics-operator-crds | v0.56.0 | Workloads | ⚠️ No |
```

**2. Bootstrap Runbook:**
```markdown
## Emergency Cluster Re-Bootstrap

1. **Prerequisites:** (5 minutes)
   ```bash
   kubectl apply -f bootstrap/prerequisites/resources.yaml
   ```

2. **CRDs:** (2 minutes)
   ```bash
   helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -
   kubectl wait --for condition=established crd/prometheusrules.monitoring.coreos.com --timeout=60s
   ```

3. **Core Infrastructure:** (10 minutes)
   ```bash
   helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync
   ```

4. **Validation:**
   ```bash
   kubectl get crd | grep victoriametrics
   flux get kustomizations --watch
   ```
```

**3. Troubleshooting Guide:**
```markdown
## CRD Bootstrap Troubleshooting

### Issue: yq not found
**Error:** `bash: yq: command not found`
**Solution:** Install yq: `brew install yq` (macOS) or download from GitHub releases

### Issue: CRD already exists
**Error:** `customresourcedefinitions.apiextensions.k8s.io "X" already exists`
**Solution:** Expected behavior - kubectl apply is idempotent

### Issue: PrometheusRule fails validation
**Error:** `no matches for kind "PrometheusRule"`
**Check:** `kubectl get crd prometheusrules.monitoring.coreos.com`
**Solution:** Re-run CRD bootstrap phase
```

---

## Summary & Key Takeaways

### Do's ✅

1. **Install CRDs before applications** - Separate bootstrap phases
2. **Use dedicated CRD charts** - When available from maintainers
3. **Pin CRD versions explicitly** - Upgrade consciously with validation
4. **Make bootstrap idempotent** - Support disaster recovery scenarios
5. **Declare dependencies explicitly** - Don't rely on timing
6. **Maintain multi-cluster consistency** - Same CRDs across fleet
7. **Monitor CRD health** - Alert on CRD issues
8. **Document CRD inventory** - Track versions and dependencies
9. **Test in development first** - Validate before production
10. **Backup before CRD operations** - CRD deletion destroys data

### Don'ts ❌

1. **Don't delete CRDs casually** - Destroys all custom resources
2. **Don't rely on Helm to upgrade CRDs** - Helm skips crds/ directory
3. **Don't use latest/floating versions** - Pin for stability
4. **Don't ignore CRD compatibility** - Test with existing CRs
5. **Don't skip CRD validation** - Schema issues cause outages
6. **Don't create circular dependencies** - Bootstrap CRDs first
7. **Don't assume CRDs are backwards compatible** - Review changelogs
8. **Don't deploy infrastructure before CRDs** - Causes race conditions
9. **Don't mix CRD management patterns** - Choose one approach
10. **Don't skip documentation** - Future you will thank you

---

## References & Further Reading

### Official Documentation

- [Kubernetes CRD Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Helm CRD Best Practices](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/)
- [VictoriaMetrics Operator](https://docs.victoriametrics.com/operator/)
- [Flux CRD Management](https://fluxcd.io/flux/components/helm/helmreleases/#crds)

### Community Resources

- [Buroa k8s-gitops Repository](https://github.com/buroa/k8s-gitops) - Production CRD bootstrap pattern
- [onedr0p/home-ops](https://github.com/onedr0p/home-ops) - Community GitOps examples
- [k8s-at-home](https://github.com/k8s-at-home) - Kubernetes homelab patterns

### Related Tools

- [Helmfile](https://helmfile.readthedocs.io/) - Declarative Helm chart management
- [yq](https://github.com/mikefarah/yq) - YAML processing
- [Flux](https://fluxcd.io/) - GitOps continuous delivery
- [kube-prometheus-stack](https://github.com/prometheus-operator/kube-prometheus) - Monitoring CRDs

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Maintained By:** Platform Engineering Team
**Review Schedule:** Quarterly
