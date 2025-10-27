# 26 — STORY-SEC-NP-BASELINE — Create Baseline NetworkPolicy Manifests

Sequence: 26/50 | Prev: STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md | Next: STORY-IDP-KEYCLOAK-OPERATOR.md
Sprint: 5 | Lane: Security
Global Sequence: 26/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links:
- docs/architecture.md §21
- kubernetes/components/networkpolicy/deny-all/
- kubernetes/components/networkpolicy/allow-dns/
- kubernetes/components/networkpolicy/allow-kube-api/
- kubernetes/components/networkpolicy/allow-fqdn/
- kubernetes/infrastructure/security/networkpolicy/
- kubernetes/infrastructure/security/networkpolicy/ks.yaml

## Story
As a platform engineer, I want to **create baseline NetworkPolicy manifests** implementing default-deny ingress/egress with explicit allow rules for DNS, kube-apiserver access, and optional FQDN allowlists, so that when deployed in Story 45 all platform and tenant namespaces have a consistent, auditable zero-trust network security foundation.

## Why / Outcome
- **Zero-Trust Foundation**: Default-deny network policies reduce attack surface
- **Consistent Security Baseline**: All namespaces inherit same security posture
- **Auditable Policies**: Declarative manifests tracked in git
- **Reusable Components**: Kustomize components enable consistent application across namespaces
- **Namespace Isolation**: Prevents lateral movement between workloads
- **Compliance**: Meets security best practices for production Kubernetes

## Scope

### This Story (Manifest Creation)
Create reusable NetworkPolicy component manifests and infrastructure composition:
1. **Default-Deny Component**: Block all ingress and egress by default
2. **Allow-DNS Component**: Permit DNS resolution (port 53 UDP/TCP to kube-dns)
3. **Allow-Kube-API Component**: Permit access to Kubernetes API server
4. **Allow-Internal Component**: Permit pod-to-pod communication within namespace
5. **Allow-FQDN Component**: Template for FQDN-based egress allowlists (Cilium)
6. **Infrastructure Kustomization**: Aggregate components for platform namespaces
7. **Tenant Template**: Reusable Kustomization template for tenant namespace onboarding
8. **Flux Kustomization**: Wire policies into cluster infrastructure

**Validation**: Local-only using `kubectl --dry-run=client`, `flux build`, `kustomize build`, and `kubeconform`

### Deferred to Story 45 (Deployment & Validation)
- Apply NetworkPolicies to platform namespaces
- Verify default-deny enforcement (blocked traffic)
- Validate DNS resolution works
- Validate kube-apiserver access works
- Test FQDN allowlist functionality
- Verify tenant namespace isolation

## Acceptance Criteria

### Manifest Creation (This Story)
1. **AC1-DefaultDeny**: Default-deny component with both Kubernetes NetworkPolicy and CiliumNetworkPolicy variants blocking all ingress/egress
2. **AC2-AllowDNS**: Allow-DNS component permitting DNS traffic (port 53 UDP/TCP) to kube-system/kube-dns with both KNP and CNP variants
3. **AC3-AllowKubeAPI**: Allow-kube-api component permitting egress to Kubernetes API server (port 443/6443) with both KNP and CNP variants
4. **AC4-AllowInternal**: Allow-internal component permitting pod-to-pod traffic within namespace
5. **AC5-AllowFQDN**: Allow-FQDN template component using Cilium `toFQDNs` for external domain allowlists
6. **AC6-InfraKustomization**: Infrastructure Kustomization applying baseline policies to platform namespaces (observability, cnpg-system, dragonfly-system, harbor, gitlab-system)
7. **AC7-TenantTemplate**: Tenant namespace Kustomization template with baseline policies for easy onboarding
8. **AC8-Documentation**: README explaining component usage, policy ordering, and namespace onboarding
9. **AC9-FluxKustomization**: Flux Kustomization manifest with proper dependencies and health checks
10. **AC10-Validation**: All manifests pass local validation: `kubectl --dry-run=client`, `flux build`, `kustomize build`, `kubeconform`

### Deferred to Story 45 (NOT Part of This Story)
- ~~NetworkPolicies applied to platform namespaces~~
- ~~Default-deny enforcement validated~~
- ~~DNS resolution tested~~
- ~~Kube-apiserver access verified~~
- ~~FQDN allowlist tested~~
- ~~Tenant namespace isolation validated~~

## Dependencies / Inputs

### Prerequisites
- **STORY-NET-CILIUM-CORE-GITOPS**: Cilium deployed with NetworkPolicy enforcement enabled
- **Platform Namespaces**: Created in previous stories (observability, cnpg-system, dragonfly-system, etc.)

### Local Tools Required
- `kubectl` - Kubernetes manifest validation
- `flux` - GitOps manifest validation
- `kustomize` - Kustomization building
- `kubeconform` - Kubernetes schema validation
- `yq` - YAML processing
- `git` - Version control

### Cluster Settings Variables
From `kubernetes/clusters/infra/cluster-settings.yaml`:
```yaml
# Cilium Configuration
CILIUM_POLICY_ENFORCEMENT: "default"  # Enforces NetworkPolicies

# DNS Configuration
DNS_SERVICE_NAME: "kube-dns"
DNS_SERVICE_NAMESPACE: "kube-system"
DNS_PORT: "53"

# Kube-API Configuration
KUBE_API_SERVICE_NAME: "kubernetes"
KUBE_API_SERVICE_NAMESPACE: "default"
KUBE_API_PORT: "443"
```

## Tasks / Subtasks

### T1: Verify Prerequisites and Strategy
- [ ] Review Cilium NetworkPolicy enforcement mode (should be "default")
- [ ] List platform namespaces requiring baseline policies
- [ ] Document policy ordering and precedence rules
- [ ] Review Cilium vs. Kubernetes NetworkPolicy feature differences
- [ ] Plan component structure for maximum reusability

### T2: Create Default-Deny Component
**Directory**: `kubernetes/components/networkpolicy/deny-all/`

**File**: `kubernetes/components/networkpolicy/deny-all/networkpolicy.yaml`

