# EPIC-5: Security & Secrets
**Goal:** Deploy cert-manager and external-secrets
**Status:** ✅ 80% Complete (configs complete, deployment pending)

## Story 5.1: Deploy cert-manager (Both Clusters) ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] cert-manager base HelmRelease created
- [x] cert-manager infrastructure config created
- [x] ClusterIssuer manifests created
- [ ] cert-manager deployed to infra cluster
- [ ] cert-manager deployed to apps cluster (automatic)
- [ ] ClusterIssuer for Let's Encrypt created
- [ ] Test certificate issued successfully

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/cert-manager/helmrelease.yaml`
  - ✅ `kubernetes/infrastructure/security/cert-manager/kustomization.yaml`
  - ✅ `kubernetes/infrastructure/security/cert-manager/clusterissuer.yaml`

- **Deploy via Flux** (automatic to both clusters)

- **Verify on both clusters:**
  ```bash
  kubectl --context infra get pods -n cert-manager
  kubectl --context apps get pods -n cert-manager
  kubectl --context infra get clusterissuer
  ```

- **Test certificate issuance:**
  ```bash
  kubectl --context infra create -f - <<EOF
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: test-cert
  spec:
    secretName: test-cert-tls
    issuerRef:
      name: letsencrypt-staging
      kind: ClusterIssuer
    dnsNames:
      - test.monosense.io
  EOF

  kubectl --context infra get certificate test-cert
  kubectl --context infra delete certificate test-cert
  ```

**Files Created:**
- ✅ `kubernetes/bases/cert-manager/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/security/cert-manager/kustomization.yaml`
- ✅ `kubernetes/infrastructure/security/cert-manager/clusterissuer.yaml`

**Note:** Stories 5.3 (cert-manager on Apps) is automatic!

---

## Story 5.2: Deploy External Secrets Operator (Both Clusters) ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] External Secrets Operator base HelmRelease created
- [x] External Secrets infrastructure config created
- [x] ClusterSecretStore for 1Password configured
- [ ] Operator deployed to infra cluster
- [ ] Operator deployed to apps cluster (automatic)
- [ ] 1Password Connect accessible
- [ ] Test ExternalSecret syncs successfully

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/external-secrets/helmrelease.yaml`
  - ✅ `kubernetes/infrastructure/security/external-secrets/kustomization.yaml`
  - ✅ `kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml`

- **Deploy via Flux** (automatic)

- **Verify on both clusters:**
  ```bash
  kubectl --context infra get pods -n external-secrets
  kubectl --context apps get pods -n external-secrets
  kubectl --context infra get clustersecretstore onepassword
  ```

- **Test ExternalSecret:**
  ```bash
  kubectl --context infra create -f - <<EOF
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: test-secret
  spec:
    refreshInterval: 1m
    secretStoreRef:
      name: onepassword
      kind: ClusterSecretStore
    target:
      name: test-secret-data
    data:
      - secretKey: test
        remoteRef:
          key: test-item
          property: password
  EOF

  kubectl --context infra get externalsecret test-secret
  kubectl --context infra get secret test-secret-data
  kubectl --context infra delete externalsecret test-secret
  ```

**Files Created:**
- ✅ `kubernetes/bases/external-secrets/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/security/external-secrets/kustomization.yaml`
- ✅ `kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml`

**1Password Configuration:**
- Connect host: From `ONEPASSWORD_CONNECT_HOST` variable
- Token: From `ONEPASSWORD_CONNECT_TOKEN_SECRET` variable
- Vault: Production

**Note:** Stories 5.4 (External Secrets on Apps) is automatic!

---
