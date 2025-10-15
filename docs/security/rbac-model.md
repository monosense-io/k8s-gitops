# RBAC Security Model

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** ✅ Approved for Implementation
**Validation:** Infrastructure Validation - Security Blocker #1

---

## Executive Summary

This document defines the Role-Based Access Control (RBAC) model for the multi-cluster Kubernetes platform. It establishes the principle of least privilege across all service accounts, operators, and human users to minimize security risk and maintain operational integrity.

---

## 🎯 RBAC Principles

### Core Principles

1. **Least Privilege**: Every account receives only the minimum permissions required for its function
2. **Separation of Duties**: Critical operations require multiple roles
3. **Namespace Isolation**: Applications cannot access resources outside their namespace (except via global services)
4. **Audit Trail**: All access is logged via Talos audit policies + Victoria Metrics
5. **Time-Bound Access**: Break-glass admin access expires after use
6. **Defense in Depth**: RBAC + Network Policies + Pod Security Standards = layered security

### Access Control Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Talos API Access (Node-level)                          │
│   - Platform team only                                           │
│   - Required for node operations, not for workloads             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: Kubernetes RBAC (Cluster-level)                        │
│   - ClusterRoles: Platform operators, monitoring                │
│   - Roles: Namespace-scoped application access                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Network Policies (Traffic-level)                       │
│   - Cilium NetworkPolicy enforcement                             │
│   - Default deny + explicit allow                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: Pod Security Standards (Workload-level)                │
│   - Restricted profile for applications                         │
│   - Baseline for platform components                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 👥 User Personas & Roles

### Persona 1: Platform Administrator

**Who**: Platform engineering team responsible for cluster operations
**Access Level**: Cluster-wide read, namespace-scoped write to `infrastructure/*` namespaces
**ClusterRole**: `platform-admin`

**Capabilities**:
- ✅ Deploy and manage platform services (Flux, cert-manager, external-secrets)
- ✅ Read all resources cluster-wide (troubleshooting)
- ✅ Manage storage classes, network policies, RBAC
- ✅ Access logs and metrics
- ❌ Delete production namespaces without approval
- ❌ Modify workload deployments (belongs to App Developers)

---

### Persona 2: Application Developer

**Who**: Development team deploying applications
**Access Level**: Namespace-scoped read/write to assigned namespaces
**Role**: `developer` (per namespace)

**Capabilities**:
- ✅ Deploy/update applications in assigned namespaces
- ✅ Read logs and metrics for their applications
- ✅ Create ConfigMaps, Secrets (via External Secrets), Services
- ✅ Scale deployments within resource quotas
- ❌ Modify namespace resource quotas
- ❌ Access other namespaces
- ❌ Create ClusterRoles or ClusterRoleBindings

---

### Persona 3: Break-Glass Administrator

**Who**: Emergency access for critical incidents
**Access Level**: Full cluster-admin
**ClusterRole**: `cluster-admin` (built-in)

**Usage**:
- 🚨 **EMERGENCY ONLY** - Requires incident ticket
- ⏱️ Time-bound access (revoke after incident resolution)
- 📝 Audit logged and reviewed
- 🔐 Granted via `kubectl create rolebinding` with TTL annotation

---

### Persona 4: CI/CD Service Account

**Who**: GitHub Actions runners, GitLab CI
**Access Level**: Namespace-scoped write to specific namespaces
**ServiceAccount**: `cicd-deployer` (per namespace)

**Capabilities**:
- ✅ Deploy application manifests via GitOps
- ✅ Read deployment status
- ❌ Delete resources not owned by CI/CD
- ❌ Modify RBAC or NetworkPolicies

---

### Persona 5: Monitoring & Observability

**Who**: Victoria Metrics, Prometheus, Grafana
**Access Level**: Cluster-wide read-only
**ClusterRole**: `monitoring-reader`

**Capabilities**:
- ✅ Read all metrics, logs, events cluster-wide
- ✅ Access pod/node metrics via kubelet
- ❌ Modify any resources

---

### Persona 6: Read-Only Auditor

**Who**: Security audits, compliance reviews
**Access Level**: Cluster-wide read-only (excluding secrets)
**ClusterRole**: `view-no-secrets`