```yaml
---
# Kubernetes NetworkPolicy: Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Kubernetes NetworkPolicy: Default deny all egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

**File**: `kubernetes/components/networkpolicy/deny-all/ciliumnetworkpolicy.yaml`

```yaml
---
# CiliumNetworkPolicy: Default deny all ingress and egress
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector: {}
  # Empty ingress/egress arrays = deny all
  ingress: []
  egress: []
```

**File**: `kubernetes/components/networkpolicy/deny-all/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - networkpolicy.yaml
  - ciliumnetworkpolicy.yaml
```

**File**: `kubernetes/components/networkpolicy/deny-all/README.md`

```markdown
# Default Deny All NetworkPolicy Component

Blocks all ingress and egress traffic by default.

## Usage

Add to your namespace Kustomization:

\`\`\`yaml
components:
  - ../../../components/networkpolicy/deny-all
\`\`\`

## Behavior

- **Ingress**: All inbound traffic blocked (including from same namespace)
- **Egress**: All outbound traffic blocked (including DNS, kube-api)

**IMPORTANT**: This component alone will break DNS and kube-api access. Always combine with `allow-dns` and `allow-kube-api` components.

## Policy Types

- **Kubernetes NetworkPolicy**: `default-deny-all-ingress`, `default-deny-all-egress`
- **CiliumNetworkPolicy**: `default-deny-all`

Both policy types are applied for defense-in-depth.
```

### T3: Create Allow-DNS Component
**Directory**: `kubernetes/components/networkpolicy/allow-dns/`

**File**: `kubernetes/components/networkpolicy/allow-dns/networkpolicy.yaml`

```yaml
---
# Kubernetes NetworkPolicy: Allow DNS egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow DNS queries to kube-dns
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**File**: `kubernetes/components/networkpolicy/allow-dns/ciliumnetworkpolicy.yaml`

```yaml
---
# CiliumNetworkPolicy: Allow DNS egress
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  endpointSelector: {}
  egress:
    # Allow DNS to kube-dns in kube-system
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
          rules:
            dns:
              - matchPattern: "*"
```

**File**: `kubernetes/components/networkpolicy/allow-dns/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - networkpolicy.yaml
  - ciliumnetworkpolicy.yaml
```

**File**: `kubernetes/components/networkpolicy/allow-dns/README.md`

```markdown
# Allow DNS NetworkPolicy Component

Permits DNS resolution to kube-dns in kube-system namespace.

## Usage

Add to your namespace Kustomization:

\`\`\`yaml
components:
  - ../../../components/networkpolicy/allow-dns
\`\`\`

## Behavior

- **Egress**: Allow UDP/TCP port 53 to kube-dns pods in kube-system
- **DNS Pattern**: Cilium variant includes DNS rule matching all patterns (`*`)

## Prerequisites

- Must be combined with `deny-all` component to function as intended
- kube-dns must be labeled with `k8s-app: kube-dns`

## Testing

\`\`\`bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- nslookup kubernetes.default
# Expected: Successful DNS resolution
\`\`\`
```

### T4: Create Allow-Kube-API Component
**Directory**: `kubernetes/components/networkpolicy/allow-kube-api/`

**File**: `kubernetes/components/networkpolicy/allow-kube-api/networkpolicy.yaml`

```yaml
---
# Kubernetes NetworkPolicy: Allow kube-apiserver egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kube-api-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow access to Kubernetes API server
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: default
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 6443
```

**File**: `kubernetes/components/networkpolicy/allow-kube-api/ciliumnetworkpolicy.yaml`

```yaml
---
# CiliumNetworkPolicy: Allow kube-apiserver egress
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-kube-api-egress
spec:
  endpointSelector: {}
  egress:
    # Allow HTTPS to Kubernetes API server
    - toEntities:
        - kube-apiserver
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
            - port: "6443"
              protocol: TCP
```

**File**: `kubernetes/components/networkpolicy/allow-kube-api/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - networkpolicy.yaml
  - ciliumnetworkpolicy.yaml
```

**File**: `kubernetes/components/networkpolicy/allow-kube-api/README.md`

```markdown
# Allow Kube-API NetworkPolicy Component

Permits access to the Kubernetes API server.

## Usage

Add to your namespace Kustomization:

\`\`\`yaml
components:
  - ../../../components/networkpolicy/allow-kube-api
\`\`\`

## Behavior

- **Egress**: Allow TCP ports 443 and 6443 to kube-apiserver
- **Entity**: Cilium variant uses `toEntities: kube-apiserver` for built-in entity matching

## Prerequisites

- Must be combined with `deny-all` component to function as intended

## Testing

\`\`\`bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- curl -sfk https://kubernetes.default.svc
# Expected: Kubernetes API server response (forbidden without token is OK)
\`\`\`
```

### T5: Create Allow-Internal Component
**Directory**: `kubernetes/components/networkpolicy/allow-internal/`

**File**: `kubernetes/components/networkpolicy/allow-internal/networkpolicy.yaml`

```yaml
---
# Kubernetes NetworkPolicy: Allow pod-to-pod within namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from same namespace
    - from:
        - podSelector: {}
  egress:
    # Allow to same namespace
    - to:
        - podSelector: {}
```

**File**: `kubernetes/components/networkpolicy/allow-internal/ciliumnetworkpolicy.yaml`

```yaml
---
# CiliumNetworkPolicy: Allow pod-to-pod within namespace
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-internal
spec:
  endpointSelector: {}
  ingress:
    # Allow from same namespace
    - fromEndpoints:
        - {}
  egress:
    # Allow to same namespace
    - toEndpoints:
        - {}
```

**File**: `kubernetes/components/networkpolicy/allow-internal/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - networkpolicy.yaml
  - ciliumnetworkpolicy.yaml
```

**File**: `kubernetes/components/networkpolicy/allow-internal/README.md`

```markdown
# Allow Internal NetworkPolicy Component

Permits pod-to-pod communication within the same namespace.

## Usage

Add to your namespace Kustomization:

\`\`\`yaml
components:
  - ../../../components/networkpolicy/allow-internal
\`\`\`

## Behavior

- **Ingress**: Allow from any pod in same namespace
- **Egress**: Allow to any pod in same namespace

## Use Cases

- Microservices within a namespace need to communicate
- Database pods need to talk to each other (e.g., replication)
- Application pods need to access local cache (e.g., Redis in same namespace)

## Security Note

This component allows all traffic within the namespace. For finer-grained control, use specific label-based policies instead.
```

