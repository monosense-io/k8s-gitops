# 12 — STORY-NET-CILIUM-CLUSTERMESH — Create Cilium ClusterMesh Manifests

Sequence: 12/50 | Prev: STORY-NET-SPEGEL-REGISTRY-MIRROR.md | Next: STORY-NET-CLUSTERMESH-DNS.md
Sprint: 6 | Lane: Networking
Global Sequence: 12/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §20; kubernetes/infrastructure/networking/cilium/clustermesh/

---

## Story

As a platform engineer, I want to **create Cilium ClusterMesh manifests** for cross-cluster connectivity, so that when deployed in Story 45, the infra and apps clusters can discover and communicate with services across cluster boundaries without sidecars or proxies.

This story creates the declarative ClusterMesh configuration manifests (ExternalSecret, cluster configuration). Actual deployment and cross-cluster connectivity validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create ClusterMesh manifests for GitOps deployment
- Enable cross-cluster service discovery and connectivity
- Support global service load balancing across clusters
- Foundation for multi-cluster applications (GitLab HA, shared databases)
- Native Cilium implementation without service mesh overhead

## Scope

**This Story (Manifest Creation):**
- Create ClusterMesh manifests in `kubernetes/infrastructure/networking/cilium/clustermesh/`
- Create ExternalSecret for ClusterMesh credentials
- Configure cluster-specific ClusterMesh settings
- Create Kustomization for ClusterMesh resources
- Update cluster-settings with ClusterMesh variables (if needed)
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying ClusterMesh configuration to clusters
- Verifying ClusterMesh Connected status
- Testing cross-cluster service discovery
- Validating cross-cluster pod connectivity
- Verifying global service load balancing

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **ExternalSecret Manifest Created:**
   - `kubernetes/infrastructure/networking/cilium/clustermesh/externalsecret.yaml` exists
   - Secret name: `cilium-clustermesh`
   - Namespace: `kube-system`
   - References 1Password path via `${CILIUM_CLUSTERMESH_SECRET_PATH}`
   - ClusterSecretStore: `onepassword`

2. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/cilium/clustermesh/ks.yaml` exists
   - References ClusterMesh manifests
   - Includes dependency on `cilium-core` and `external-secrets`
   - `kubernetes/infrastructure/networking/cilium/clustermesh/kustomization.yaml` glue file exists

3. **Cluster Settings Alignment:**
   - Cluster-settings include ClusterMesh variables:
     - `CILIUM_CLUSTERMESH_SECRET_PATH` (e.g., `kubernetes/infra/cilium-clustermesh`)
     - `CILIUM_CLUSTER_NAME` (e.g., `infra`, `apps`)
     - `CILIUM_CLUSTER_ID` (e.g., `1` for infra, `2` for apps)

4. **Cilium Core HelmRelease Updated:**
   - Cilium HelmRelease has ClusterMesh enabled:
     - `clustermesh.useAPIServer: true`
     - `clustermesh.config.enabled: true`
     - `cluster.name: ${CILIUM_CLUSTER_NAME}`
     - `cluster.id: ${CILIUM_CLUSTER_ID}`

5. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct cluster name and ID substitution for each cluster
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ ClusterMesh Connected status on both clusters
- ❌ Cross-cluster service discovery working
- ❌ Cross-cluster pod connectivity verified
- ❌ Global service endpoints visible
- ❌ ClusterMesh API server healthy

---

## Dependencies

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium core manifests with ClusterMesh enabled)
- Story 05 (STORY-SEC-EXTERNAL-SECRETS-BASE) complete (ClusterSecretStore configured)
- Cluster-settings ConfigMaps with `CILIUM_CLUSTERMESH_SECRET_PATH`, `CILIUM_CLUSTER_NAME`, `CILIUM_CLUSTER_ID`
- 1Password vault populated with ClusterMesh credentials
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ L3 connectivity between clusters (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests with ClusterMesh enabled):
  ```bash
  grep -i "clustermesh" kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  # Confirm: clustermesh.useAPIServer: true
  ```

- [ ] Verify Story 05 complete (ClusterSecretStore manifests created):
  ```bash
  ls -la kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml
  ```

- [ ] Verify cluster-settings have ClusterMesh variables:
  ```bash
  grep -E '(CILIUM_CLUSTERMESH_SECRET_PATH|CILIUM_CLUSTER_NAME|CILIUM_CLUSTER_ID)' kubernetes/clusters/infra/cluster-settings.yaml
  grep -E '(CILIUM_CLUSTERMESH_SECRET_PATH|CILIUM_CLUSTER_NAME|CILIUM_CLUSTER_ID)' kubernetes/clusters/apps/cluster-settings.yaml
  ```

---

### T2: Update Cilium Core HelmRelease (If Needed)

- [ ] Verify Cilium HelmRelease has ClusterMesh configuration:
  ```bash
  grep -A 10 "clustermesh:" kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  ```

- [ ] If ClusterMesh not configured, update HelmRelease:
  ```yaml
  # In kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml values section
  cluster:
    name: ${CILIUM_CLUSTER_NAME}
    id: ${CILIUM_CLUSTER_ID}

  clustermesh:
    useAPIServer: true
    apiserver:
      service:
        type: LoadBalancer
        annotations:
          io.cilium/lb-ipam-ips: ${CILIUM_CLUSTERMESH_LB_IP}
      replicas: 3
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 128Mi
    config:
      enabled: true
      domain: mesh.cilium.io
  ```

---

### T3: Create ClusterMesh Manifests

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/cilium/clustermesh
  ```