**Capabilities**:
- ✅ Read all resource definitions
- ✅ View configurations and policies
- ❌ Read Secret contents
- ❌ Modify anything

---

## 🤖 Service Account RBAC Matrix

### Infra Cluster Service Accounts

| Service Account | Namespace | ClusterRole | Permissions | Justification |
|-----------------|-----------|-------------|-------------|---------------|
| `flux-system/flux` | `flux-system` | `cluster-admin` | Full cluster access | GitOps reconciliation requires managing all resources |
| `external-secrets/external-secrets-operator` | `external-secrets` | `external-secrets-operator` | Read: Secrets, ServiceAccounts<br>Write: Secrets | Syncing secrets from 1Password |
| `cert-manager/cert-manager` | `cert-manager` | `cert-manager-controller` | Read: Ingress, Services<br>Write: Secrets, Certificates | TLS certificate provisioning |
| `rook-ceph/rook-ceph-operator` | `rook-ceph` | `rook-ceph-operator` | Node access, PV management | Storage provisioning |
| `monitoring/vmagent` | `monitoring` | `monitoring-reader` | Read: Pods, Nodes, Services | Metrics scraping |
| `monitoring/vmalert` | `monitoring` | `vmalert-executor` | Read: All<br>Write: PrometheusRules | Alert evaluation |
| `kube-system/cilium` | `kube-system` | `cilium` | Node networking, NetworkPolicies | CNI operations |
| `databases/cloudnative-pg` | `databases` | `cloudnative-pg-operator` | StatefulSet, PVC management | PostgreSQL operator |

---

### Apps Cluster Service Accounts

| Service Account | Namespace | ClusterRole | Permissions | Justification |
|-----------------|-----------|-------------|-------------|---------------|
| `flux-system/flux` | `flux-system` | `cluster-admin` | Full cluster access | GitOps reconciliation |
| `monitoring/vmagent` | `monitoring` | `monitoring-reader` | Read: Pods, Nodes | Remote-write to infra cluster |
| `kube-system/cilium` | `kube-system` | `cilium` | Node networking | CNI operations |
| `gitlab/gitlab` | `gitlab` | `gitlab-runner` | Namespace-scoped pod exec | CI/CD pipeline execution |

---

## 📜 RBAC Policy Definitions

### ClusterRole: `platform-admin`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
  labels:
    app.kubernetes.io/managed-by: flux
    rbac.monosense.io/persona: platform-admin
rules:
  # Full access to platform namespaces
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
    # Applied via RoleBindings to specific namespaces only

  # Cluster-wide read for troubleshooting
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]

  # Cluster-scoped resource management
  - apiGroups: [""]
    resources: ["nodes", "persistentvolumes", "namespaces"]
    verbs: ["get", "list", "watch", "patch"]

  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses", "volumeattachments"]
    verbs: ["*"]

  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles", "clusterrolebindings"]
    verbs: ["get", "list", "watch", "create", "patch"]

  - apiGroups: ["cilium.io"]
    resources: ["*"]
    verbs: ["*"]

  # Deny: Cannot delete production namespaces
  # Enforced via admission controller (not RBAC)
```

---

### ClusterRole: `monitoring-reader`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
  labels:
    rbac.monosense.io/persona: monitoring
rules:
  # Read all resources for metrics
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]

  # Access kubelet metrics
  - nonResourceURLs:
      - "/metrics"
      - "/metrics/cadvisor"
      - "/metrics/probes"
    verbs: ["get"]

  # Deny: Cannot read Secret data
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: [] # No verbs = explicit deny
```

---

### Role: `developer` (per namespace)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: <APPLICATION_NAMESPACE>
  labels:
    rbac.monosense.io/persona: developer