### T6: Create Allow-FQDN Template Component
**Directory**: `kubernetes/components/networkpolicy/allow-fqdn/`

**File**: `kubernetes/components/networkpolicy/allow-fqdn/ciliumnetworkpolicy.yaml`

```yaml
---
# CiliumNetworkPolicy: Allow egress to specific FQDNs
# TEMPLATE: Customize matchPattern and matchName for your use case
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-fqdn-egress
spec:
  endpointSelector: {}
  egress:
    # Allow HTTPS to specific FQDNs
    - toFQDNs:
        # Pattern matching (wildcards supported)
        - matchPattern: "*.github.com"
        - matchPattern: "*.githubusercontent.com"
        # Exact matching
        - matchName: "registry-1.docker.io"
        - matchName: "ghcr.io"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

**File**: `kubernetes/components/networkpolicy/allow-fqdn/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ciliumnetworkpolicy.yaml
```

**File**: `kubernetes/components/networkpolicy/allow-fqdn/README.md`

```markdown
# Allow FQDN NetworkPolicy Component (Cilium)

Permits egress to specific fully-qualified domain names using Cilium's FQDN policy.

## Features

- **DNS-aware**: Cilium intercepts DNS responses and allows traffic to resolved IPs
- **Pattern Matching**: Use wildcards like `*.github.com`
- **Exact Matching**: Use `matchName` for specific domains

## Usage

Copy and customize this component for your namespace:

\`\`\`yaml
# In your namespace kustomization
components:
  - ../../../components/networkpolicy/allow-fqdn
\`\`\`

## Customization

Edit `ciliumnetworkpolicy.yaml` to match your required FQDNs:

\`\`\`yaml
toFQDNs:
  - matchPattern: "*.mycompany.com"
  - matchName: "api.external-service.io"
\`\`\`

## How It Works

1. Pod makes DNS query for allowed FQDN
2. Cilium intercepts DNS response and learns IP addresses
3. Cilium allows traffic to those IPs on specified ports
4. IPs are cached with TTL matching DNS record TTL

## Prerequisites

- Cilium with DNS proxy enabled (default in modern versions)
- Must be combined with `allow-dns` component for DNS resolution

## Testing

\`\`\`bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- curl -s https://github.com
# Expected: Successful if github.com matches allowlist
\`\`\`

## Security Notes

- Wildcards should be used carefully (e.g., `*.com` is too broad)
- FQDNs are resolved via DNS, so DNS spoofing protections are important
- Consider using IP-based policies for highly sensitive traffic
```

### T7: Create Infrastructure Kustomization
**Directory**: `kubernetes/infrastructure/security/networkpolicy/`

**File**: `kubernetes/infrastructure/security/networkpolicy/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Apply baseline network policies to platform namespaces

resources:
  # Observability namespace
  - observability-policies.yaml

  # Database namespaces
  - cnpg-system-policies.yaml
  - dragonfly-system-policies.yaml

  # Platform namespaces
  - harbor-policies.yaml
  - gitlab-system-policies.yaml
  - flux-system-policies.yaml
```

**File**: `kubernetes/infrastructure/security/networkpolicy/observability-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: observability

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/cnpg-system-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: cnpg-system

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/dragonfly-system-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: dragonfly-system

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/harbor-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: harbor

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/gitlab-system-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: gitlab-system

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/flux-system-policies.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: flux-system

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

**File**: `kubernetes/infrastructure/security/networkpolicy/README.md`

```markdown
# Baseline NetworkPolicy Infrastructure

Applies baseline network policies to platform namespaces.

## Applied Policies

Each platform namespace gets:
1. **deny-all**: Block all ingress/egress by default
2. **allow-dns**: Permit DNS resolution
3. **allow-kube-api**: Permit Kubernetes API access
4. **allow-internal**: Permit pod-to-pod within namespace

## Platform Namespaces

- `observability` - VictoriaMetrics, VictoriaLogs, Grafana
- `cnpg-system` - CloudNativePG operator and clusters
- `dragonfly-system` - DragonflyDB cache
- `harbor` - Container registry
- `gitlab-system` - GitLab
- `flux-system` - Flux GitOps controllers

## Adding New Namespaces

1. Create `<namespace>-policies.yaml`:
   \`\`\`yaml
   apiVersion: kustomize.config.k8s.io/v1alpha1
   kind: Component

   namespace: <namespace>

   components:
     - ../../../components/networkpolicy/deny-all
     - ../../../components/networkpolicy/allow-dns
     - ../../../components/networkpolicy/allow-kube-api
     - ../../../components/networkpolicy/allow-internal
   \`\`\`

2. Add to `kustomization.yaml`:
   \`\`\`yaml
   resources:
     - <namespace>-policies.yaml
   \`\`\`

## Testing

See individual component READMEs for testing procedures.
```

### T8: Create Tenant Template
**File**: `docs/templates/tenant-namespace-networkpolicy.yaml`

```yaml
# Template: Tenant Namespace NetworkPolicy Kustomization
# Copy this file to your tenant namespace directory and customize

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <TENANT-NAMESPACE>

# Baseline network policies
components:
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-kube-api
  - ../../components/networkpolicy/allow-internal

# Optional: Add FQDN allowlist
# Uncomment and customize for internet egress
# - ../../components/networkpolicy/allow-fqdn

# Application-specific resources
resources:
  # Add your application manifests here
  # - deployment.yaml
  # - service.yaml
  # - etc.
```

**File**: `docs/templates/README-tenant-networkpolicy.md`

