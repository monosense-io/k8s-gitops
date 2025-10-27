# 06 — STORY-SEC-CERT-MANAGER-ISSUERS — Create cert-manager Issuer Manifests

Sequence: 06/50 | Prev: STORY-SEC-EXTERNAL-SECRETS-BASE.md | Next: STORY-OPS-RELOADER-ALL-CLUSTERS.md
Sprint: 2 | Lane: Security
Global Sequence: 06/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §8; kubernetes/infrastructure/security/cert-manager/

---

## Story

As a platform engineer, I want to **create cert-manager ClusterIssuer and wildcard certificate manifests** with Let's Encrypt DNS-01 (Cloudflare) integration, so that when deployed in Story 45, clusters have automated TLS certificate issuance and renewal for Gateway and other HTTPS services.

This story creates the declarative cert-manager configuration manifests (ClusterIssuers, ExternalSecret, wildcard Certificate, PrometheusRule). Actual deployment and certificate validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create ClusterIssuer manifests for Let's Encrypt (staging and production)
- Configure Cloudflare DNS-01 challenge solver
- Create wildcard certificate manifests for `*.${SECRET_DOMAIN}`
- Enable automated TLS issuance and renewal
- Foundation for Gateway HTTPS and service TLS

## Scope

**This Story (Manifest Creation):**
- Create cert-manager configuration manifests in `kubernetes/infrastructure/security/cert-manager/`
- Create ClusterIssuer manifests (staging and production)
- Create ExternalSecret for Cloudflare API token
- Create wildcard Certificate manifest
- Create PrometheusRule for cert-manager monitoring
- Create Kustomization for cert-manager resources
- Update cluster-settings with Cloudflare variables (if needed)
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying cert-manager issuers to clusters
- Verifying ClusterIssuer Ready status
- Testing certificate issuance (staging, then production)
- Validating certificate renewal
- Testing wildcard certificate with Gateway HTTPS
---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **ClusterIssuer Manifests Created:**
   - `kubernetes/infrastructure/security/cert-manager/clusterissuers.yaml` exists
   - Staging ClusterIssuer: `letsencrypt-staging`
   - Production ClusterIssuer: `letsencrypt-production`
   - DNS-01 solver configured with Cloudflare
   - Email configured via `${LETSENCRYPT_EMAIL}`
   - Secret reference for Cloudflare API token

2. **ExternalSecret Manifest Created:**
   - `kubernetes/infrastructure/security/cert-manager/externalsecret-cloudflare.yaml` exists
   - References ClusterSecretStore `onepassword`
   - Fetches Cloudflare API token from `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}`
   - Target secret: `cloudflare-api-token` in `cert-manager` namespace

3. **Wildcard Certificate Manifest Created:**
   - `kubernetes/infrastructure/security/cert-manager/wildcard-certificate.yaml` exists
   - Certificate name: `wildcard-tls`
   - DNS names: `*.${SECRET_DOMAIN}` and `${SECRET_DOMAIN}`
   - Issuer reference: `letsencrypt-production`
   - Secret name: `wildcard-tls` in `kube-system` namespace

4. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/security/cert-manager/prometheusrule.yaml` exists
   - Alert rules defined: CertManagerAbsent, CertificateExpiringSoon, CertificateNotReady

5. **Kustomization Created:**
   - `kubernetes/infrastructure/security/cert-manager/ks.yaml` exists
   - References all cert-manager manifests
   - Includes dependency on external-secrets
   - `kubernetes/infrastructure/security/cert-manager/kustomization.yaml` glue file exists

6. **Cluster Settings Alignment:**
   - Cluster-settings include cert-manager variables:
     - `LETSENCRYPT_EMAIL` (e.g., `admin@monosense.io`)
     - `SECRET_DOMAIN` (e.g., `monosense.io`)
     - `CERTMANAGER_CLOUDFLARE_SECRET_PATH` (e.g., `kubernetes/infra/cert-manager/cloudflare`)

7. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct domain and email substitution
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ cert-manager controller/webhook running
- ❌ ClusterIssuer Ready=True
- ❌ ExternalSecret syncing Cloudflare token
- ❌ Wildcard certificate issued and Ready
- ❌ Certificate secret contains valid TLS cert
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Certificate renewal tested

---

## Dependencies

**Prerequisites (v3.0):**
- Story 43 (STORY-BOOT-CRDS) complete (cert-manager CRDs created)
- Story 44 (STORY-BOOT-CORE) complete (cert-manager operator bootstrapped)
- Story 05 (STORY-SEC-EXTERNAL-SECRETS-BASE) complete (External Secrets manifests created)
- Cluster-settings ConfigMaps with `LETSENCRYPT_EMAIL`, `SECRET_DOMAIN`, `CERTMANAGER_CLOUDFLARE_SECRET_PATH`
- Cloudflare API token stored in 1Password (referenced by path)
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ External Secrets deployed (deployment in Story 45)
- ❌ cert-manager deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 43 complete (cert-manager CRDs manifests created):
  ```bash
  grep -i "cert-manager" bootstrap/helmfile.d/00-crds.yaml.gotmpl
  ```

- [ ] Verify Story 44 complete (cert-manager operator bootstrapped):
  ```bash
  grep -i "cert-manager" bootstrap/helmfile.d/01-core.yaml.gotmpl
  ```

- [ ] Verify Story 05 complete (External Secrets manifests created):
  ```bash
  ls -la kubernetes/infrastructure/security/external-secrets/
  ```

- [ ] Verify cluster-settings have cert-manager variables:
  ```bash
  grep -E '(LETSENCRYPT_EMAIL|SECRET_DOMAIN|CERTMANAGER_CLOUDFLARE_SECRET_PATH)' kubernetes/clusters/infra/cluster-settings.yaml
  grep -E '(LETSENCRYPT_EMAIL|SECRET_DOMAIN|CERTMANAGER_CLOUDFLARE_SECRET_PATH)' kubernetes/clusters/apps/cluster-settings.yaml
  ```

---

### T2: Create cert-manager Issuer Manifests

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/security/cert-manager
  ```

- [ ] Create `clusterissuers.yaml`:
  ```yaml
  ---
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-staging
  spec:
    acme:
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      email: ${LETSENCRYPT_EMAIL}
      privateKeySecretRef:
        name: letsencrypt-staging
      solvers:
        - dns01:
            cloudflare:
              email: ${LETSENCRYPT_EMAIL}
              apiTokenSecretRef:
                name: cloudflare-api-token
                key: api-token
          selector:
            dnsZones:
              - ${SECRET_DOMAIN}
  ---
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-production
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: ${LETSENCRYPT_EMAIL}
      privateKeySecretRef:
        name: letsencrypt-production
      solvers:
        - dns01:
            cloudflare:
              email: ${LETSENCRYPT_EMAIL}
              apiTokenSecretRef:
                name: cloudflare-api-token
                key: api-token
          selector:
            dnsZones:
              - ${SECRET_DOMAIN}
  ```

- [ ] Create `externalsecret-cloudflare.yaml`:
  ```yaml
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: cloudflare-api-token
    namespace: cert-manager
  spec:
    refreshInterval: 1h
    secretStoreRef:
      name: onepassword
      kind: ClusterSecretStore
    target:
      name: cloudflare-api-token
      creationPolicy: Owner
    data:
      - secretKey: api-token
        remoteRef:
          key: ${CERTMANAGER_CLOUDFLARE_SECRET_PATH}
          property: credential
  ```

- [ ] Create `wildcard-certificate.yaml`:
  ```yaml
  ---
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: wildcard-tls
    namespace: kube-system
  spec:
    secretName: wildcard-tls
    issuerRef:
      name: letsencrypt-production
      kind: ClusterIssuer
    dnsNames:
      - "*.${SECRET_DOMAIN}"
      - "${SECRET_DOMAIN}"
    duration: 2160h  # 90 days
    renewBefore: 720h  # 30 days
  ```

