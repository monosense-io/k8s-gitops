# 35 — STORY-TENANCY-BASELINE — Create Tenant Namespace Template

**Status:** v3.0 (Manifests-first) | **Date:** 2025-10-26
**Sequence:** 35/50 | **Prev:** STORY-APP-HARBOR.md | **Next:** STORY-BACKUP-VOLSYNC-APPS.md
**Sprint:** 7 | **Lane:** Platform | **Global Sequence:** 35/50

**Owner:** Platform Engineering
**Links:** docs/architecture.md §13; kubernetes/components/{namespace,networkpolicy,monitoring}; kubernetes/workloads/tenants

---

## 📖 Story

As a **Platform Engineer**, I need to **create a reusable tenant namespace template** with RBAC, LimitRange, ResourceQuota, NetworkPolicies, and ServiceAccounts, so that I have a standardized, secure baseline for onboarding new teams with consistent guardrails and documented onboarding procedures, ready for deployment and validation in Story 45.

## 🎯 Scope

### This Story (35): Manifest Creation (Local Only)
- Create tenant namespace template with parameterized Kustomization
- Define reusable components for namespace, RBAC, quotas, network policies
- Create example `demo` tenant to validate template
- Document tenant onboarding runbook
- **NO cluster deployment** (all work happens locally in git repository)

### Story 45: Deployment and Validation
- Deploy demo tenant via Flux reconciliation
- Validate RBAC, quotas, and network policies
- Test sample workloads in demo tenant
- Validate resource constraints and egress restrictions

---

## ✅ Acceptance Criteria

### Manifest Completeness (AC1-AC10)

**AC1**: Tenant template directory structure exists:
- `kubernetes/workloads/tenants/_template/` with parameterized Kustomization
- Components for namespace, RBAC, quotas, network policies

**AC2**: Namespace component with labels and annotations:
- `kubernetes/components/namespace/namespace.yaml` (parameterized)
- Labels: `app.kubernetes.io/managed-by: flux`, `toolkit.fluxcd.io/tenant: ${TEAM}`
- Annotations: Resource owner contact info

**AC3**: RBAC components for team members:
- `kubernetes/components/rbac/developer-role.yaml` (Role with pod CRUD, logs, exec)
- `kubernetes/components/rbac/developer-rolebinding.yaml` (RoleBinding to group)
- `kubernetes/components/rbac/viewer-role.yaml` (Role with read-only access)
- `kubernetes/components/rbac/viewer-rolebinding.yaml` (RoleBinding to group)

**AC4**: ServiceAccount for CI/CD:
- `kubernetes/components/rbac/cicd-serviceaccount.yaml`
- `kubernetes/components/rbac/cicd-role.yaml` (Role with deployment permissions)
- `kubernetes/components/rbac/cicd-rolebinding.yaml`

**AC5**: ResourceQuota for tenant limits:
- `kubernetes/components/quota/resourcequota.yaml`:
  - CPU requests: 4 cores
  - Memory requests: 8Gi
  - CPU limits: 8 cores
  - Memory limits: 16Gi
  - Pods: 20
  - Services: 10
  - PVCs: 5

**AC6**: LimitRange for default/max resource limits:
- `kubernetes/components/quota/limitrange.yaml`:
  - Container default: 100m CPU, 128Mi memory
  - Container max: 2 cores, 4Gi memory
  - PVC max: 10Gi

**AC7**: NetworkPolicies for security baseline:
- `kubernetes/components/networkpolicy/deny-all.yaml` (deny all ingress/egress)
- `kubernetes/components/networkpolicy/allow-dns.yaml` (allow DNS to kube-system)
- `kubernetes/components/networkpolicy/allow-kube-api.yaml` (allow kube-apiserver)
- `kubernetes/components/networkpolicy/allow-observability.yaml` (allow metrics scraping)

**AC8**: Example demo tenant:
- `kubernetes/workloads/tenants/demo/kustomization.yaml` (uses template)
- Substitutions: `TEAM=demo`, `CONTACT=platform@example.com`

**AC9**: Flux Kustomization for demo tenant:
- `kubernetes/workloads/tenants/demo/ks.yaml`:
  - Health check: Namespace
  - Wait: true, timeout: 2m

**AC10**: Tenant onboarding runbook:
- `docs/runbooks/tenant-onboarding.md`:
  - Template usage instructions
  - RBAC group mapping
  - Resource quota guidelines
  - Network policy customization
  - Troubleshooting guide

---

## 📋 Dependencies / Inputs