```markdown
# Tenant Namespace NetworkPolicy Template

This template provides baseline network policies for tenant namespaces.

## Quick Start

1. Copy `tenant-namespace-networkpolicy.yaml` to your namespace directory:
   \`\`\`bash
   cp docs/templates/tenant-namespace-networkpolicy.yaml kubernetes/tenants/<your-namespace>/kustomization.yaml
   \`\`\`

2. Edit the file and replace `<TENANT-NAMESPACE>` with your namespace name

3. Add your application resources

4. (Optional) Customize FQDN allowlist if internet egress is needed

## Included Policies

- **deny-all**: Blocks all traffic by default
- **allow-dns**: Permits DNS resolution
- **allow-kube-api**: Permits Kubernetes API access
- **allow-internal**: Permits pod-to-pod communication within namespace

## Testing Your Policies

\`\`\`bash
# Create test pod
kubectl -n <your-namespace> run curl --image=curlimages/curl -- sleep 3600

# Test DNS (should work)
kubectl -n <your-namespace> exec curl -- nslookup kubernetes.default

# Test kube-api (should work)
kubectl -n <your-namespace> exec curl -- curl -sfk https://kubernetes.default.svc

# Test internet egress (should fail unless FQDN allowlist added)
kubectl -n <your-namespace> exec curl -- curl -s https://example.com

# Cleanup
kubectl -n <your-namespace> delete pod curl
\`\`\`

## Adding FQDN Allowlist

If your application needs to access external services:

1. Copy FQDN component:
   \`\`\`bash
   mkdir -p kubernetes/tenants/<your-namespace>/networkpolicy
   cp kubernetes/components/networkpolicy/allow-fqdn/ciliumnetworkpolicy.yaml \\
      kubernetes/tenants/<your-namespace>/networkpolicy/allow-fqdn.yaml
   \`\`\`

2. Edit and customize FQDNs:
   \`\`\`yaml
   toFQDNs:
     - matchPattern: "*.your-service.com"
     - matchName: "api.external.io"
   \`\`\`

3. Add to kustomization:
   \`\`\`yaml
   resources:
     - networkpolicy/allow-fqdn.yaml
   \`\`\`

## Troubleshooting

### DNS not working
- Verify kube-dns is running: `kubectl -n kube-system get pods -l k8s-app=kube-dns`
- Check DNS policy is applied: `kubectl -n <namespace> get networkpolicies`

### Kube-API not accessible
- Verify allow-kube-api policy exists
- Check for conflicting policies

### FQDN allowlist not working
- Verify Cilium DNS proxy is enabled
- Check Cilium logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=cilium | grep -i fqdn`
- Verify DNS resolution works first (FQDN requires DNS)
```

### T9: Create Flux Kustomization
**File**: `kubernetes/infrastructure/security/networkpolicy/ks.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-networkpolicy-baseline
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/infrastructure/security/networkpolicy

  prune: true
  wait: false  # NetworkPolicies don't have ready status

  # Depend on Cilium
  dependsOn:
    - name: cluster-infra-infrastructure

  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T10: Create Component Documentation
**File**: `kubernetes/components/networkpolicy/README.md`

```markdown
# NetworkPolicy Components

Reusable Kustomize components for baseline network security policies.

## Available Components

| Component | Purpose | Required | KNP | CNP |
|-----------|---------|----------|-----|-----|
| `deny-all` | Block all ingress/egress | Yes | ✓ | ✓ |
| `allow-dns` | Permit DNS resolution | Yes | ✓ | ✓ |
| `allow-kube-api` | Permit Kubernetes API access | Yes | ✓ | ✓ |
| `allow-internal` | Permit pod-to-pod within namespace | Recommended | ✓ | ✓ |
| `allow-fqdn` | Permit specific external FQDNs | Optional | ✗ | ✓ |

**KNP** = Kubernetes NetworkPolicy, **CNP** = CiliumNetworkPolicy

## Policy Ordering

NetworkPolicies are **additive** - multiple policies apply simultaneously. Order doesn't matter for different policies.

### Recommended Application Order

1. `deny-all` - Establish default-deny baseline
2. `allow-dns` - Enable DNS resolution
3. `allow-kube-api` - Enable Kubernetes API access
4. `allow-internal` - Enable pod-to-pod communication
5. `allow-fqdn` - (Optional) Enable specific external access

## Usage Patterns

### Platform Namespace (Recommended)

\`\`\`yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: my-platform-service

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
\`\`\`

### Tenant Namespace (Minimal)

\`\`\`yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: tenant-app

components:
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-kube-api
\`\`\`

### Internet-Facing Service

\`\`\`yaml
components:
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-kube-api
  - ../../components/networkpolicy/allow-internal
  - ../../components/networkpolicy/allow-fqdn  # Customize FQDNs
\`\`\`

## Testing

See individual component READMEs for detailed testing procedures.

### Quick Test

\`\`\`bash
NS=<your-namespace>

# Create test pod
kubectl -n $NS run curl --image=curlimages/curl -- sleep 3600

# Test DNS (should work with allow-dns)
kubectl -n $NS exec curl -- nslookup kubernetes.default

# Test kube-API (should work with allow-kube-api)
kubectl -n $NS exec curl -- curl -sfk https://kubernetes.default.svc

# Test internal (should work with allow-internal)
kubectl -n $NS run nginx --image=nginx --port=80
kubectl -n $NS exec curl -- curl -s http://nginx

# Test internet (should fail unless allow-fqdn configured)
kubectl -n $NS exec curl -- curl -s https://example.com

# Cleanup
kubectl -n $NS delete pod curl nginx
\`\`\`

## Troubleshooting

### Common Issues

1. **DNS not working**
   - Verify kube-dns pod label: `k8s-app: kube-dns`
   - Check namespace label on kube-system
   - Verify allow-dns component is applied

2. **Kube-API not accessible**
   - Check allow-kube-api component is applied
   - Verify ports 443/6443 are allowed

3. **FQDN allowlist not working (Cilium)**
   - Ensure DNS works first (FQDN requires DNS resolution)
   - Verify Cilium DNS proxy is enabled
   - Check Cilium agent logs for FQDN policy errors

4. **Policies not enforced**
   - Verify Cilium policy enforcement mode: `kubectl get cm -n kube-system cilium-config -o yaml | grep policy-enforcement`
   - Should be `default` or higher

### Validation Commands

\`\`\`bash
# List all NetworkPolicies in namespace
kubectl -n <namespace> get networkpolicies

# List all CiliumNetworkPolicies in namespace
kubectl -n <namespace> get ciliumnetworkpolicies

# Check Cilium policy enforcement
cilium policy get

# View Cilium endpoint policies
cilium endpoint list
cilium endpoint get <endpoint-id>
\`\`\`

## Best Practices

1. **Always start with deny-all**: Establishes zero-trust baseline
2. **Always include allow-dns**: Nearly all workloads need DNS
3. **Always include allow-kube-api**: Controllers and operators need API access
4. **Use allow-internal judiciously**: Only if pod-to-pod communication needed
5. **Minimize FQDN allowlists**: Use specific domains, avoid wildcards like `*.com`
6. **Test policies in non-prod first**: Verify no breakage before production
7. **Document exceptions**: If you skip deny-all, document why

## References

- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cilium NetworkPolicy](https://docs.cilium.io/en/stable/security/policy/)
- [Cilium FQDN Policy](https://docs.cilium.io/en/stable/security/policy/language/#dns-based)
```