rules:
  # Full control over application resources
  - apiGroups: ["", "apps", "batch"]
    resources:
      - pods
      - pods/log
      - pods/exec
      - deployments
      - replicasets
      - statefulsets
      - daemonsets
      - jobs
      - cronjobs
      - services
      - configmaps
      - persistentvolumeclaims
    verbs: ["*"]

  # External Secrets (create only, operator manages)
  - apiGroups: ["external-secrets.io"]
    resources: ["externalsecrets", "secretstores"]
    verbs: ["create", "get", "list", "watch"]

  # Read-only for monitoring
  - apiGroups: ["monitoring.coreos.com"]
    resources: ["servicemonitors", "podmonitors"]
    verbs: ["get", "list", "watch"]

  # Cannot modify RBAC
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["*"]
    verbs: []

  # Cannot modify NetworkPolicies
  - apiGroups: ["networking.k8s.io", "cilium.io"]
    resources: ["networkpolicies", "ciliumnetworkpolicies"]
    verbs: ["get", "list", "watch"]
```

---

### ServiceAccount: `cicd-deployer`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-deployer
  namespace: <APPLICATION_NAMESPACE>
  labels:
    rbac.monosense.io/persona: cicd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: <APPLICATION_NAMESPACE>
rules:
  # Deploy application manifests
  - apiGroups: ["", "apps"]
    resources:
      - deployments
      - services
      - configmaps
    verbs: ["create", "update", "patch", "get", "list"]

  # Read status for health checks
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]

  # Cannot delete resources (manual intervention required)
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: [] # No delete verb
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deployer
  namespace: <APPLICATION_NAMESPACE>
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cicd-deployer
subjects:
  - kind: ServiceAccount
    name: cicd-deployer
    namespace: <APPLICATION_NAMESPACE>
```

---

## 🔒 Operator RBAC Specifications

### FluxCD

**Status**: ✅ RBAC provided by `flux bootstrap`
**ClusterRole**: `cluster-admin` (required for GitOps)
**Justification**: Flux manages all cluster resources declaratively
**Mitigation**: Git repository is single source of truth, protected by branch protection + PR reviews

---

### External Secrets Operator

**Required Permissions**:
- Read: `ServiceAccount`, `Secret` (source secrets)
- Write: `Secret` (synced secrets)
- Watch: `ExternalSecret`, `SecretStore` CRDs

**ClusterRole**: Custom `external-secrets-operator` (defined in manifests)

---

### Rook Ceph Operator

**Required Permissions**:
- Node access (DaemonSet deployment)
- PV/PVC management
- StatefulSet, Deployment management
- Custom Ceph CRDs

**ClusterRole**: `rook-ceph-operator` (provided by Rook Helm chart)
**Security Note**: Requires privileged containers for OSD pods

---

### cert-manager

**Required Permissions**:
- Read: `Ingress`, `Service` (for ACME challenges)
- Write: `Secret` (TLS certificates)
- Manage: `Certificate`, `CertificateRequest` CRDs

**ClusterRole**: `cert-manager-controller` (provided by cert-manager Helm chart)

---

### Victoria Metrics Operator

**Required Permissions**:
- Read: All resources (metrics scraping)
- Write: `VMAgent`, `VMAlert`, `VMCluster` CRDs
- Access: Kubelet metrics endpoints

**ClusterRole**: `victoria-metrics-operator` (provided by VM Helm chart)

---

### CloudNativePG Operator

**Required Permissions**:
- Manage: `StatefulSet`, `PVC`, `Service`
- Write: `Secret` (PostgreSQL credentials)
- Manage: `Cluster`, `Backup`, `ScheduledBackup` CRDs

**ClusterRole**: `cloudnative-pg-operator` (provided by CNPG Helm chart)

---

## 📊 RBAC Audit & Compliance

### Audit Requirements

1. **Quarterly RBAC Review**: Validate all ClusterRoleBindings and RoleBindings
2. **Service Account Audit**: Ensure no overprivileged service accounts
3. **User Access Review**: Verify human user access is still required
4. **Break-Glass Audit**: Review all cluster-admin access grants

### Compliance Checks

```bash
# List all ClusterRoleBindings
kubectl get clusterrolebindings -o wide

# Find cluster-admin bindings (should be minimal)
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# Audit service accounts with cluster-admin
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[] | select(.kind=="ServiceAccount")'

# List all Roles and RoleBindings per namespace
kubectl get roles,rolebindings -A

# Check for overly permissive Roles (verb: "*")
kubectl get roles -A -o json | \
  jq '.items[] | select(.rules[].verbs[] | contains("*"))'
```

