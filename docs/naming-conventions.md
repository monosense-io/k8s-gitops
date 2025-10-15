# Naming Conventions

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** ✅ Approved
**Validation:** Infrastructure Validation - IaC Section 2

---

## Purpose

This document defines naming conventions for all infrastructure resources in the multi-cluster Kubernetes platform. Consistent naming improves:
- **Discoverability** - Find resources quickly
- **Maintainability** - Understand resource purpose at a glance
- **Automation** - Predictable patterns for scripting
- **Troubleshooting** - Identify resource relationships

---

## Kubernetes Resources

### Namespaces

**Pattern:** `<category>[-<purpose>]`

**Categories:**
- `kube-system` - Kubernetes core services
- `flux-system` - GitOps controllers
- `rook-ceph` - Storage infrastructure
- `observability` - Monitoring, logging, alerting
- `external-secrets` - Secret management
- `cert-manager` - Certificate automation

**Examples:**
```yaml
kube-system          # Core Kubernetes
rook-ceph            # Ceph storage
observability        # Victoria Metrics stack
platform-databases   # Shared databases
```

---

### Flux Kustomizations

**Pattern:** `cluster-<cluster>-<stack>`

**Components:**
- `<cluster>`: `infra` | `apps`
- `<stack>`: `infrastructure` | `workloads`

**Examples:**
```yaml
cluster-infra-infrastructure  # Infra cluster base infrastructure
cluster-infra-workloads       # Infra cluster platform workloads
cluster-apps-infrastructure   # Apps cluster base infrastructure
cluster-apps-workloads        # Apps cluster tenant workloads
```

---

### Helm Releases

**Pattern:** `<component>` (kept simple, namespace provides context)

**Examples:**
```yaml
# kubernetes/bases/cilium/helmrelease.yaml
name: cilium
namespace: kube-system

# kubernetes/bases/rook-ceph-operator/helmrelease.yaml
name: rook-ceph-operator
namespace: rook-ceph

# kubernetes/workloads/platform/observability/victoria-metrics/kustomization.yaml
name: victoria-metrics-stack
namespace: observability
```

---

### ConfigMaps & Secrets

**Pattern:** `<component>-<purpose>`

**Examples:**
```yaml
grafana-config           # Grafana configuration
cilium-bgp-config        # Cilium BGP settings
postgres-init-scripts    # Database init scripts
onepassword-connect-token # External Secrets auth
```

---

## Environment Variables (postBuild.substitute)

### Variable Naming Pattern

**Pattern:** `<COMPONENT>_<ATTRIBUTE>`

**Component Prefixes:**
- `CLUSTER_*` - Cluster-wide settings
- `CILIUM_*` - Cilium CNI configuration
- `ROOK_CEPH_*` - Rook Ceph storage
- `CNPG_*` - CloudNativePG databases
- `DRAGONFLY_*` - Dragonfly cache
- `OBSERVABILITY_*` - Monitoring stack
- `EXTERNAL_SECRET_*` - Secret management

**Examples:**
```yaml
# Cluster identification
CLUSTER: "infra"
CLUSTER_ID: "1"
SECRET_DOMAIN: "monosense.io"

# Networking
POD_CIDR: '["10.244.0.0/16"]'
SERVICE_CIDR: '["10.245.0.0/16"]'
CILIUM_BGP_LOCAL_ASN: "64512"

# Storage
ROOK_CEPH_NAMESPACE: "rook-ceph"
ROOK_CEPH_DEVICE_FILTER: "^nvme[0-9]+n1$"
ROOK_CEPH_MON_COUNT: "3"

# Database
CNPG_STORAGE_CLASS: "openebs-local-nvme"
CNPG_DATA_SIZE: "200Gi"

# Observability
OBSERVABILITY_METRICS_RETENTION: "30d"
OBSERVABILITY_LOGS_RETENTION: "14d"
```

---

## 1Password Secret Paths

### Secret Path Pattern

**Pattern:** `kubernetes/<cluster>/<component>/<secret-type>`

**Structure:**
- `kubernetes/` - Root for all K8s secrets
- `<cluster>` - `infra` | `apps` | `shared`
- `<component>` - Service or application name
- `<secret-type>` - Purpose of secret

**Examples:**
```
kubernetes/infra/grafana-admin
kubernetes/infra/cloudnative-pg/minio
kubernetes/infra/cloudnative-pg/superuser
kubernetes/infra/dragonfly/auth
kubernetes/infra/cilium-clustermesh
kubernetes/infra/cert-manager/cloudflare
kubernetes/apps/gitlab/runner-token
kubernetes/apps/harbor/admin
kubernetes/shared/1password-connect-token
```

---

## Talos Machine Configs

### File Naming

**Pattern:** `<ip-address>.yaml` or `machineconfig.yaml.j2` (template)

**Examples:**
```
talos/machineconfig.yaml.j2              # Jinja2 template
talos/controlplane/10.25.11.11.yaml      # Generated config (infra-01)
talos/controlplane/10.25.11.14.yaml      # Generated config (apps-01)
```

### Node Names

**Pattern:** `<cluster>-<type>-<number>`

**Examples:**
```
infra-01, infra-02, infra-03  # Infra cluster nodes
apps-01, apps-02, apps-03     # Apps cluster nodes
```

---

## Storage Resources

### StorageClasses

**Pattern:** `<provider>-<type>[-<tier>]`