### T11: Local Validation
- [ ] Validate all YAML syntax: `kubectl --dry-run=client -f <file>`
- [ ] Build component kustomizations: `kustomize build kubernetes/components/networkpolicy/deny-all`
- [ ] Build infrastructure kustomization: `kustomize build kubernetes/infrastructure/security/networkpolicy`
- [ ] Build Flux kustomization: `flux build kustomization cluster-networkpolicy-baseline --path ./kubernetes/infrastructure/security/networkpolicy`
- [ ] Schema validation: `kubeconform -summary -output json kubernetes/components/networkpolicy/**/*.yaml`
- [ ] Verify both KNP and CNP variants in each component
- [ ] Verify namespace selectors and pod selectors
- [ ] Review FQDN matchPattern and matchName syntax

### T12: Update Cluster Infrastructure Kustomization
**File**: `kubernetes/clusters/infra/infrastructure.yaml`

Add NetworkPolicy baseline to infrastructure composition:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-infra-infrastructure
  namespace: flux-system
spec:
  # ... existing configuration ...

  dependsOn:
    - name: cluster-infra-networking  # Cilium must be ready

  # Health checks would include new NetworkPolicy kustomization
```

### T13: Commit to Git
- [ ] Stage all new and modified files
- [ ] Commit with message: "feat(security): create baseline NetworkPolicy manifests (Story 26)"
- [ ] Include in commit message:
  - 5 reusable components (deny-all, allow-dns, allow-kube-api, allow-internal, allow-fqdn)
  - Both Kubernetes NetworkPolicy and CiliumNetworkPolicy variants
  - Infrastructure kustomization for 6 platform namespaces
  - Tenant namespace template for easy onboarding
  - Comprehensive documentation and testing guides

## Runtime Validation (MOVED TO STORY 45)

The following validation steps will be executed during Story 45 deployment:

### Policy Application Validation
```bash
# Verify NetworkPolicies applied to observability namespace
kubectl --context=infra -n observability get networkpolicies

# Verify CiliumNetworkPolicies applied
kubectl --context=infra -n observability get ciliumnetworkpolicies

# Check all platform namespaces
for ns in observability cnpg-system dragonfly-system harbor gitlab-system flux-system; do
  echo "=== $ns ==="
  kubectl --context=infra -n $ns get networkpolicies,ciliumnetworkpolicies
done
```

### Default-Deny Enforcement Validation
```bash
# Create test pod in observability namespace
kubectl --context=infra -n observability run curl --image=curlimages/curl -- sleep 3600

# Wait for pod to be running
kubectl --context=infra -n observability wait --for=condition=Ready pod/curl --timeout=60s

# Test that internet egress is blocked (default-deny egress)
kubectl --context=infra -n observability exec curl -- timeout 5 curl -s https://example.com
# Expected: Connection timeout or network unreachable

# Test that ingress from other namespaces is blocked
kubectl --context=infra -n default run nginx --image=nginx --port=80
kubectl --context=infra -n default expose pod nginx --port=80
kubectl --context=infra -n observability exec curl -- timeout 5 curl -s http://nginx.default.svc.cluster.local
# Expected: Connection timeout

# Cleanup
kubectl --context=infra -n default delete pod nginx svc nginx
```

### DNS Allow Validation
```bash
# Test DNS resolution (should work with allow-dns)
kubectl --context=infra -n observability exec curl -- nslookup kubernetes.default
# Expected: Successful DNS resolution with IP address

# Test DNS to external domain (should work)
kubectl --context=infra -n observability exec curl -- nslookup google.com
# Expected: Successful DNS resolution

# Verify DNS policy exists
kubectl --context=infra -n observability get networkpolicy allow-dns-egress
kubectl --context=infra -n observability get ciliumnetworkpolicy allow-dns-egress
```

### Kube-API Allow Validation
```bash
# Test kube-apiserver access (should work with allow-kube-api)
kubectl --context=infra -n observability exec curl -- curl -sfk https://kubernetes.default.svc
# Expected: Forbidden (403) - authentication error is OK, proves network access works

# Alternative: Check for valid response headers
kubectl --context=infra -n observability exec curl -- curl -sfkI https://kubernetes.default.svc | grep "HTTP/"
# Expected: HTTP/2 403 or similar

# Verify kube-api policy exists
kubectl --context=infra -n observability get networkpolicy allow-kube-api-egress
kubectl --context=infra -n observability get ciliumnetworkpolicy allow-kube-api-egress
```

### Internal Communication Validation
```bash
# Create two pods in same namespace
kubectl --context=infra -n observability run nginx --image=nginx --port=80
kubectl --context=infra -n observability expose pod nginx --port=80

# Test pod-to-pod communication (should work with allow-internal)
kubectl --context=infra -n observability exec curl -- curl -s http://nginx
# Expected: Nginx welcome page HTML

# Test pod-to-service communication
kubectl --context=infra -n observability exec curl -- curl -s http://nginx.observability.svc.cluster.local
# Expected: Nginx welcome page HTML

# Cleanup
kubectl --context=infra -n observability delete pod nginx svc nginx
```

### Cross-Namespace Isolation Validation
```bash
# Create service in different namespace
kubectl --context=infra -n default run nginx --image=nginx --port=80
kubectl --context=infra -n default expose pod nginx --port=80