- [ ] Create `externalsecret.yaml`:
  ```yaml
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: cilium-clustermesh
    namespace: kube-system
  spec:
    secretStoreRef:
      name: onepassword
      kind: ClusterSecretStore
    target:
      name: cilium-clustermesh
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          config: "{{ .config | b64dec }}"
    dataFrom:
      - extract:
          key: ${CILIUM_CLUSTERMESH_SECRET_PATH}
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - externalsecret.yaml
  ```

---

### T4: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: cilium-clustermesh
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/cilium/clustermesh
    prune: true
    wait: true
    dependsOn:
      - name: cilium-core
      - name: external-secrets
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    healthChecks:
      - apiVersion: external-secrets.io/v1beta1
        kind: ExternalSecret
        name: cilium-clustermesh
        namespace: kube-system
  ```

---

### T5: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/clustermesh/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/clustermesh
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster (should substitute cluster name "infra", ID "1")
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "cilium") | .spec.values.cluster'

  # Apps cluster (should substitute cluster name "apps", ID "2")
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "cilium") | .spec.values.cluster'
  ```

- [ ] Verify ExternalSecret path substitution:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "ExternalSecret" and .metadata.name == "cilium-clustermesh") | .spec.dataFrom[0].extract.key'
  # Expected: kubernetes/infra/cilium-clustermesh
  ```

---

### T6: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/networking/cilium/kustomization.yaml`:
  ```yaml
  resources:
    - core/ks.yaml
    - ipam/ks.yaml
    - gateway/ks.yaml
    - bgp/ks.yaml
    - clustermesh/ks.yaml  # ADD THIS LINE
  ```

---