**Examples:**
```yaml
rook-ceph-block       # Rook Ceph RBD (replicated block)
rook-ceph-filesystem  # Rook CephFS (shared filesystem)
openebs-local-nvme    # OpenEBS hostPath on NVMe
local-path            # Local path provisioner
```

### PersistentVolumeClaims

**Pattern:** `<component>-<purpose>-<index>` (for StatefulSets)

**Examples:**
```yaml
data-postgres-cluster-1      # CloudNativePG data volume
data-dragonfly-0             # Dragonfly data volume
victoria-metrics-storage-0   # VM storage replica 0
```

---

## Labels

### Standard Kubernetes Labels

Always include:
```yaml
metadata:
  labels:
    app.kubernetes.io/name: <component>
    app.kubernetes.io/instance: <release>
    app.kubernetes.io/version: <version>
    app.kubernetes.io/component: <role>
    app.kubernetes.io/part-of: <application>
    app.kubernetes.io/managed-by: flux
```

### Custom Labels

**Pattern:** `<domain>/<key>`

**Examples:**
```yaml
# Cluster identification
kubernetes.io/cluster: infra
topology.kubernetes.io/zone: us-central1-a

# Flux GitOps
kustomize.toolkit.fluxcd.io/name: cluster-infra-infrastructure
kustomize.toolkit.fluxcd.io/namespace: flux-system

# Cilium service mesh
io.cilium/global-service: "true"
service.cilium.io/global: "true"
```

---

## Annotations

### Common Annotations

```yaml
metadata:
  annotations:
    # External Secrets path
    external-secrets.io/secret-path: "kubernetes/infra/component"

    # Flux reconciliation
    kustomize.toolkit.fluxcd.io/reconcile: "true"

    # Certificate management
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

    # Cilium networking
    io.cilium/lb-ipam-ips: "10.25.11.100"

    # External DNS
    external-dns.alpha.kubernetes.io/hostname: "grafana.monosense.io"
```

---

## Network Resources

### LoadBalancer Services

**IP Pool Allocation:**
```
Infra Cluster: 10.25.11.100-149
Apps Cluster:  10.25.11.150-199
```

**Assignment Pattern:**
```yaml
# Infra cluster
10.25.11.100  # Cilium ClusterMesh API
10.25.11.101  # Reserved
10.25.11.120  # Cilium Gateway (Envoy)
10.25.11.121+ # Additional services

# Apps cluster
10.25.11.150  # Cilium ClusterMesh API
10.25.11.151  # Reserved
10.25.11.170  # Cilium Gateway (Envoy)
10.25.11.171+ # Additional services
```

---

## BGP Configuration

### AS Numbers

```
Juniper SRX320:  65000
Infra Cluster:   64512
Apps Cluster:    64513
```

---

## Git Repository Structure

### Directory Naming

```
kubernetes/
├── bases/                  # Reusable HelmRelease and CRD definitions
├── components/             # Kustomize components (mixins)
├── infrastructure/         # Platform infrastructure stacks
└── workloads/              # Application workloads
    ├── platform/           # Platform-provided services
    └── tenants/            # Tenant applications

talos/
├── machineconfig.yaml.j2   # Jinja2 template
└── <cluster>/              # Generated configs per cluster
```

---

## Enforcement

### Pre-commit Hooks (Recommended)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace

  - repo: https://github.com/adrienverge/yamllint
    hooks:
      - id: yamllint
        args: [--strict, --config-data, '{extends: default, rules: {line-length: {max: 160}}}']
```

### CI/CD Validation

GitHub Actions workflow validates:
- YAML syntax and linting
- Flux Kustomization builds
- Schema conformance with kubeconform
- Secret scanning with Gitleaks

---

## Examples by Use Case

### Adding a New Helm Release

```yaml
# kubernetes/bases/new-component/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml

# kubernetes/bases/new-component/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: new-component
  namespace: ${COMPONENT_NAMESPACE:=default}
spec:
  interval: 30m
  chart:
    spec:
      chart: new-component
      version: 1.2.3
      sourceRef:
        kind: HelmRepository
        name: repo-name
        namespace: flux-system
  values:
    storageClass: ${STORAGE_CLASS}
```

### Adding a New Secret

```bash
# 1. Create secret in 1Password
op item create \
  --category=password \
  --title="kubernetes/infra/new-component/auth" \
  --vault="Kubernetes" \
  username="admin" \
  password="$(openssl rand -base64 32)"

# 2. Create ExternalSecret manifest
cat <<EOF > kubernetes/workloads/platform/new-component/externalsecret.yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: new-component-auth
  namespace: ${COMPONENT_NAMESPACE}
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: new-component-auth
  dataFrom:
    - extract:
        key: kubernetes/infra/new-component/auth
EOF
```

---

## Troubleshooting

### Finding Resources by Pattern

```bash
# Find all infra cluster Kustomizations
kubectl get kustomization -n flux-system | grep infra

# Find all Rook Ceph resources
kubectl get all -n rook-ceph

# Find all resources with specific label
kubectl get all -A -l app.kubernetes.io/part-of=monitoring

# Find secrets from 1Password
kubectl get externalsecrets -A
```

---

## References

- [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Flux Kustomization API](https://fluxcd.io/flux/components/kustomize/kustomization/)
- [1Password Connect Server](https://developer.1password.com/docs/connect/)

---

**Status**: ✅ Active Convention
**Review Date**: Quarterly
**Owner**: Platform Team