# Attempt cross-namespace access (should fail with default policies)
kubectl --context=infra -n observability exec curl -- timeout 5 curl -s http://nginx.default.svc.cluster.local
# Expected: Connection timeout (blocked by default-deny)

# Cleanup
kubectl --context=infra -n default delete pod nginx svc nginx
kubectl --context=infra -n observability delete pod curl
```

### FQDN Allowlist Validation (Cilium)
```bash
# Create namespace with FQDN allowlist
kubectl --context=infra create namespace test-fqdn

# Apply policies with FQDN allowlist
kubectl --context=infra apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-github-fqdn
  namespace: test-fqdn
spec:
  endpointSelector: {}
  egress:
    - toFQDNs:
        - matchPattern: "*.github.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
EOF

# Also apply baseline policies
kubectl --context=infra -n test-fqdn apply -f kubernetes/components/networkpolicy/deny-all/
kubectl --context=infra -n test-fqdn apply -f kubernetes/components/networkpolicy/allow-dns/

# Create test pod
kubectl --context=infra -n test-fqdn run curl --image=curlimages/curl -- sleep 3600
kubectl --context=infra -n test-fqdn wait --for=condition=Ready pod/curl --timeout=60s

# Test allowed FQDN (should work)
kubectl --context=infra -n test-fqdn exec curl -- curl -sI https://github.com | grep "HTTP/"
# Expected: HTTP/2 200 or 301

# Test disallowed FQDN (should fail)
kubectl --context=infra -n test-fqdn exec curl -- timeout 5 curl -s https://example.com
# Expected: Connection timeout

# Check Cilium FQDN policy status
cilium policy get --context=infra | grep -A 20 "allow-github-fqdn"

# Cleanup
kubectl --context=infra delete namespace test-fqdn
```

### Policy Enforcement Mode Validation
```bash
# Verify Cilium policy enforcement mode
kubectl --context=infra -n kube-system get cm cilium-config -o yaml | grep policy-enforcement
# Expected: default or higher (never "never")

# Check Cilium agent status
cilium status --context=infra | grep "Policy enforcement"
# Expected: Enabled

# List Cilium endpoints with policy enforcement
cilium endpoint list --context=infra
# Should show endpoints with policy enforcement enabled
```

### Multi-Namespace Validation
```bash
# Verify policies applied to all platform namespaces
for ns in observability cnpg-system dragonfly-system harbor gitlab-system flux-system; do
  echo "=== Testing namespace: $ns ==="

  # Create test pod
  kubectl --context=infra -n $ns run test-curl --image=curlimages/curl -- sleep 3600
  kubectl --context=infra -n $ns wait --for=condition=Ready pod/test-curl --timeout=60s

  # Test DNS
  echo -n "DNS: "
  kubectl --context=infra -n $ns exec test-curl -- nslookup kubernetes.default > /dev/null 2>&1 && echo "OK" || echo "FAIL"

  # Test kube-API
  echo -n "Kube-API: "
  kubectl --context=infra -n $ns exec test-curl -- curl -sfk https://kubernetes.default.svc > /dev/null 2>&1 && echo "OK" || echo "OK (403 expected)"

  # Test internet egress (should fail)
  echo -n "Internet egress (should be blocked): "
  kubectl --context=infra -n $ns exec test-curl -- timeout 3 curl -s https://example.com > /dev/null 2>&1 && echo "FAIL (should be blocked)" || echo "OK (blocked)"

  # Cleanup
  kubectl --context=infra -n $ns delete pod test-curl --wait=false

  echo ""
done
```

### Cilium Policy Inspection
```bash
# View Cilium policy repository
cilium policy get --context=infra

# Check specific namespace policies
cilium policy get --context=infra --namespace observability

# View endpoint policies
cilium endpoint list --context=infra