### T7: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have ClusterMesh variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  CILIUM_CLUSTER_NAME: "infra"
  CILIUM_CLUSTER_ID: "1"
  CILIUM_CLUSTERMESH_SECRET_PATH: "kubernetes/infra/cilium-clustermesh"
  CILIUM_CLUSTERMESH_LB_IP: "10.25.11.100"
  ```

- [ ] Verify apps cluster-settings have ClusterMesh variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  CILIUM_CLUSTER_NAME: "apps"
  CILIUM_CLUSTER_ID: "2"
  CILIUM_CLUSTERMESH_SECRET_PATH: "kubernetes/apps/cilium-clustermesh"
  CILIUM_CLUSTERMESH_LB_IP: "10.25.11.120"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMaps

---

### T8: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/clustermesh/
  git add kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml  # If updated
  git commit -m "feat(networking): add Cilium ClusterMesh manifests

  - Create ExternalSecret for ClusterMesh credentials from 1Password
  - Configure cluster-specific names and IDs (infra=1, apps=2)
  - Enable ClusterMesh API server with LoadBalancer service
  - Configure ClusterMesh domain mesh.cilium.io
  - Add dependency on cilium-core and external-secrets

  Part of Story 12 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy ClusterMesh (Story 45 only)
flux reconcile kustomization cilium-clustermesh --with-source

# Verify ExternalSecret synced
kubectl -n kube-system get externalsecret cilium-clustermesh
kubectl -n kube-system get externalsecret cilium-clustermesh -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify ClusterMesh secret created
kubectl -n kube-system get secret cilium-clustermesh
kubectl -n kube-system get secret cilium-clustermesh -o jsonpath='{.data.config}' | base64 -d | head -20

# Verify ClusterMesh API server running
kubectl -n kube-system get deploy clustermesh-apiserver
kubectl -n kube-system get pods -l app.kubernetes.io/name=clustermesh-apiserver

# Verify ClusterMesh LoadBalancer service
kubectl -n kube-system get svc clustermesh-apiserver -o wide
# Expected: LoadBalancer IP assigned from IPAM pool

# Check ClusterMesh status
cilium clustermesh status
# Expected output:
# ⚙️  ClusterMesh:                   Enabled
# ✅ Service:                        clustermesh-apiserver
# ✅ Deployment:                     clustermesh-apiserver
# ✅ Cluster Connections:
#    - apps: status=Connected, latency=<1ms

# On apps cluster, verify connection to infra
kubectl --context apps exec -n kube-system ds/cilium -- cilium clustermesh status
# Expected: Connected to infra cluster

# Test cross-cluster service discovery
# Deploy test service on infra cluster
kubectl --context infra apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: default
  annotations:
    service.cilium.io/global: "true"
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: test-echo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-echo
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-echo
  template:
    metadata:
      labels:
        app: test-echo
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo:latest
          args:
            - -text=infra-cluster
          ports:
            - containerPort: 5678
EOF

# Wait for deployment
kubectl --context infra -n default wait --for=condition=available deployment/test-echo --timeout=60s

# On apps cluster, verify service is discovered
kubectl --context apps run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -s test-service.default.svc.cluster.local
# Expected: "infra-cluster" response

# Verify global service endpoints
kubectl --context apps get endpoints test-service -n default -o yaml
# Expected: Endpoints include pods from both clusters

# Test bidirectional connectivity
# Deploy test service on apps cluster
kubectl --context apps apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-service-apps
  namespace: default
  annotations:
    service.cilium.io/global: "true"
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: test-echo-apps
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-echo-apps
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-echo-apps
  template:
    metadata:
      labels:
        app: test-echo-apps
      spec:
        containers:
          - name: echo
            image: hashicorp/http-echo:latest
            args:
              - -text=apps-cluster
            ports:
              - containerPort: 5678
EOF

# From infra cluster, access apps service
kubectl --context infra run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -s test-service-apps.default.svc.cluster.local
# Expected: "apps-cluster" response

# Verify ClusterMesh metrics
kubectl --context infra -n kube-system port-forward deploy/clustermesh-apiserver 9962:9962 &
sleep 2
curl -s http://localhost:9962/metrics | grep cilium_clustermesh
# Expected metrics:
# - cilium_clustermesh_connected_clusters
# - cilium_clustermesh_remote_cluster_ready

# Cleanup test resources
kubectl --context infra delete deployment test-echo -n default
kubectl --context infra delete service test-service -n default
kubectl --context apps delete deployment test-echo-apps -n default
kubectl --context apps delete service test-service-apps -n default

# Verify ClusterMesh configuration
cilium clustermesh status --verbose
# Shows detailed connection info, latencies, and cluster metadata
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/networking/cilium/clustermesh/`
- [ ] ExternalSecret manifest created for ClusterMesh credentials
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Cilium core HelmRelease updated with ClusterMesh configuration
- [ ] Cluster-settings have ClusterMesh variables (names, IDs, secret paths, LB IPs)
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct cluster name and ID substitution for both clusters
  - [ ] ExternalSecret path substitution verified
- [ ] Infrastructure kustomization updated to include ClusterMesh
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ ClusterMesh Connected status on both clusters
- ❌ Cross-cluster service discovery working
- ❌ Cross-cluster pod connectivity verified
- ❌ Global service endpoints visible
- ❌ ClusterMesh API server healthy
- ❌ Bidirectional connectivity tested
- ❌ ClusterMesh metrics available

---

## Design Notes

### ClusterMesh Architecture

Cilium ClusterMesh enables multi-cluster connectivity without service mesh overhead:
- **Native Cilium**: Uses Cilium's native capabilities for cross-cluster networking
- **Global Services**: Services annotated with `service.cilium.io/global: "true"` are discoverable across clusters
- **Pod-to-Pod**: Direct pod-to-pod connectivity across clusters via Cilium tunnels
- **API Server**: Each cluster runs a ClusterMesh API server that peers with other clusters

### Requirements

- **Non-overlapping PodCIDRs**: Each cluster must have unique PodCIDRs (infra: 10.42.0.0/16, apps: 10.43.0.0/16)
- **Non-overlapping ServiceCIDRs**: Each cluster must have unique ServiceCIDRs (infra: 10.43.0.0/16, apps: 10.44.0.0/16)
- **L3 Connectivity**: ClusterMesh API servers must be reachable across clusters (via LoadBalancer IPs)
- **Unique Cluster IDs**: Each cluster must have a unique ID (1-255)

### Security

ClusterMesh credentials are stored in 1Password and synchronized via External Secrets Operator:
- **mTLS**: ClusterMesh API servers use mutual TLS for authentication
- **Certificates**: Auto-generated certificates stored in clustermesh secret
- **Secret Rotation**: Supported via ExternalSecret refresh

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T8 focusing on local validation only. Added comprehensive cross-cluster connectivity testing in runtime validation section. Added design notes for ClusterMesh architecture and requirements. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
