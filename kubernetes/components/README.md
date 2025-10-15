# Kubernetes Components Library

Reusable Kustomize components for DRY (Don't Repeat Yourself) infrastructure patterns.

## 📚 Available Components

### Core Components

| Component | Purpose | Usage |
|-----------|---------|-------|
| `namespace` | Standard namespace with restricted PSS | Most application namespaces |
| `namespace-privileged` | Privileged namespace for system components | kube-system, flux-system |

### Database Services

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| `cnpg-database` | PostgreSQL database provisioning on shared cluster | Application-specific database creation |

### High Availability

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| `pdb-maxunavailable-1` | PodDisruptionBudget (max 1 unavailable) | Auto-configured via replacements |

### Monitoring

| Component | Purpose | Metrics Source |
|-----------|---------|----------------|
| `monitoring/servicemonitor` | Prometheus ServiceMonitor | Service with metrics port |
| `monitoring/podmonitor` | Prometheus PodMonitor | Direct pod metrics |
| `monitoring/prometheusrule-basic` | Common alert rules | Pod, memory, CPU alerts |

### Security

| Component | Purpose | Policy |
|-----------|---------|--------|
| `externalsecret` | 1Password secret sync | ClusterSecretStore integration |
| `networkpolicy/deny-all` | Default deny all traffic | Baseline security |
| `networkpolicy/allow-dns` | Allow DNS queries | CoreDNS access |
| `networkpolicy/allow-internal` | Allow namespace-internal traffic | Same-namespace communication |

---

## 🚀 Quick Start

### Example: Deploy an Application with Components

```yaml
# kubernetes/infrastructure/myapp/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Set namespace (also creates it via component)
namespace: myapp

# Include reusable components
components:
  - ../../components/namespace
  - ../../components/pdb-maxunavailable-1
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns

resources:
  - deployment.yaml
  - service.yaml
```

### What This Does

✅ **Creates namespace** with standard labels and restricted PSS
✅ **Creates PodDisruptionBudget** automatically matching Deployment
✅ **Creates ServiceMonitor** automatically matching Service
✅ **Creates PrometheusRule** with common alerts for the namespace
✅ **Creates NetworkPolicies** for zero-trust security

**Result:** ~80% less YAML compared to defining everything manually!

---

## 📖 Component Usage Guide

### 1. Namespace Component

Creates a namespace with standard labels and Pod Security Standards.

#### Standard Namespace (Restricted PSS)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: my-app
components:
  - ../../components/namespace
```

**Creates:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    app.kubernetes.io/managed-by: flux
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

#### Privileged Namespace (System Components)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kube-system
components:
  - ../../components/namespace-privileged
```

---

### 2. PodDisruptionBudget Component

Automatically creates PDB matching your Deployment or StatefulSet.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/pdb-maxunavailable-1
resources:
  - deployment.yaml  # Must have app.kubernetes.io/name label
```

**Requirements:**
- Deployment/StatefulSet must have `spec.template.metadata.labels.[app.kubernetes.io/name]`
- Component uses Kustomize replacements to auto-populate PDB

**Variants:**
- `pdb-maxunavailable-1` - Max 1 pod unavailable (most common)

---

### 3. ServiceMonitor Component

Automatically creates ServiceMonitor for Prometheus scraping.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/monitoring/servicemonitor
resources:
  - service.yaml  # Must have app.kubernetes.io/name label and "metrics" port
```

**Default Configuration:**
- Port: `metrics`
- Interval: `30s`
- Path: `/metrics`
- Scheme: `http`

**Requirements:**
- Service must have `metadata.labels.[app.kubernetes.io/name]`
- Service must expose a port named `metrics`

---

### 4. PodMonitor Component

For components that expose metrics without a Service (e.g., DaemonSets).

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/monitoring/podmonitor
resources:
  - daemonset.yaml  # Must have app.kubernetes.io/name label
```

---

### 5. PrometheusRule Component

Common alert rules for application health.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: my-app
components:
  - ../../components/monitoring/prometheusrule-basic
```

**Alerts Included:**
- `PodNotReady` - Pod not ready for 5m
- `HighMemoryUsage` - Memory > 90% for 10m
- `HighCPUUsage` - CPU > 90% for 10m
- `ContainerRestarting` - Container restarting
- `DeploymentReplicasMismatch` - Replicas don't match desired

---

### 6. ExternalSecret Component

Template for 1Password secret integration.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/externalsecret
patches:
  - patch: |-
      - op: replace
        path: /metadata/name
        value: my-secret
      - op: replace
        path: /spec/target/name
        value: my-secret
      - op: add
        path: /spec/data
        value:
          - secretKey: password
            remoteRef:
              key: kubernetes/my-app/credentials
              property: password
    target:
      kind: ExternalSecret
```

**Variables Used:**
- `${EXTERNAL_SECRET_STORE}` - Usually `onepassword`

---

### 7. NetworkPolicy Components

#### Deny All (Baseline Security)

```yaml
components:
  - ../../components/networkpolicy/deny-all
```

Blocks all traffic by default. Add allow policies after this.

#### Allow DNS

```yaml
components:
  - ../../components/networkpolicy/allow-dns
```

Permits DNS queries to CoreDNS in kube-system.

#### Allow Internal

```yaml
components:
  - ../../components/networkpolicy/allow-internal
```

Allows communication within the same namespace.

**Common Pattern:**
```yaml
components:
  - ../../components/networkpolicy/deny-all       # Deny everything
  - ../../components/networkpolicy/allow-dns      # Except DNS
  - ../../components/networkpolicy/allow-internal # And same-namespace
```

---

## 🏗️ Complete Example

### Application Structure

```
kubernetes/infrastructure/myapp/
├── kustomization.yaml    # Uses components
├── deployment.yaml       # Application workload
├── service.yaml          # Service definition
└── configmap.yaml        # Configuration
```

### kustomization.yaml

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp

components:
  # Core
  - ../../components/namespace

  # High Availability
  - ../../components/pdb-maxunavailable-1

  # Monitoring
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic

  # Security
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-internal

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/component: backend
```

### deployment.yaml

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

### service.yaml

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app.kubernetes.io/name: myapp
  ports:
    - name: http
      port: 80
      targetPort: http
    - name: metrics
      port: 9090
      targetPort: metrics
```

### What Gets Generated

From these 3 files + components, Kustomize generates:

1. ✅ Namespace (with PSS labels)
2. ✅ Deployment (your definition)
3. ✅ Service (your definition)
4. ✅ ConfigMap (your definition)
5. ✅ PodDisruptionBudget (auto-configured)
6. ✅ ServiceMonitor (auto-configured)
7. ✅ PrometheusRule (5 common alerts)
8. ✅ NetworkPolicy: deny-all
9. ✅ NetworkPolicy: allow-dns
10. ✅ NetworkPolicy: allow-internal

**Total:** 10 resources from 3 YAML files + components

**Without components:** Would need ~10 manually-written YAML files

**Code reduction:** ~70%! 🎉

---

## 🎯 Best Practices

### 1. Always Use Namespace Component

```yaml
# ✅ Good
components:
  - ../../components/namespace

# ❌ Bad
resources:
  - namespace.yaml  # Manual namespace creation
```

### 2. Require app.kubernetes.io/name Label

All workloads should have this label for component auto-configuration:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: my-app
```

### 3. Layer Components Logically

```yaml
components:
  # Core (namespace first)
  - ../../components/namespace

  # HA
  - ../../components/pdb-maxunavailable-1

  # Monitoring (after workload defined)
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic

  # Security (last - policies reference resources)
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
```

### 4. Use Common Labels

Set common labels at kustomization level:

```yaml
commonLabels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: platform
```

### 5. Customize When Needed

Components are templates. Override via patches:

```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/maxUnavailable
        value: 2
    target:
      kind: PodDisruptionBudget
```

---

## 🔬 Testing Components

### Build Locally

```bash
# Test component usage
cd kubernetes/infrastructure/myapp
kustomize build .

# Verify resources generated
kustomize build . | kubectl apply --dry-run=client -f -
```

### Validate

```bash
# Check all resources created
kustomize build . | yq e 'select(.kind != null) | .kind' -

# Count resources
kustomize build . | yq e 'select(.kind != null)' - | grep -c '^kind:'
```

---

## 📊 Component Benefits

### Code Reduction

| Without Components | With Components | Reduction |
|-------------------|-----------------|-----------|
| ~15 YAML files | ~5 YAML files | ~66% |
| ~500 lines | ~150 lines | ~70% |
| Manual PDB config | Auto-configured | 100% |
| Manual monitoring | Auto-configured | 100% |

### Standardization

✅ **Consistent** - Same patterns across all apps
✅ **Best Practices** - Security and HA built-in
✅ **Maintainable** - Update component, all apps benefit
✅ **Discoverable** - Easy to see what's configured

### Multi-Cluster Compatible

Components work with variable substitution:

```yaml
# In cluster kustomization
postBuild:
  substitute:
    CLUSTER: infra
    EXTERNAL_SECRET_STORE: onepassword
```

Components reference `${EXTERNAL_SECRET_STORE}` and it works across all clusters!

---

## 🚀 Next Steps

1. **Review Examples** - See `kubernetes/infrastructure/` for real usage
2. **Create Your App** - Copy pattern from examples
3. **Customize** - Add patches for app-specific needs
4. **Extend** - Create new components for your patterns

---

## 📚 References

- [Kustomize Components](https://kubectl.docs.kubernetes.io/guides/config_management/components/)
- [Kustomize Replacements](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/replacements/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

**Created:** 2025-10-15
**Phase:** 2 - Component Library Implementation
**Status:** Complete ✅