### Local Tools Required
- Text editor (VS Code, vim, etc.)
- `yq` for YAML validation
- `kustomize` for manifest validation (`kustomize build`)
- `flux` CLI for Kustomization validation (`flux build kustomization`)
- Git for version control

### Upstream Stories (Deployment Prerequisites - Story 45)
- **STORY-SEC-NP-BASELINE** — NetworkPolicy CRDs and baseline policies
- **STORY-OBS-VM-STACK** — VictoriaMetrics for metrics scraping

---

## 🛠️ Tasks / Subtasks

### T1: Prerequisites and Strategy

- [ ] **T1.1**: Review tenant isolation requirements
  - Study Kubernetes multi-tenancy best practices
  - Understand RBAC models (namespace-scoped vs cluster-scoped)
  - Review resource quota and limit range strategies
  - Understand network policy egress patterns

- [ ] **T1.2**: Define directory structure
  ```
  kubernetes/components/
  ├── namespace/
  │   ├── namespace.yaml
  │   └── kustomization.yaml
  ├── rbac/
  │   ├── developer-role.yaml
  │   ├── developer-rolebinding.yaml
  │   ├── viewer-role.yaml
  │   ├── viewer-rolebinding.yaml
  │   ├── cicd-serviceaccount.yaml
  │   ├── cicd-role.yaml
  │   ├── cicd-rolebinding.yaml
  │   └── kustomization.yaml
  ├── quota/
  │   ├── resourcequota.yaml
  │   ├── limitrange.yaml
  │   └── kustomization.yaml
  └── networkpolicy/
      ├── deny-all.yaml
      ├── allow-dns.yaml
      ├── allow-kube-api.yaml
      ├── allow-observability.yaml
      └── kustomization.yaml

  kubernetes/workloads/tenants/
  ├── _template/
  │   ├── kustomization.yaml
  │   └── README.md
  └── demo/
      ├── kustomization.yaml
      └── ks.yaml

  docs/runbooks/
  └── tenant-onboarding.md
  ```

### T2: Namespace Component

