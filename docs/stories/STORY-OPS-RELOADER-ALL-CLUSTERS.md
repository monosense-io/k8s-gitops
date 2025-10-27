# 07 — STORY-OPS-RELOADER-ALL-CLUSTERS — Create Stakater Reloader Manifests

Sequence: 07/50 | Prev: STORY-SEC-CERT-MANAGER-ISSUERS.md | Next: STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL.md
Sprint: 2 | Lane: Operations
Global Sequence: 07/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §23; kubernetes/workloads/platform/system/reloader/

---

## Story

As a platform engineer, I want to **create Stakater Reloader manifests** for automatic pod restarts on ConfigMap/Secret changes, so that when deployed in Story 45, clusters automatically roll pods when External Secrets rotates credentials, eliminating manual restarts and enabling fully automated credential rotation.

This story creates the declarative Reloader manifests (HelmRelease, OCIRepository, PodMonitor). Actual deployment and restart testing happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create Reloader manifests for GitOps deployment
- Enable automatic pod restarts on ConfigMap/Secret changes
- Support automated credential rotation (Cloudflare API tokens, etc.)
- Reduce operational toil and manual pod restarts
- Foundation for future secret rotation automation

## Scope

**This Story (Manifest Creation):**
- Create Reloader manifests in `kubernetes/workloads/platform/system/reloader/`
- Create HelmRelease for Stakater Reloader
- Create OCIRepository for Reloader Helm chart
- Create PodMonitor for observability
- Create Kustomization for Reloader resources
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying Reloader to clusters
- Verifying Reloader deployment running
- Testing automatic pod restarts on ConfigMap/Secret changes
- Validating PodMonitor metrics scraping

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/workloads/platform/system/reloader/app/helmrelease.yaml` exists
   - Reloader version: `2.2.3` (chart tag)
   - Namespace: `kube-system`
   - PodMonitor enabled
   - Security: read-only root filesystem

2. **OCIRepository Manifest Created:**
   - OCIRepository defined in same file as HelmRelease
   - References Stakater Reloader chart from `ghcr.io/stakater/charts/reloader`
   - Chart version: `2.2.3`

3. **Kustomization Created:**
   - `kubernetes/workloads/platform/system/reloader/ks.yaml` exists
   - References Reloader manifests
   - No dependencies (can deploy early)
   - `kubernetes/workloads/platform/system/reloader/app/kustomization.yaml` glue file exists

4. **Platform Kustomization Updated:**
   - `kubernetes/workloads/platform/system/kustomization.yaml` exists and includes `reloader`
   - `kubernetes/workloads/platform/kustomization.yaml` includes `system`

5. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-workloads --path ./kubernetes/workloads` succeeds
   - `flux build kustomization cluster-apps-workloads --path ./kubernetes/workloads` succeeds
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ Reloader deployment running in kube-system
- ❌ PodMonitor scraping metrics
- ❌ Automatic pod restart on ConfigMap change tested
- ❌ Automatic pod restart on Secret change tested

---

## Dependencies

**Prerequisites (v3.0):**
- Flux operational (Story 44 complete - Flux bootstrapped)
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ VictoriaMetrics deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Flux operational (Story 44 complete):
  ```bash
  ls -la bootstrap/helmfile.d/01-core.yaml.gotmpl
  grep -i "flux" bootstrap/helmfile.d/01-core.yaml.gotmpl
  ```

---

### T2: Create Reloader Manifests

- [ ] Create directory structure:
  ```bash
  mkdir -p kubernetes/workloads/platform/system/reloader/app
  ```

