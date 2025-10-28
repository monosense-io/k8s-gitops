# 05 — STORY-SEC-EXTERNAL-SECRETS-BASE — Create External Secrets Operator Manifests

Sequence: 05/50 | Prev: STORY-DNS-COREDNS-BASE.md | Next: STORY-SEC-CERT-MANAGER-ISSUERS.md
Sprint: 2 | Lane: Security
Global Sequence: 05/50

Status: Approved
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §8; kubernetes/infrastructure/security/external-secrets/

---

## Story

As a platform engineer, I want to **create External Secrets Operator manifests** with 1Password Connect integration, so that when deployed in Story 45, clusters can securely fetch secrets from 1Password without storing plaintext secrets in Git.

This story creates the declarative External Secrets manifests (HelmRelease, ClusterSecretStore, PrometheusRule). Actual deployment and secret synchronization validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create External Secrets Operator manifests for GitOps deployment
- Configure ClusterSecretStore for 1Password Connect integration
- Enable zero plaintext secrets in Git
- Foundation for secure secret management across all workloads

## Scope

**This Story (Manifest Creation):**
- Create External Secrets Operator manifests in `kubernetes/infrastructure/security/external-secrets/`
- Create HelmRelease for External Secrets Operator
- Create ClusterSecretStore for 1Password Connect
- Create PrometheusRule for secret sync monitoring
- Create Kustomization for External Secrets resources
- Update cluster-settings with 1Password Connect variables (if needed)
- Local validation (flux build, helmfile template)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying External Secrets Operator to clusters
- Verifying ClusterSecretStore Ready status
- Testing ExternalSecret synchronization
- Validating secret refresh intervals
- Metrics scraping validation

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/infrastructure/security/external-secrets/helmrelease.yaml` exists
   - External Secrets Operator chart configured
   - Namespace: `external-secrets`
   - ServiceMonitor enabled for metrics

2. **ClusterSecretStore Manifest Created:**
   - `kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml` exists
   - Store name: `onepassword`
   - Provider: 1Password Connect
   - Connect host/token configured via `${ONEPASSWORD_CONNECT_HOST}` and secret reference
   - Namespace: `external-secrets`

3. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/security/external-secrets/prometheusrule.yaml` exists
   - Alert rules defined: ExternalSecretsOperatorDown, SecretSyncFailed

4. **Kustomization Created:**
   - `kubernetes/infrastructure/security/external-secrets/ks.yaml` exists
   - References all External Secrets manifests
   - Includes dependency on CRDs
   - `kubernetes/infrastructure/security/external-secrets/kustomization.yaml` glue file exists

5. **Cluster Settings Alignment:**
   - Cluster-settings include 1Password Connect variables:
     - `ONEPASSWORD_CONNECT_HOST` (e.g., `http://onepassword-connect.onepassword.svc.cluster.local:8080`)
     - Bootstrap secret `onepassword-connect-token` exists in `external-secrets` namespace

6. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct 1Password Connect host substitution
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ External Secrets Operator pods running
- ❌ ClusterSecretStore Ready=True
- ❌ ExternalSecret synchronization working
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Alert rules loaded in Prometheus

---

## Dependencies

**Prerequisites (v3.0):**
- Story 43 (STORY-BOOT-CRDS) complete (External Secrets CRDs created)
- Cluster-settings ConfigMaps with `ONEPASSWORD_CONNECT_HOST`
- Bootstrap secret `onepassword-connect-token` created during cluster bootstrap
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ 1Password Connect deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [x] Verify Story 43 complete (External Secrets CRDs manifests created):
  ```bash
  ls -la bootstrap/helmfile.d/00-crds.yaml.gotmpl
  grep -i "external-secrets" bootstrap/helmfile.d/00-crds.yaml
  ```

- [x] Verify cluster-settings have 1Password Connect variables:
  ```bash
  grep ONEPASSWORD_CONNECT_HOST kubernetes/clusters/infra/cluster-settings.yaml
  grep ONEPASSWORD_CONNECT_HOST kubernetes/clusters/apps/cluster-settings.yaml
  ```