# Get detailed policy for specific endpoint
ENDPOINT_ID=$(cilium endpoint list --context=infra -o json | jq -r '.[0].id')
cilium endpoint get $ENDPOINT_ID --context=infra
```

### Documentation Validation
```bash
# Verify README files exist
ls -la kubernetes/components/networkpolicy/*/README.md
ls -la kubernetes/infrastructure/security/networkpolicy/README.md
ls -la docs/templates/README-tenant-networkpolicy.md

# Verify all components have both KNP and CNP
for component in deny-all allow-dns allow-kube-api allow-internal; do
  echo "=== $component ==="
  ls kubernetes/components/networkpolicy/$component/
  grep -q "kind: NetworkPolicy" kubernetes/components/networkpolicy/$component/networkpolicy.yaml && echo "KNP: OK" || echo "KNP: MISSING"
  grep -q "kind: CiliumNetworkPolicy" kubernetes/components/networkpolicy/$component/ciliumnetworkpolicy.yaml && echo "CNP: OK" || echo "CNP: MISSING"
  echo ""
done
```

## Definition of Done

### Manifest Creation Complete (This Story)
- [ ] All acceptance criteria AC1-AC10 met with evidence
- [ ] Default-deny component created with KNP and CNP variants
- [ ] Allow-DNS component created with KNP and CNP variants
- [ ] Allow-kube-api component created with KNP and CNP variants
- [ ] Allow-internal component created with KNP and CNP variants
- [ ] Allow-FQDN template component created (Cilium only)
- [ ] Infrastructure Kustomization created applying policies to 6 platform namespaces
- [ ] Tenant namespace template created with usage documentation
- [ ] Component README files created with testing procedures
- [ ] Flux Kustomization manifest created with dependencies
- [ ] All manifests pass local validation (kubectl, flux, kustomize, kubeconform)
- [ ] Changes committed to git with descriptive commit message
- [ ] Story documented in change log

### NOT Part of DoD (Moved to Story 45)
- ~~NetworkPolicies deployed to platform namespaces~~
- ~~Default-deny enforcement validated~~
- ~~DNS resolution tested across namespaces~~
- ~~Kube-apiserver access verified~~
- ~~Cross-namespace isolation validated~~
- ~~FQDN allowlist tested~~

---

## Design Notes

### Zero-Trust Network Security

**Zero-Trust Principles**:
- **Default Deny**: Block all traffic unless explicitly allowed
- **Least Privilege**: Grant minimum necessary network access
- **Defense in Depth**: Multiple policy layers (KNP + CNP)
- **Explicit Allow**: Whitelist approach vs. blacklist

**Benefits**:
- **Reduced Attack Surface**: Limits blast radius of compromised pods
- **Lateral Movement Prevention**: Restricts pod-to-pod communication
- **Compliance**: Meets security frameworks (PCI-DSS, HIPAA, SOC 2)
- **Auditability**: All network rules declared in git

### Kubernetes NetworkPolicy vs. CiliumNetworkPolicy

**Why Both?**:
- **Defense in Depth**: Dual policy enforcement provides redundancy
- **Compatibility**: KNP works with any CNI supporting NetworkPolicy
- **Advanced Features**: CNP provides FQDN, identity-based policies, L7 rules

**Feature Comparison**:

| Feature | KNP | CNP |
|---------|-----|-----|
| Pod selectors | ✓ | ✓ |
| Namespace selectors | ✓ | ✓ |
| Port-based rules | ✓ | ✓ |
| FQDN-based egress | ✗ | ✓ |
| Identity-based policies | ✗ | ✓ |
| L7 (HTTP) policies | ✗ | ✓ |
| DNS-aware filtering | ✗ | ✓ |
| Entity selectors (kube-apiserver) | ✗ | ✓ |

**Strategy**:
- Use KNP for basic policies (default-deny, allow-dns, allow-kube-api)
- Use CNP for advanced features (FQDN allowlists, identity-based auth)
- Include both in components for maximum compatibility

### Policy Ordering and Precedence

**NetworkPolicy Behavior**:
- Policies are **additive** (OR logic, not AND)
- If any policy allows traffic, it's permitted
- Multiple policies in same namespace are combined
- No concept of policy priority or ordering

**Example**:
```yaml
# Policy 1: deny-all egress
policyTypes: [Egress]
egress: []

# Policy 2: allow-dns egress
policyTypes: [Egress]
egress:
  - to: [kube-dns]
    ports: [53]

# Result: DNS allowed, all other egress denied
```

**Best Practice**:
1. Apply default-deny first (establishes baseline)
2. Apply allow policies second (create exceptions)
3. Apply application-specific policies last (fine-grained control)

### Component Architecture

**Kustomize Components**:
- Reusable building blocks
- Composable via `components:` in Kustomization
- No need to fork/duplicate for each namespace

**Directory Structure**:
```
components/networkpolicy/
├── deny-all/
│   ├── networkpolicy.yaml        # KNP variant
│   ├── ciliumnetworkpolicy.yaml  # CNP variant
│   ├── kustomization.yaml
│   └── README.md
├── allow-dns/
│   ├── networkpolicy.yaml
│   ├── ciliumnetworkpolicy.yaml
│   ├── kustomization.yaml
│   └── README.md
└── ...
```

**Consumption**:
```yaml
# In platform namespace kustomization
components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
```

### DNS Policy Design

**Challenge**: Default-deny blocks DNS resolution

**Solution**: Explicit allow to kube-dns

**KNP Approach**:
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
        podSelector:
          matchLabels:
            k8s-app: kube-dns
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

**CNP Approach**:
```yaml
egress:
  - toEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: kube-system
          k8s-app: kube-dns
    toPorts:
      - ports:
          - port: "53"
            protocol: UDP
          - port: "53"
            protocol: TCP
        rules:
          dns:
            - matchPattern: "*"
```

**Key Differences**:
- CNP includes DNS rule matching all patterns (`*`)
- CNP uses `toEndpoints` with namespace label
- Both permit UDP and TCP (DNS can use either)

### Kube-API Policy Design

**Challenge**: Many workloads need Kubernetes API access (controllers, operators, service discovery)

**Solution**: Explicit allow to kube-apiserver

**KNP Approach**:
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: default
    ports:
      - protocol: TCP
        port: 443
      - protocol: TCP
        port: 6443
```

**CNP Approach** (Better):
```yaml
egress:
  - toEntities:
      - kube-apiserver
    toPorts:
      - ports:
          - port: "443"
            protocol: TCP
          - port: "6443"
            protocol: TCP
```

**CNP Advantage**: Uses built-in `kube-apiserver` entity, no need to know namespace or pod selectors

### FQDN-Based Egress (Cilium)

**How It Works**:
1. Pod performs DNS query for allowed FQDN
2. Cilium intercepts DNS response via DNS proxy
3. Cilium extracts IP addresses from DNS answer
4. Cilium allows traffic to those IPs on specified ports
5. IP allowance expires with DNS TTL

**Example**:
```yaml
toFQDNs:
  - matchPattern: "*.github.com"  # Wildcard
  - matchName: "ghcr.io"          # Exact
toPorts:
  - ports:
      - port: "443"
        protocol: TCP
```

**Security Considerations**:
- **DNS TTL**: IPs cached based on DNS TTL, updates automatically
- **DNS Spoofing**: Cilium trusts DNS responses (DNSSEC recommended)
- **Wildcard Scope**: Use narrow wildcards (`*.github.com` not `*.com`)
- **IP Changes**: Handles dynamic IPs gracefully via DNS re-resolution

**Limitations**:
- Cilium-only feature (no KNP equivalent)
- Requires Cilium DNS proxy (enabled by default)
- Doesn't work for direct-to-IP traffic

### Platform Namespace Baseline

**Applied Namespaces**:
1. `observability` - VictoriaMetrics, Grafana, Fluent Bit
2. `cnpg-system` - CloudNativePG operator and clusters
3. `dragonfly-system` - DragonflyDB cache
4. `harbor` - Container registry
5. `gitlab-system` - GitLab
6. `flux-system` - Flux controllers

**Baseline Policies**:
- `deny-all`: Default-deny ingress/egress
- `allow-dns`: Permit DNS resolution
- `allow-kube-api`: Permit Kubernetes API access
- `allow-internal`: Permit pod-to-pod within namespace

**Rationale**:
- **Consistency**: All platform namespaces have same security baseline
- **Auditability**: Single source of truth for network policies
- **Maintainability**: Update one component, all namespaces inherit
- **Tenant Parity**: Tenants can use same baseline via template

### Tenant Onboarding

**Template Approach**:
- Provide `tenant-namespace-networkpolicy.yaml` template
- Tenants copy and customize for their namespace
- Baseline policies included by default
- Optional FQDN allowlist with instructions

**Benefits**:
- **Self-Service**: Tenants onboard without platform team
- **Consistency**: Same security baseline across tenants
- **Documentation**: README provides testing and troubleshooting
- **Flexibility**: Tenants can add custom policies

**Onboarding Steps**:
1. Copy template to tenant namespace directory
2. Replace `<TENANT-NAMESPACE>` placeholder
3. Add application resources
4. (Optional) Customize FQDN allowlist
5. Apply via Flux or kubectl

### Testing Strategy

**Test Levels**:
1. **Syntax Validation**: `kubectl --dry-run=client`
2. **Schema Validation**: `kubeconform`
3. **Build Validation**: `kustomize build`, `flux build`
4. **Runtime Validation**: Deploy and test (Story 45)

**Runtime Tests**:
- **DNS Resolution**: `nslookup kubernetes.default`
- **Kube-API Access**: `curl -sfk https://kubernetes.default.svc`
- **Internet Egress**: `curl -s https://example.com` (should fail)
- **Cross-Namespace**: Access service in different namespace (should fail)
- **Internal**: Access service in same namespace (should work)

### Security Best Practices

1. **Always Default-Deny**: Never skip default-deny component
2. **Minimize Wildcards**: Use specific FQDNs, avoid `*.com`
3. **Avoid Allow-All**: Never use `podSelector: {}` in ingress without ports
4. **Document Exceptions**: If policies are skipped, document why
5. **Test in Non-Prod**: Validate policies don't break applications
6. **Monitor Denials**: Check Cilium logs for unexpected policy drops
7. **Periodic Review**: Audit policies quarterly for unused allowances

### Future Enhancements

**Identity-Based Policies** (STORY-SEC-SPIRE-CILIUM-AUTH):
- SPIRE integration for workload identity
- Mutual TLS (mTLS) enforcement
- Identity-based authorization (not just network)

**L7 Policies**:
- HTTP method restrictions (GET only, no POST)
- Path-based policies (`/api/public` allowed, `/admin` denied)
- Header-based policies (API key validation)

**Global Network Policies**:
- Cluster-wide policies applying to all namespaces
- Precedence over namespace-scoped policies

**Policy Monitoring**:
- Grafana dashboards for policy violations
- Alerts for unexpected denials
- Traffic flow visualization

---

## Change Log

### v3.0 - 2025-10-26 - Manifests-First Refinement
**Architect**: Separated manifest creation from deployment and validation following v3.0 architecture pattern.

**Changes**:
1. **Story Rewrite**: Focused on creating baseline NetworkPolicy component manifests
2. **Scope Split**: "This Story (Manifest Creation)" vs. "Deferred to Story 45 (Deployment & Validation)"
3. **Acceptance Criteria**: Rewrote AC1-AC10 for manifest creation; deferred runtime validation to Story 45
4. **Dependencies**: Updated to local tools only (kubectl, flux, kustomize, kubeconform, yq, git)
5. **Tasks**: Restructured to T1-T13 covering manifest creation and local validation:
   - T1: Prerequisites and strategy
   - T2: Default-deny component (KNP + CNP)
   - T3: Allow-DNS component (KNP + CNP)
   - T4: Allow-kube-api component (KNP + CNP)
   - T5: Allow-internal component (KNP + CNP)
   - T6: Allow-FQDN template component (CNP only)
   - T7: Infrastructure Kustomization (6 platform namespaces)
   - T8: Tenant namespace template with documentation
   - T9: Flux Kustomization with dependencies
   - T10: Component documentation with testing guides
   - T11: Local validation
   - T12: Update cluster infrastructure Kustomization
   - T13: Git commit
6. **Runtime Validation**: Created comprehensive "Runtime Validation (MOVED TO STORY 45)" section with 8 categories:
   - Policy application validation
   - Default-deny enforcement validation
   - DNS allow validation
   - Kube-API allow validation
   - Internal communication validation
   - Cross-namespace isolation validation
   - FQDN allowlist validation (Cilium)
   - Policy enforcement mode validation
   - Multi-namespace validation
   - Cilium policy inspection
   - Documentation validation
7. **DoD Update**: "Manifest Creation Complete" vs. "NOT Part of DoD (Moved to Story 45)"
8. **Design Notes**: Added comprehensive design documentation covering:
   - Zero-trust network security principles
   - Kubernetes NetworkPolicy vs. CiliumNetworkPolicy comparison
   - Policy ordering and precedence rules
   - Component architecture with Kustomize
   - DNS policy design (KNP vs. CNP approaches)
   - Kube-API policy design with entity selectors
   - FQDN-based egress with Cilium (how it works, security, limitations)
   - Platform namespace baseline (6 namespaces, 4 policies each)
   - Tenant onboarding process
   - Testing strategy (4 levels)
   - Security best practices (7 rules)
   - Future enhancements (identity-based, L7, global policies)

**Technical Details**:
- 5 reusable components: deny-all, allow-dns, allow-kube-api, allow-internal, allow-fqdn
- Both Kubernetes NetworkPolicy and CiliumNetworkPolicy variants (defense in depth)
- Infrastructure Kustomization applying baseline to 6 platform namespaces
- Tenant namespace template for self-service onboarding
- Comprehensive README files with testing procedures
- FQDN allowlist template using Cilium `toFQDNs` feature

**Validation Approach**:
- Local-only validation using kubectl --dry-run, flux build, kustomize build, kubeconform
- Comprehensive runtime validation commands documented for Story 45
- No cluster access required for this story

**Story Workflow**:
1. Create all NetworkPolicy component manifests
2. Create infrastructure composition for platform namespaces
3. Create tenant template for easy onboarding
4. Validate manifests locally using GitOps tools
5. Commit to git
6. Deployment and runtime validation deferred to Story 45