- [ ] Create `helmrelease.yaml`:
  ```yaml
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: OCIRepository
  metadata:
    name: reloader
    namespace: kube-system
  spec:
    interval: 15m
    layerSelector:
      mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
      operation: copy
    ref:
      tag: 2.2.3
    url: oci://ghcr.io/stakater/charts/reloader
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: reloader
    namespace: kube-system
  spec:
    chartRef:
      kind: OCIRepository
      name: reloader
      namespace: kube-system
    interval: 1h
    install:
      remediation:
        retries: 2
      createNamespace: true
    upgrade:
      remediation:
        retries: 2
        strategy: rollback
      cleanupOnFail: true
    rollback:
      recreate: true
      cleanupOnFail: true
    values:
      fullnameOverride: reloader
      reloader:
        readOnlyRootFileSystem: true
        podMonitor:
          enabled: true
          namespace: kube-system
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: reloader
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/platform/system/reloader/app
    prune: true
    wait: true
    sourceRef:
      kind: GitRepository
      name: flux-system
    targetNamespace: kube-system
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: reloader
        namespace: kube-system
  ```

---

### T4: Create Platform System Kustomization

- [ ] Create `kubernetes/workloads/platform/system/kustomization.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - reloader/ks.yaml
  ```

---

### T5: Update Platform Kustomization

- [ ] Update `kubernetes/workloads/platform/kustomization.yaml`:
  ```yaml
  resources:
    - observability
    - databases
    - cicd
    - mesh-demo
    - system  # ADD THIS LINE
  ```

---

### T6: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/workloads/platform/system/reloader/app/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/workloads/platform/system/reloader/app
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster
  flux build kustomization cluster-infra-workloads --path ./kubernetes/workloads | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "reloader")'

  # Apps cluster
  flux build kustomization cluster-apps-workloads --path ./kubernetes/workloads | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "reloader")'
  ```

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/workloads/platform/system/
  git commit -m "feat(ops): add Stakater Reloader manifests

  - Create HelmRelease for Stakater Reloader 2.2.3
  - Enable PodMonitor for observability
  - Configure read-only root filesystem security
  - Create platform/system kustomization structure

  Part of Story 07 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy Reloader (Story 45 only)
flux reconcile kustomization reloader --with-source

# Verify deployment
kubectl -n kube-system get deploy reloader
kubectl -n kube-system get pods -l app.kubernetes.io/name=reloader

# Verify PodMonitor
kubectl -n kube-system get podmonitor reloader

# Test automatic restart on ConfigMap change
kubectl create configmap test-config --from-literal=key=value -n default

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-reloader
  namespace: default
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-reloader
  template:
    metadata:
      labels:
        app: test-reloader
    spec:
      containers:
        - name: test
          image: nginx:alpine
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: test-config
EOF

# Wait for pod to start
kubectl -n default wait --for=condition=ready pod -l app=test-reloader --timeout=60s

# Get pod creation timestamp
BEFORE=$(kubectl -n default get pod -l app=test-reloader -o jsonpath='{.items[0].metadata.creationTimestamp}')

# Update ConfigMap
kubectl patch configmap test-config -n default --type merge -p '{"data":{"key":"newvalue"}}'

# Wait 60 seconds for Reloader to detect change and restart pod
sleep 60

# Verify pod was restarted (new creation timestamp)
AFTER=$(kubectl -n default get pod -l app=test-reloader -o jsonpath='{.items[0].metadata.creationTimestamp}')

if [ "$BEFORE" != "$AFTER" ]; then
  echo "SUCCESS: Pod restarted automatically (Before: $BEFORE, After: $AFTER)"
else
  echo "FAILED: Pod did not restart"
fi

# Cleanup
kubectl delete deployment test-reloader -n default
kubectl delete configmap test-config -n default
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/workloads/platform/system/reloader/app/`
- [ ] HelmRelease manifest created with:
  - [ ] Reloader version 2.2.3
  - [ ] PodMonitor enabled
  - [ ] Read-only root filesystem security
- [ ] OCIRepository manifest created
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with health checks
- [ ] Platform system kustomization created
- [ ] Platform kustomization updated to include system
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows Reloader resources for both clusters
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ Reloader deployment running in kube-system
- ❌ PodMonitor scraping metrics
- ❌ Automatic pod restart on ConfigMap change tested
- ❌ Automatic pod restart on Secret change tested
- ❌ Integration with External Secrets rotation tested

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Added comprehensive restart testing in runtime validation. | Platform Engineering |
| 2025-10-22 | 1.0     | Initial draft | Platform Engineering |