- [ ] **T2.1**: Create `components/namespace/namespace.yaml`
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: ${TEAM}
    labels:
      app.kubernetes.io/managed-by: flux
      toolkit.fluxcd.io/tenant: ${TEAM}
      team: ${TEAM}
    annotations:
      contact: ${CONTACT}
      description: "Namespace for ${TEAM} team"
  ```

- [ ] **T2.2**: Create `components/namespace/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - namespace.yaml
  ```

### T3: RBAC Components

- [ ] **T3.1**: Create `components/rbac/developer-role.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: developer
    namespace: ${TEAM}
  rules:
    # Pod management
    - apiGroups: [""]
      resources: ["pods", "pods/log", "pods/exec", "pods/portforward"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Deployment management
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Service management
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # ConfigMap and Secret management
    - apiGroups: [""]
      resources: ["configmaps", "secrets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # PVC management
    - apiGroups: [""]
      resources: ["persistentvolumeclaims"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Job management
    - apiGroups: ["batch"]
      resources: ["jobs", "cronjobs"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Ingress/Route management
    - apiGroups: ["networking.k8s.io"]
      resources: ["ingresses"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    - apiGroups: ["gateway.networking.k8s.io"]
      resources: ["httproutes"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Events (read-only)
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["get", "list", "watch"]
  ```

- [ ] **T3.2**: Create `components/rbac/developer-rolebinding.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: developer
    namespace: ${TEAM}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: developer
  subjects:
    # Bind to OIDC group (adjust based on your identity provider)
    - kind: Group
      name: ${TEAM}-developers
      apiGroup: rbac.authorization.k8s.io
  ```

- [ ] **T3.3**: Create `components/rbac/viewer-role.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: viewer
    namespace: ${TEAM}
  rules:
    # Read-only access to most resources
    - apiGroups: ["", "apps", "batch", "networking.k8s.io", "gateway.networking.k8s.io"]
      resources: ["*"]
      verbs: ["get", "list", "watch"]

    # Explicitly deny secrets (use view-no-secrets ClusterRole pattern)
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: []
  ```

- [ ] **T3.4**: Create `components/rbac/viewer-rolebinding.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: viewer
    namespace: ${TEAM}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: viewer
  subjects:
    - kind: Group
      name: ${TEAM}-viewers
      apiGroup: rbac.authorization.k8s.io
  ```

- [ ] **T3.5**: Create `components/rbac/cicd-serviceaccount.yaml`
  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: cicd
    namespace: ${TEAM}
  ```

- [ ] **T3.6**: Create `components/rbac/cicd-role.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: cicd
    namespace: ${TEAM}
  rules:
    # Deployment automation
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets", "statefulsets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    # Service updates
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["get", "list", "watch", "create", "update", "patch"]

    # ConfigMap updates
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch", "create", "update", "patch"]

    # Job execution
    - apiGroups: ["batch"]
      resources: ["jobs"]
      verbs: ["get", "list", "watch", "create", "delete"]

    # Pod logs (for debugging)
    - apiGroups: [""]
      resources: ["pods", "pods/log"]
      verbs: ["get", "list", "watch"]
  ```

- [ ] **T3.7**: Create `components/rbac/cicd-rolebinding.yaml`
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: cicd
    namespace: ${TEAM}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: cicd
  subjects:
    - kind: ServiceAccount
      name: cicd
      namespace: ${TEAM}
  ```

- [ ] **T3.8**: Create `components/rbac/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - developer-role.yaml
    - developer-rolebinding.yaml
    - viewer-role.yaml
    - viewer-rolebinding.yaml
    - cicd-serviceaccount.yaml
    - cicd-role.yaml
    - cicd-rolebinding.yaml
  ```

### T4: Quota Components

- [ ] **T4.1**: Create `components/quota/resourcequota.yaml`
  ```yaml
  apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: ${TEAM}-quota
    namespace: ${TEAM}
  spec:
    hard:
      # CPU and Memory
      requests.cpu: "4"
      requests.memory: 8Gi
      limits.cpu: "8"
      limits.memory: 16Gi

      # Object counts
      pods: "20"
      services: "10"
      services.loadbalancers: "0"  # No LoadBalancer services
      services.nodeports: "0"      # No NodePort services
      persistentvolumeclaims: "5"

      # Storage
      requests.storage: 50Gi
  ```

- [ ] **T4.2**: Create `components/quota/limitrange.yaml`
  ```yaml
  apiVersion: v1
  kind: LimitRange
  metadata:
    name: ${TEAM}-limits
    namespace: ${TEAM}
  spec:
    limits:
      # Container defaults and limits
      - type: Container
        default:
          cpu: 100m
          memory: 128Mi
        defaultRequest:
          cpu: 100m
          memory: 128Mi
        max:
          cpu: "2"
          memory: 4Gi
        min:
          cpu: 10m
          memory: 16Mi

      # PVC limits
      - type: PersistentVolumeClaim
        max:
          storage: 10Gi
        min:
          storage: 1Gi
  ```

- [ ] **T4.3**: Create `components/quota/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - resourcequota.yaml
    - limitrange.yaml
  ```

### T5: NetworkPolicy Components

- [ ] **T5.1**: Create `components/networkpolicy/deny-all.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: deny-all
    namespace: ${TEAM}
  spec:
    podSelector: {}
    policyTypes:
      - Ingress
      - Egress
  ```

- [ ] **T5.2**: Create `components/networkpolicy/allow-dns.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-dns
    namespace: ${TEAM}
  spec:
    podSelector: {}
    policyTypes:
      - Egress
    egress:
      # Allow DNS to kube-system
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53
  ```

- [ ] **T5.3**: Create `components/networkpolicy/allow-kube-api.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-kube-api
    namespace: ${TEAM}
  spec:
    podSelector: {}
    policyTypes:
      - Egress
    egress:
      # Allow kube-apiserver (default service)
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: default
        ports:
          - protocol: TCP
            port: 443
  ```

- [ ] **T5.4**: Create `components/networkpolicy/allow-observability.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-observability
    namespace: ${TEAM}
  spec:
    podSelector: {}
    policyTypes:
      - Ingress
    ingress:
      # Allow metrics scraping from observability namespace
      - from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: observability
        ports:
          - protocol: TCP
            port: 8080
          - protocol: TCP
            port: 9090
  ```

- [ ] **T5.5**: Create `components/networkpolicy/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - deny-all.yaml
    - allow-dns.yaml
    - allow-kube-api.yaml
    - allow-observability.yaml
  ```

### T6: Tenant Template

- [ ] **T6.1**: Create `workloads/tenants/_template/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization

  # Namespace
  namespace: ${TEAM}

  # Components (reusable manifests)
  components:
    - ../../../components/namespace
    - ../../../components/rbac
    - ../../../components/quota
    - ../../../components/networkpolicy

  # Replacements for parameterization
  replacements:
    - source:
        kind: Namespace
        name: ${TEAM}
        fieldPath: metadata.name
      targets:
        - select:
            kind: Role
          fieldPaths:
            - metadata.namespace
        - select:
            kind: RoleBinding
          fieldPaths:
            - metadata.namespace
        - select:
            kind: ServiceAccount
          fieldPaths:
            - metadata.namespace
        - select:
            kind: ResourceQuota
          fieldPaths:
            - metadata.namespace
        - select:
            kind: LimitRange
          fieldPaths:
            - metadata.namespace
        - select:
            kind: NetworkPolicy
          fieldPaths:
            - metadata.namespace
  ```

- [ ] **T6.2**: Create `workloads/tenants/_template/README.md`
  ```markdown
  # Tenant Template

  ## Usage

  1. **Copy template to create new tenant**:
     ```bash
     cp -r kubernetes/workloads/tenants/_template kubernetes/workloads/tenants/myteam
     ```

  2. **Update kustomization.yaml**:
     - Replace `${TEAM}` with your team name (e.g., `myteam`)
     - Replace `${CONTACT}` with team contact email

  3. **Create Flux Kustomization**:
     ```yaml
     # kubernetes/workloads/tenants/myteam/ks.yaml
     apiVersion: kustomize.toolkit.fluxcd.io/v1
     kind: Kustomization
     metadata:
       name: tenant-myteam
       namespace: flux-system
     spec:
       interval: 10m
       path: ./kubernetes/workloads/tenants/myteam
       prune: true
       wait: true
       timeout: 2m
       sourceRef:
         kind: GitRepository
         name: flux-system
       healthChecks:
         - apiVersion: v1
           kind: Namespace
           name: myteam
     ```

  4. **Commit and push**:
     ```bash
     git add kubernetes/workloads/tenants/myteam/
     git commit -m "feat(tenants): add myteam tenant"
     git push
     ```

  5. **Verify deployment**:
     ```bash
     flux reconcile kustomization tenant-myteam --with-source
     kubectl get ns myteam
     kubectl get resourcequota,limitrange -n myteam
     kubectl get networkpolicy -n myteam
     ```

  ## Components

  - **Namespace**: Team namespace with labels and annotations
  - **RBAC**: Developer and viewer roles with OIDC group bindings
  - **Quota**: ResourceQuota (4 CPU, 8Gi memory) and LimitRange
  - **NetworkPolicies**: Deny-all baseline + allow DNS/kube-api/observability

  ## Customization

  ### Adjust Resource Quotas

  Edit `components/quota/resourcequota.yaml`:
  ```yaml
  spec:
    hard:
      requests.cpu: "8"      # Increase CPU quota
      requests.memory: 16Gi  # Increase memory quota
  ```

  ### Add Custom Network Policies

  Create additional NetworkPolicy manifests in your tenant directory:
  ```yaml
  # myteam/allow-external-api.yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-external-api
    namespace: myteam
  spec:
    podSelector:
      matchLabels:
        app: myapp
    policyTypes:
      - Egress
    egress:
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 443
  ```

  ### Update RBAC Group Bindings

  Edit `components/rbac/developer-rolebinding.yaml`:
  ```yaml
  subjects:
    - kind: Group
      name: myteam-developers  # OIDC group from Keycloak
      apiGroup: rbac.authorization.k8s.io
  ```

  ## References

  - [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
  - [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
  - [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
  - [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
  ```

### T7: Demo Tenant Example

- [ ] **T7.1**: Create `workloads/tenants/demo/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization

  # Namespace
  namespace: demo

  # Use template components
  components:
    - ../../../components/namespace
    - ../../../components/rbac
    - ../../../components/quota
    - ../../../components/networkpolicy

  # Replacements for demo tenant
  replacements:
    - source:
        kind: Namespace
        name: demo
        fieldPath: metadata.name
      targets:
        - select:
            kind: Role
          fieldPaths:
            - metadata.namespace
        - select:
            kind: RoleBinding
          fieldPaths:
            - metadata.namespace
        - select:
            kind: ServiceAccount
          fieldPaths:
            - metadata.namespace
        - select:
            kind: ResourceQuota
          fieldPaths:
            - metadata.namespace
        - select:
            kind: LimitRange
          fieldPaths:
            - metadata.namespace
        - select:
            kind: NetworkPolicy
          fieldPaths:
            - metadata.namespace

  # Patches for demo-specific values
  patches:
    - patch: |-
        - op: replace
          path: /metadata/annotations/contact
          value: platform@example.com
      target:
        kind: Namespace
        name: demo
  ```

- [ ] **T7.2**: Create `workloads/tenants/demo/ks.yaml`
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: tenant-demo
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/tenants/demo
    prune: true
    wait: true
    timeout: 2m
    sourceRef:
      kind: GitRepository
      name: flux-system
    healthChecks:
      - apiVersion: v1
        kind: Namespace
        name: demo
  ```

### T8: Tenant Onboarding Runbook

- [ ] **T8.1**: Create `docs/runbooks/tenant-onboarding.md`
  ```markdown
  # Tenant Onboarding Runbook

  ## Overview

  This runbook guides platform engineers through onboarding a new team to the Kubernetes cluster with standardized namespace, RBAC, quotas, and network policies.

  ## Prerequisites

  - Keycloak OIDC groups configured for team members
  - Team resource requirements documented
  - Contact information for team lead

  ## Onboarding Steps

  ### 1. Create Tenant Namespace

  **Copy template**:
  ```bash
  TEAM="myteam"
  cp -r kubernetes/workloads/tenants/_template kubernetes/workloads/tenants/$TEAM
  cd kubernetes/workloads/tenants/$TEAM
  ```

  ### 2. Configure Tenant

  **Update kustomization.yaml**:
  - Replace `${TEAM}` with team name
  - Replace `${CONTACT}` with team contact email

  **Example**:
  ```yaml
  namespace: myteam

  patches:
    - patch: |-
        - op: replace
          path: /metadata/annotations/contact
          value: myteam-lead@example.com
      target:
        kind: Namespace
        name: myteam
  ```

  ### 3. Adjust Resource Quotas (if needed)

  **Default quotas**:
  - CPU requests: 4 cores
  - Memory requests: 8Gi
  - CPU limits: 8 cores
  - Memory limits: 16Gi
  - Pods: 20
  - Services: 10
  - PVCs: 5

  **To increase quotas**:
  ```yaml
  # Add to kustomization.yaml
  patches:
    - patch: |-
        - op: replace
          path: /spec/hard/requests.cpu
          value: "8"
        - op: replace
          path: /spec/hard/requests.memory
          value: 16Gi
      target:
        kind: ResourceQuota
        name: myteam-quota
  ```

  ### 4. Configure RBAC Groups

  **Update OIDC group bindings**:
  ```yaml
  # Add to kustomization.yaml
  patches:
    - patch: |-
        - op: replace
          path: /subjects/0/name
          value: myteam-developers
      target:
        kind: RoleBinding
        name: developer
    - patch: |-
        - op: replace
          path: /subjects/0/name
          value: myteam-viewers
      target:
        kind: RoleBinding
        name: viewer
  ```

  **Keycloak group mapping**:
  1. Create groups in Keycloak: `myteam-developers`, `myteam-viewers`
  2. Add team members to appropriate groups
  3. Verify OIDC claim includes group membership

  ### 5. Create Flux Kustomization

  **Create ks.yaml**:
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: tenant-myteam
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/tenants/myteam
    prune: true
    wait: true
    timeout: 2m
    sourceRef:
      kind: GitRepository
      name: flux-system
    healthChecks:
      - apiVersion: v1
        kind: Namespace
        name: myteam
  ```

  ### 6. Deploy Tenant

  **Commit and push**:
  ```bash
  git add kubernetes/workloads/tenants/myteam/
  git commit -m "feat(tenants): add myteam tenant with 4 CPU / 8Gi memory quota"
  git push
  ```

  **Verify deployment**:
  ```bash
  # Reconcile Flux
  flux reconcile kustomization tenant-myteam --with-source

  # Check namespace
  kubectl get ns myteam

  # Check RBAC
  kubectl get role,rolebinding,serviceaccount -n myteam

  # Check quotas
  kubectl get resourcequota,limitrange -n myteam
  kubectl describe resourcequota myteam-quota -n myteam

  # Check network policies
  kubectl get networkpolicy -n myteam
  ```

  ### 7. Validate RBAC

  **Test developer access**:
  ```bash
  # As developer user
  kubectl auth can-i create pods -n myteam --as=user@example.com
  kubectl auth can-i delete deployments -n myteam --as=user@example.com
  kubectl auth can-i get secrets -n myteam --as=user@example.com
  ```

  **Test viewer access**:
  ```bash
  # As viewer user
  kubectl auth can-i get pods -n myteam --as=viewer@example.com
  kubectl auth can-i create pods -n myteam --as=viewer@example.com
  ```

  ### 8. Test Resource Constraints

  **Deploy test pod**:
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: test-pod
    namespace: myteam
  spec:
    containers:
      - name: nginx
        image: nginx:alpine
        # Resources will be auto-applied from LimitRange
  ```

  **Verify limits**:
  ```bash
  kubectl describe pod test-pod -n myteam | grep -A 5 Limits
  # Should show: cpu: 100m, memory: 128Mi (from LimitRange default)
  ```

  **Test quota enforcement**:
  ```bash
  # Try to exceed quota
  kubectl describe resourcequota myteam-quota -n myteam
  # Create 21 pods (exceeds quota of 20)
  ```

  ### 9. Test Network Policies

  **Test DNS resolution**:
  ```bash
  kubectl run -it --rm debug --image=busybox --restart=Never -n myteam -- nslookup kubernetes.default
  # Should succeed (DNS allowed)
  ```

  **Test external egress (should fail with default policies)**:
  ```bash
  kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n myteam -- curl https://example.com
  # Should timeout (external egress denied)
  ```

  **Add custom egress policy if needed**:
  ```yaml
  # myteam/allow-external-https.yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-external-https
    namespace: myteam
  spec:
    podSelector:
      matchLabels:
        app: myapp
    policyTypes:
      - Egress
    egress:
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 443
  ```

  ## Offboarding

  **Remove tenant**:
  ```bash
  # Delete Flux Kustomization (will prune namespace)
  kubectl delete kustomization tenant-myteam -n flux-system

  # Or delete from git
  git rm -r kubernetes/workloads/tenants/myteam
  git commit -m "chore(tenants): offboard myteam tenant"
  git push
  ```

  ## Troubleshooting

  ### Quota Exceeded

  **Symptom**: Pod creation fails with "exceeded quota"

  **Solution**:
  ```bash
  # Check current usage
  kubectl describe resourcequota myteam-quota -n myteam

  # Increase quota or delete unused resources
  ```

  ### RBAC Access Denied

  **Symptom**: User cannot perform action

  **Solution**:
  ```bash
  # Check user's groups
  kubectl get --raw /apis/authentication.k8s.io/v1/tokenreviews \
    -H "Authorization: Bearer $TOKEN" | jq .status.user.groups

  # Verify group bindings
  kubectl get rolebinding -n myteam -o yaml | grep -A 5 subjects
  ```

  ### Network Policy Blocking Traffic

  **Symptom**: Pod cannot reach service

  **Solution**:
  ```bash
  # Check existing policies
  kubectl get networkpolicy -n myteam

  # Add specific egress/ingress rules
  ```

  ## References

  - Template: `kubernetes/workloads/tenants/_template/`
  - Components: `kubernetes/components/{namespace,rbac,quota,networkpolicy}/`
  - [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
  - [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
  ```

### T9: Validation and Git Commit

- [ ] **T9.1**: Validate all manifests with kustomize
  ```bash
  # Validate components
  kustomize build kubernetes/components/namespace
  kustomize build kubernetes/components/rbac
  kustomize build kubernetes/components/quota
  kustomize build kubernetes/components/networkpolicy

  # Validate demo tenant
  kustomize build kubernetes/workloads/tenants/demo
  ```

- [ ] **T9.2**: Validate Flux Kustomization
  ```bash
  # Validate demo tenant Flux Kustomization
  flux build kustomization tenant-demo \
    --path ./kubernetes/workloads/tenants/demo \
    --kustomization-file ./kubernetes/workloads/tenants/demo/ks.yaml
  ```

- [ ] **T9.3**: Commit manifests to git
  ```bash
  git add kubernetes/components/
  git add kubernetes/workloads/tenants/
  git add docs/runbooks/tenant-onboarding.md
  git commit -m "feat(tenants): add tenant namespace template with RBAC, quotas, and network policies

  - Create reusable components for namespace, RBAC, quota, networkpolicy
  - Add tenant template with parameterized Kustomization
  - Create demo tenant example
  - Add RBAC roles: developer (full CRUD), viewer (read-only), CI/CD
  - Set resource quotas: 4 CPU / 8Gi memory requests, 8 CPU / 16Gi limits
  - Add LimitRange: default 100m/128Mi, max 2 CPU / 4Gi per container
  - Create NetworkPolicies: deny-all + allow DNS/kube-api/observability
  - Document tenant onboarding runbook with validation steps

  Features:
  - Developer role: pod CRUD, deployment management, logs/exec
  - Viewer role: read-only access (no secrets)
  - CI/CD ServiceAccount: deployment automation
  - ResourceQuota: 20 pods, 10 services, 5 PVCs, 50Gi storage
  - NetworkPolicy: deny-all baseline with essential egress rules

  Story: STORY-TENANCY-BASELINE (35/50)
  Related: STORY-SEC-NP-BASELINE, STORY-OBS-VM-STACK"
  ```

---

## 🧪 Runtime Validation (Deferred to Story 45)

**IMPORTANT**: The following validation steps are **NOT performed in this story**. They are documented here for reference and will be executed in Story 45 after deployment.

### Deployment Validation (Story 45)

```bash
# 1. Deploy demo tenant
flux reconcile kustomization tenant-demo --with-source

# 2. Verify namespace
kubectl get ns demo
kubectl describe ns demo

# 3. Verify RBAC
kubectl get role,rolebinding,serviceaccount -n demo
kubectl describe role developer -n demo
kubectl describe rolebinding developer -n demo

# 4. Verify quotas
kubectl get resourcequota,limitrange -n demo
kubectl describe resourcequota demo-quota -n demo
kubectl describe limitrange demo-limits -n demo

# 5. Verify network policies
kubectl get networkpolicy -n demo
kubectl describe networkpolicy deny-all -n demo

# 6. Test RBAC (developer)
kubectl auth can-i create pods -n demo --as=developer@example.com
kubectl auth can-i delete deployments -n demo --as=developer@example.com
kubectl auth can-i get secrets -n demo --as=developer@example.com

# 7. Test RBAC (viewer)
kubectl auth can-i get pods -n demo --as=viewer@example.com
kubectl auth can-i create pods -n demo --as=viewer@example.com

# 8. Test resource constraints
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: demo
spec:
  containers:
    - name: nginx
      image: nginx:alpine
EOF

kubectl describe pod test-pod -n demo | grep -A 5 Limits

# 9. Test network policies
kubectl run -it --rm debug --image=busybox --restart=Never -n demo -- nslookup kubernetes.default
# Should succeed (DNS allowed)

kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n demo -- curl --max-time 5 https://example.com
# Should timeout (external egress denied)

# 10. Test quota enforcement
for i in {1..21}; do
  kubectl run test-$i --image=nginx:alpine -n demo
done
# Should fail after 20 pods (quota exceeded)
```

---

## ✅ Definition of Done

### Manifest Creation (This Story)
- [ ] All components created per AC1-AC10
- [ ] Kustomize validation passes (`kustomize build`)
- [ ] Flux validation passes (`flux build kustomization`)
- [ ] Template README comprehensive and accurate
- [ ] Demo tenant created and validated
- [ ] Onboarding runbook documented
- [ ] Git commit pushed to repository
- [ ] No deployment or cluster access performed

### Deployment and Validation (Story 45)
- [ ] Demo tenant namespace created
- [ ] RBAC roles and bindings functional
- [ ] Resource quotas enforced
- [ ] LimitRange applied to pods
- [ ] Network policies enforced (deny-all + allow DNS/kube-api)
- [ ] Sample workload respects constraints
- [ ] Onboarding runbook validated

---

## 📐 Design Notes

### Multi-Tenancy Model

**Namespace-Level Isolation**:

This template implements **soft multi-tenancy** using Kubernetes namespaces:

**Isolation Layers**:
1. **RBAC**: Namespace-scoped roles (no cluster-wide access)
2. **Quotas**: Resource limits prevent noisy neighbor issues
3. **NetworkPolicies**: Default-deny egress/ingress with allowlist
4. **Pod Security**: Enforced via PSA labels (baseline by default)

**Not Provided** (requires additional stories):
- Node isolation (use node selectors, taints/tolerations)
- Network segmentation (use Cilium network policies with FQDN)
- Pod-level isolation (use sandboxed runtimes like gVisor, Kata)

### RBAC Design

**Three Roles**:

1. **Developer**: Full CRUD access to namespace resources
   - Pods, deployments, services, configmaps, secrets
   - Logs, exec, port-forward (debugging)
   - **Cannot**: Modify RBAC, quotas, or network policies

2. **Viewer**: Read-only access (no secrets)
   - Get, list, watch most resources
   - **Cannot**: View secrets, create/update/delete resources

3. **CI/CD**: Deployment automation
   - Create/update deployments, services, configmaps
   - Run jobs, view logs
   - **Cannot**: Exec into pods, modify secrets directly

**Group Binding Pattern**:
- RoleBindings reference OIDC groups from Keycloak
- Groups: `${TEAM}-developers`, `${TEAM}-viewers`
- ServiceAccount for CI/CD: `cicd` in tenant namespace

### Resource Quota Strategy

**Default Quotas** (adjust per team):

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 4 cores | 8 cores |
| Memory | 8Gi | 16Gi |
| Pods | 20 | - |
| Services | 10 | - |
| PVCs | 5 | - |
| Storage | 50Gi | - |

**Quota Enforcement**:
- **Hard limits**: Prevent resource exhaustion
- **Noisy neighbor prevention**: One team cannot consume all cluster resources
- **Cost control**: Limit cloud provider costs (if using managed Kubernetes)

**LimitRange Defaults**:
- **Container default**: 100m CPU, 128Mi memory (applied if not specified)
- **Container max**: 2 cores, 4Gi memory (prevents single pod from consuming all quota)
- **PVC max**: 10Gi (prevents large persistent volumes)

### Network Policy Strategy

**Default-Deny Baseline**:

All traffic denied by default, with explicit allowlist:

1. **deny-all.yaml**: Deny all ingress and egress
2. **allow-dns.yaml**: Allow DNS to kube-system (UDP/TCP port 53)
3. **allow-kube-api.yaml**: Allow kube-apiserver (default/kubernetes service)
4. **allow-observability.yaml**: Allow metrics scraping from observability namespace

**Custom Egress Patterns** (add as needed):

- **External HTTPS**: Allow specific apps to reach external APIs
- **Database access**: Allow to CNPG pooler in cnpg-system namespace
- **Service mesh**: Allow to istio-system or linkerd namespace

**Why Default-Deny?**

- **Security**: Prevents lateral movement in cluster
- **Compliance**: Meets zero-trust network requirements
- **Visibility**: Forces teams to explicitly document network dependencies

### Template Parameterization

**Kustomize Replacements**:

The template uses Kustomize `replacements` to parameterize manifests:

```yaml
replacements:
  - source:
      kind: Namespace
      name: ${TEAM}
      fieldPath: metadata.name
    targets:
      - select:
          kind: Role
        fieldPaths:
          - metadata.namespace
```

**Why not Helm?**

- **Simpler**: No Helm charts to maintain
- **GitOps-native**: Kustomize is Flux's default
- **Composable**: Components can be mixed/matched per tenant
- **Transparent**: Easy to see final manifests with `kustomize build`

### Onboarding Workflow

**Process**:

1. Platform engineer copies template
2. Updates team name and contact info
3. Adjusts quotas/RBAC groups as needed
4. Creates Flux Kustomization
5. Commits to git
6. Flux reconciles and creates namespace

**Time to onboard**: <10 minutes (including validation)

### Quota Adjustment Guidelines

**When to increase quotas**:

- **CPU-intensive workloads**: Machine learning, video processing
- **Memory-intensive workloads**: Big data, in-memory caches
- **Many services**: Microservices architecture (>10 services)
- **Large datasets**: Persistent volumes >50Gi

**Example adjustments**:

```yaml
# High-performance team
requests.cpu: "16"
requests.memory: 32Gi
pods: "50"
persistentvolumeclaims: "10"
requests.storage: 200Gi
```

### Monitoring and Alerts (Future)

**Quota utilization alerts** (to be added in observability story):

- Alert when team uses >80% of CPU quota
- Alert when team uses >80% of memory quota
- Alert when team uses >90% of pod count quota

**NetworkPolicy alerts**:

- Alert on deny-all policy violations (dropped packets)
- Dashboard showing top egress destinations per namespace

---

## 📝 Change Log

### v3.0 - 2025-10-26
- Refined to manifests-first architecture pattern
- Separated manifest creation (Story 35) from deployment (Story 45)
- Created reusable components for namespace, RBAC, quota, networkpolicy
- Added tenant template with Kustomize replacements
- Created demo tenant example for validation
- Added three RBAC roles: developer, viewer, CI/CD
- Set resource quotas: 4 CPU / 8Gi memory (requests), 8 CPU / 16Gi (limits)
- Created LimitRange with container defaults and max limits
- Added NetworkPolicies: deny-all + allow DNS/kube-api/observability
- Documented tenant onboarding runbook with validation steps

### v2.0 - 2025-10-22
- Original implementation-focused story with deployment tasks

---

**Story Owner:** Platform Engineering
**Last Updated:** 2025-10-26
**Status:** v3.0 (Manifests-first)