- [ ] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: cert-manager
    namespace: cert-manager
  spec:
    groups:
      - name: cert-manager
        interval: 30s
        rules:
          - alert: CertManagerAbsent
            expr: absent(up{job="cert-manager"})
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "cert-manager metrics absent"
              description: "cert-manager has been absent for 5 minutes"

          - alert: CertificateExpiringSoon
            expr: certmanager_certificate_expiration_timestamp_seconds - time() < 604800
            for: 1h
            labels:
              severity: warning
            annotations:
              summary: "Certificate expiring soon"
              description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} expires in less than 7 days"

          - alert: CertificateNotReady
            expr: certmanager_certificate_ready_status{condition="False"} == 1
            for: 10m
            labels:
              severity: critical
            annotations:
              summary: "Certificate not ready"
              description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} is not ready"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - clusterissuers.yaml
    - externalsecret-cloudflare.yaml
    - wildcard-certificate.yaml
    - prometheusrule.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: cert-manager-issuers
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/security/cert-manager
    prune: true
    wait: true
    dependsOn:
      - name: external-secrets
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    healthChecks:
      - apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        name: letsencrypt-production
        namespace: ""
      - apiVersion: cert-manager.io/v1
        kind: Certificate
        name: wildcard-tls
        namespace: kube-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/security/cert-manager/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/security/cert-manager
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "ClusterIssuer" and .metadata.name == "letsencrypt-production") | .spec.acme.email'
  # Expected: admin@monosense.io (or actual email)

  # Apps cluster
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "Certificate") | .spec.dnsNames'
  # Expected: ["*.monosense.io", "monosense.io"] (or actual domain)
  ```

- [ ] Verify ExternalSecret path substitution:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "ExternalSecret" and .metadata.name == "cloudflare-api-token") | .spec.data[0].remoteRef.key'
  # Expected: kubernetes/infra/cert-manager/cloudflare
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/security/kustomization.yaml`:
  ```yaml
  resources:
    - external-secrets/ks.yaml
    - cert-manager/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have cert-manager variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  LETSENCRYPT_EMAIL: "admin@monosense.io"
  SECRET_DOMAIN: "monosense.io"
  CERTMANAGER_CLOUDFLARE_SECRET_PATH: "kubernetes/infra/cert-manager/cloudflare"
  ```

- [ ] Verify apps cluster-settings have cert-manager variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  LETSENCRYPT_EMAIL: "admin@monosense.io"
  SECRET_DOMAIN: "monosense.io"
  CERTMANAGER_CLOUDFLARE_SECRET_PATH: "kubernetes/apps/cert-manager/cloudflare"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMaps

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/security/cert-manager/
  git commit -m "feat(security): add cert-manager ClusterIssuer and wildcard certificate manifests

  - Create ClusterIssuers for Let's Encrypt (staging and production)
  - Configure Cloudflare DNS-01 challenge solver
  - Create ExternalSecret for Cloudflare API token
  - Create wildcard Certificate for *.${SECRET_DOMAIN}
  - Create PrometheusRule for cert-manager monitoring
  - Configure cluster-specific email and domain

  Part of Story 06 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy cert-manager issuers (Story 45 only)
flux reconcile kustomization cert-manager-issuers --with-source

# Verify ClusterIssuers
kubectl get clusterissuer
kubectl get clusterissuer letsencrypt-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify ExternalSecret synced
kubectl -n cert-manager get externalsecret cloudflare-api-token
kubectl -n cert-manager get secret cloudflare-api-token

# Test staging certificate first
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-staging-cert
  namespace: default
spec:
  secretName: test-staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.monosense.io
EOF

# Verify staging certificate issued
kubectl -n default get certificate test-staging-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Switch to production wildcard certificate
kubectl -n kube-system get certificate wildcard-tls
kubectl -n kube-system get certificate wildcard-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify certificate secret
kubectl -n kube-system get secret wildcard-tls
kubectl -n kube-system get secret wildcard-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A2 "Subject Alternative Name"
# Expected: DNS:*.monosense.io, DNS:monosense.io

# Test certificate renewal (manual trigger)
kubectl -n kube-system annotate certificate wildcard-tls cert-manager.io/issue-temporary-certificate="true" --overwrite

# Cleanup staging test
kubectl delete certificate -n default test-staging-cert
kubectl delete secret -n default test-staging-tls
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/security/cert-manager/`
- [ ] ClusterIssuer manifests created (staging and production)
- [ ] ExternalSecret manifest created for Cloudflare API token
- [ ] Wildcard Certificate manifest created
- [ ] PrometheusRule manifest created with alert rules
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Cluster-settings have cert-manager variables (email, domain, Cloudflare path)
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct email and domain substitution
  - [ ] ExternalSecret path substitution verified
- [ ] Infrastructure kustomization updated to include cert-manager
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ cert-manager controller/webhook running
- ❌ ClusterIssuer Ready=True
- ❌ ExternalSecret syncing Cloudflare token
- ❌ Wildcard certificate issued and Ready
- ❌ Certificate secret contains valid TLS cert
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Certificate renewal tested
- ❌ Gateway HTTPS integration tested

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Removed extensive dev notes and validation sections. | Platform Engineering |
| 2025-10-22 | 2.0     | Story validation updates | Platform Engineering |