---

## 🛡️ Break-Glass Procedure

### When to Use Break-Glass Access

- 🚨 **Critical Incident**: Production outage requiring immediate cluster-wide access
- 🔥 **Security Incident**: Compromised namespace requiring emergency response
- ⚠️ **Data Loss Prevention**: Imminent data loss requiring rapid intervention

### Break-Glass Access Grant Procedure

```bash
# 1. Create incident ticket
# Ticket: INC-2025-001 - Production database outage

# 2. Grant temporary cluster-admin
kubectl create rolebinding break-glass-admin-<USERNAME> \
  --clusterrole=cluster-admin \
  --user=<USERNAME> \
  --namespace=<AFFECTED_NAMESPACE>

# 3. Add TTL annotation (24-hour expiry)
kubectl annotate rolebinding break-glass-admin-<USERNAME> \
  "monosense.io/expires-at=$(date -u -d '+24 hours' +%Y-%m-%dT%H:%M:%SZ)"

# 4. Document in incident log
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - Granted break-glass access to <USERNAME> for INC-2025-001" >> /var/log/break-glass-audit.log

# 5. Revoke after incident resolution
kubectl delete rolebinding break-glass-admin-<USERNAME>
```

---

## 🔐 RBAC Best Practices

### Do's ✅

1. **Use ServiceAccounts for automation** - Never use personal credentials for CI/CD
2. **Namespace-scope roles when possible** - Prefer `Role` over `ClusterRole`
3. **Explicit allow lists** - Define exactly which resources/verbs are needed
4. **Regular audits** - Quarterly review of all RBAC bindings
5. **Document justifications** - Every ClusterRole should have a "Why" comment

### Don'ts ❌

1. **Never grant cluster-admin to applications** - Except Flux (GitOps requirement)
2. **Avoid wildcard permissions** - `resources: ["*"]` should be rare
3. **Don't use default ServiceAccount** - Always create dedicated ServiceAccounts
4. **Never commit credentials** - Use External Secrets for all sensitive data
5. **Don't skip RBAC for "convenience"** - Security > convenience

---

## 🗂️ RBAC Manifest Organization

### Repository Structure

```
kubernetes/
├── bases/
│   └── rbac/
│       ├── platform-admin-clusterrole.yaml
│       ├── monitoring-reader-clusterrole.yaml
│       ├── developer-role-template.yaml
│       └── kustomization.yaml
├── infrastructure/
│   └── security/
│       └── rbac/
│           ├── infra-cluster-bindings.yaml
│           ├── apps-cluster-bindings.yaml
│           └── kustomization.yaml
└── workloads/
    └── <namespace>/
        ├── rbac/
        │   ├── serviceaccount.yaml
        │   ├── role.yaml
        │   └── rolebinding.yaml
        └── kustomization.yaml
```

---

## 📝 Implementation Checklist

- [ ] Create base RBAC ClusterRoles (`platform-admin`, `monitoring-reader`, etc.)
- [ ] Deploy ClusterRoleBindings for platform team
- [ ] Audit all operator Helm charts for RBAC configurations
- [ ] Create per-namespace developer Roles
- [ ] Configure CI/CD ServiceAccounts with limited permissions
- [ ] Document break-glass procedure
- [ ] Schedule quarterly RBAC audit
- [ ] Enable Talos audit logging (see BLOCKER #2)
- [ ] Integrate RBAC violations into AlertManager

---

## 🔗 Related Documentation

- [Data Classification Framework](./data-classification.md) - BLOCKER #3
- [Talos Audit Logging](./talos-audit-policy.md) - BLOCKER #2
- [Architecture Decision Record](../architecture-decision-record.md) - ADR-007 (Pod Security)
- [Network Policies](../../kubernetes/infrastructure/security/network-policies/) - ADR-005

---

**Status**: 📋 Ready for Implementation
**Next Action**: Create RBAC manifests in `kubernetes/bases/rbac/`
**Owner**: Platform Team
**Review Date**: Before Phase 1 Deployment