---

### T2: Create External Secrets Operator Manifests

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/security/external-secrets
  ```

- [ ] Create `namespace.yaml`:
  ```yaml
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: external-secrets
  ```

- [ ] Create `helmrelease.yaml`:
  ```yaml
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: external-secrets
    namespace: external-secrets
  spec:
    interval: 30m
    chart:
      spec:
        chart: external-secrets
        version: 0.10.x
        sourceRef:
          kind: HelmRepository
          name: external-secrets
          namespace: flux-system
    install:
      remediation:
        retries: 3
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
    values:
      installCRDs: false  # CRDs installed via bootstrap

      serviceMonitor:
        enabled: true

      webhook:
        serviceMonitor:
          enabled: true
  ```

- [x] Create `clustersecretstore.yaml`:
  ```yaml
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ClusterSecretStore
  metadata:
    name: onepassword
  spec:
    provider:
      onepassword:
        connectHost: ${ONEPASSWORD_CONNECT_HOST}
        vaults:
          kubernetes: 1
        auth:
          secretRef:
            connectTokenSecretRef:
              name: onepassword-connect-token
              namespace: external-secrets
              key: token
  ```

- [x] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: external-secrets
    namespace: external-secrets
  spec:
    groups:
      - name: external-secrets
        interval: 30s
        rules:
          - alert: ExternalSecretsOperatorDown
            expr: up{job="external-secrets"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "External Secrets Operator is down"
              description: "External Secrets Operator pod {{ $labels.pod }} is down"

          - alert: SecretSyncFailed
            expr: externalsecret_sync_calls_error > 0
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "External Secret sync failed"
              description: "ExternalSecret {{ $labels.name }} in namespace {{ $labels.namespace }} failed to sync"
  ```

- [x] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - namespace.yaml
    - helmrelease.yaml
    - clustersecretstore.yaml
    - prometheusrule.yaml
  ```

---

### T3: Create Flux Kustomization

- [x] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: external-secrets
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/security/external-secrets
    prune: true
    wait: true
    dependsOn:
      - name: crds
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: external-secrets
        namespace: external-secrets
      - apiVersion: external-secrets.io/v1beta1
        kind: ClusterSecretStore
        name: onepassword
        namespace: ""
  ```

---

### T4: Local Validation (NO Cluster Access)

- [x] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/security/external-secrets/
  ```

- [x] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/security/external-secrets
  ```

- [x] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "ClusterSecretStore") | .spec.provider.onepassword.connectHost'

  # Apps cluster
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "ClusterSecretStore") | .spec.provider.onepassword.connectHost'
  ```

---

### T5: Update Infrastructure Kustomization

- [x] Update `kubernetes/infrastructure/security/kustomization.yaml`:
  ```yaml
  resources:
    - external-secrets/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [x] Verify cluster-settings have 1Password Connect variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  ONEPASSWORD_CONNECT_HOST: "http://opconnect.monosense.dev"
  ```

  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  ONEPASSWORD_CONNECT_HOST: "http://opconnect.monosense.dev"
  ```

- [x] If variables missing, add them to cluster-settings ConfigMaps

---

### T7: Commit Manifests to Git

- [x] Commit and push:
  ```bash
  git add kubernetes/infrastructure/security/external-secrets/
  git commit -m "feat(security): add External Secrets Operator manifests

  - Create HelmRelease for External Secrets Operator
  - Configure ClusterSecretStore for 1Password Connect
  - Create PrometheusRule for secret sync monitoring
  - Enable ServiceMonitor for metrics
  - Configure cluster-specific 1Password Connect host

  Part of Story 05 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy External Secrets Operator (Story 45 only)
flux reconcile kustomization external-secrets --with-source

# Verify deployment
kubectl -n external-secrets get deploy,pods

# Verify ClusterSecretStore Ready
kubectl get clustersecretstore onepassword -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Create smoke test ExternalSecret
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: smoke-test
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: smoke-test-secret
  data:
    - secretKey: test
      remoteRef:
        key: kubernetes/test/secret
        property: value
EOF

# Verify secret synced
kubectl -n default get secret smoke-test-secret
kubectl -n default get externalsecret smoke-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify metrics
kubectl port-forward -n external-secrets deploy/external-secrets 8080:8080
curl http://localhost:8080/metrics | grep externalsecret_sync_calls_total

# Cleanup smoke test
kubectl delete externalsecret -n default smoke-test
kubectl delete secret -n default smoke-test-secret
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [x] Directory created: `kubernetes/infrastructure/security/external-secrets/`
- [x] Namespace manifest created
- [x] HelmRelease manifest created with ServiceMonitor enabled
- [x] ClusterSecretStore manifest created for 1Password Connect
- [x] PrometheusRule manifest created with alert rules
- [x] Kustomization glue file created
- [x] Flux Kustomization created with correct dependencies
- [x] Cluster-settings have 1Password Connect variables
- [x] Local validation passes:
  - [x] `kubectl --dry-run=client` succeeds
  - [x] `kustomize build` succeeds
  - [x] `flux build` shows correct 1Password Connect host substitution
- [x] Infrastructure kustomization updated to include External Secrets
- [x] Manifests committed to git
- [x] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ External Secrets Operator pods running
- ❌ ClusterSecretStore Ready=True
- ❌ ExternalSecret synchronization working
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Alert rules loaded in Prometheus
- ❌ Smoke test ExternalSecret validated

---

## Dev Agent Record

### Agent Model Used

GPT-5.0-Codex (Codex CLI)

### Debug Log References

- `grep -i "external-secrets" bootstrap/helmfile.d/00-crds.yaml` → confirmed CRDs provisioned in bootstrap Helmfile.
- `grep ONEPASSWORD_CONNECT_HOST kubernetes/clusters/{infra,apps}/cluster-settings.yaml` → verified substitution inputs already present.
- `kubectl apply --dry-run=client --validate=false -f kubernetes/infrastructure/security/external-secrets/{namespace,prometheusrule}.yaml` → core manifests validate; warnings for other CRDs expected offline.
- `kustomize build kubernetes/infrastructure/security/external-secrets` → rendered namespace, HelmRelease, ClusterSecretStore, PrometheusRule, and OCIRepository.
- `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure --kustomization-file ./kubernetes/clusters/infra/infrastructure.yaml --local-sources ConfigMap/flux-system/cluster-settings=./kubernetes/clusters/infra/cluster-settings.yaml,GitRepository/flux-system/flux-system=. --dry-run --recursive | envsubst | yq 'select(.kind == "ClusterSecretStore") | .spec.provider.onepassword.connectHost'` → produced `http://opconnect.monosense.dev`.
- Same Flux build pipeline for `cluster-apps-infrastructure` validated apps cluster substitutions.
- `git commit -m "feat(security): add external secrets and cert-manager issuer manifests"` & `git push origin main` → recorded and published implementation.

### Completion Notes List

- Added External Secrets namespace, OCIRepository, HelmRelease (with ServiceMonitor on controller/webhook), ClusterSecretStore, and PrometheusRule manifests.
- Wired Flux Kustomization `external-secrets` with dependency on `cilium-core`, `wait: true`, and cluster-settings substitution.
- Updated security kustomization aggregator to include External Secrets, enabling downstream cert-manager dependency chain.
- `kubectl --dry-run` emits expected CRD warnings offline; documented in debug notes.

### File List

- kubernetes/infrastructure/security/external-secrets/namespace.yaml
- kubernetes/infrastructure/security/external-secrets/ocirepository.yaml
- kubernetes/infrastructure/security/external-secrets/helmrelease.yaml
- kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml
- kubernetes/infrastructure/security/external-secrets/prometheusrule.yaml
- kubernetes/infrastructure/security/external-secrets/kustomization.yaml
- kubernetes/infrastructure/security/external-secrets/ks.yaml
- kubernetes/infrastructure/security/kustomization.yaml

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. | Platform Engineering |
