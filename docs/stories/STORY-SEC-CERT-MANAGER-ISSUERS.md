# 06 — STORY-SEC-CERT-MANAGER-ISSUERS — Issuers and Wildcard Certificates

Sequence: 06/41 | Prev: STORY-DNS-COREDNS-BASE.md | Next: STORY-SEC-EXTERNAL-SECRETS-BASE.md
Sprint: 2 | Lane: Security
Global Sequence: 6/41

Status: Ready for Implementation
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §8; kubernetes/infrastructure/security/cert-manager; kubernetes/infrastructure/security/cert-manager/ks.yaml

## Story
As a platform engineer,
I want to deploy cert-manager via Flux and configure ClusterIssuers (Let's Encrypt DNS-01 with Cloudflare) and a wildcard certificate per cluster,
so that we have automated TLS issuance and renewal for all services with secure HTTPS communication.

## Why / Outcome
- Automated TLS issuance and renewal; TLS for Gateway.

## Scope
- Resources: `bases/cert-manager` HelmRelease, `clusterissuers.yaml`, `externalsecret-cloudflare.yaml`, `wildcard-certificate.yaml`.
## Acceptance Criteria
1) cert-manager controller/webhook Available on infra/apps.
2) ClusterIssuer Ready; wildcard Certificate Ready with a valid Secret.
3) Metrics rules present and healthy.

## Dependencies / Inputs
- STORY-SEC-EXTERNAL-SECRETS-BASE (must be completed first)
- Cloudflare API token stored in 1Password at `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}`
- External Secrets operator must be deployed and functional
- cert-manager CRDs bootstrapped via Helmfile (Phase 0)

## Tasks / Subtasks

- [ ] Task 1: Verify existing cert-manager configuration (AC: 1, 2)
  - [ ] Review `kubernetes/infrastructure/security/cert-manager/clusterissuers.yaml`
    - Verify both staging and prod ClusterIssuers are configured
    - Confirm DNS01 solver with Cloudflare is properly set
    - Check `${SECRET_DOMAIN}` variable usage
  - [ ] Review `kubernetes/infrastructure/security/cert-manager/externalsecret-cloudflare.yaml`
    - Verify it references `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}`
    - Confirm Cloudflare API token template is correct
  - [ ] Review `kubernetes/infrastructure/security/cert-manager/wildcard-certificate.yaml`
    - Check wildcard Certificate for `*.${SECRET_DOMAIN}`
    - Note: Currently using staging issuer, will switch to prod in Task 3
    - Verify secret name and duration settings

- [ ] Task 2: Verify cert-manager integration in infrastructure (AC: 1)
  - [ ] Check `kubernetes/infrastructure/security/kustomization.yaml`
    - Confirm cert-manager/ks.yaml is included
    - Verify cert-manager resources are included
  - [ ] Verify Flux Kustomization `kubernetes/infrastructure/security/cert-manager/ks.yaml`
    - Check dependencies on external-secrets and cilium
    - Confirm health checks for cert-manager components
    - Verify postBuild substitution from cluster-settings
  - [ ] Confirm deployment to both clusters
    - cert-manager security is deployed via infrastructure Kustomizations
    - Same configuration applies to both infra and apps clusters

- [ ] Task 3: Deploy and validate cert-manager on infra cluster (AC: 1, 2, 3)
  - [ ] Apply changes to infra cluster
    - Verify cert-manager controller and webhook are Available
    - Check ExternalSecret syncs Cloudflare token from 1Password
    - Verify ClusterIssuer reaches Ready status
  - [ ] Test staging certificate issuance
    - Apply wildcard-certificate.yaml with staging issuer
    - Verify certificate is issued and Ready
    - Check certificate secret contains valid staging TLS certificate
  - [ ] Switch to production certificate
    - Update wildcard-certificate.yaml to use letsencrypt-prod issuer
    - Apply and verify production certificate is issued
    - Confirm certificate is trusted by browsers

- [ ] Task 4: Deploy and validate cert-manager on apps cluster (AC: 1, 2, 3)
  - [ ] Apply changes to apps cluster
    - Verify cert-manager controller and webhook are Available
    - Check ExternalSecret syncs Cloudflare token from 1Password
    - Verify ClusterIssuer reaches Ready status (shared with infra)
  - [ ] Validate wildcard certificate on apps cluster
    - Apply production wildcard-certificate.yaml
    - Verify certificate is issued and Ready
    - Confirm certificate can be used by services in apps cluster
  - [ ] Verify PrometheusRules are monitoring cert-manager health
    - Check `kubernetes/infrastructure/security/cert-manager/prometheusrule.yaml`
    - Confirm metrics are being collected

- [ ] Task 5: Update documentation and prepare for Gateway integration (AC: 3)
  - [ ] Update `docs/architecture.md` security section with certificate management details
  - [ ] Document Cloudflare DNS01 challenge process in the architecture
  - [ ] Add troubleshooting steps for common certificate issues
  - [ ] Document certificate renewal and rotation process
  - [ ] Note integration points for Gateway HTTPS configuration
  - [ ] Attach to Gateway story for HTTPS validation (as noted in original task)

## Validation Steps
```bash
# Reconcile cert-manager security Kustomization
flux -n flux-system --context=infra reconcile ks cert-manager --with-source
flux -n flux-system --context=apps reconcile ks cert-manager --with-source

# Check cert-manager deployments
kubectl --context=infra -n cert-manager get deploy
kubectl --context=apps -n cert-manager get deploy

# Verify ClusterIssuers
kubectl --context=infra get clusterissuer
kubectl --context=apps get clusterissuer

# Check certificates
kubectl --context=infra -n kube-system get certificate wildcard-domain
kubectl --context=apps -n kube-system get certificate wildcard-domain

# Check certificate secret
kubectl --context=infra -n kube-system get secret wildcard-tls -o yaml
kubectl --context=apps -n kube-system get secret wildcard-tls -o yaml

# Verify ExternalSecret
kubectl --context=infra -n cert-manager get externalsecret cloudflare-api-token
kubectl --context=apps -n cert-manager get externalsecret cloudflare-api-token
```

## Dev Notes

### Testing
- Unit tests: Not applicable (infrastructure configuration)
- Integration tests: Validate cert-manager deployment and certificate issuance
- End-to-end tests: Verify wildcard certificate works with actual services
- Security validation: Test certificate renewal and expiration handling

### Key Discovery: Files Already Exist
**Important**: All cert-manager security configuration files already exist and are properly configured:
- Location: `kubernetes/infrastructure/security/cert-manager/`
- Already integrated into Flux via `kubernetes/infrastructure/security/kustomization.yaml`
- This story focuses on validation, testing, and switching to production certificates

### Bootstrap vs Flux Management Pattern
- cert-manager is bootstrapped via Helmfile during cluster initialization (bootstrap/helmfile.d/01-core.yaml.gotmpl)
- After bootstrap, cert-manager is managed by Flux for day-2 operations
- This story focuses on the Flux-managed components (issuers and certificates)
- Bootstrap sequence: Cilium → CoreDNS → Spegel → cert-manager → Flux-operator → Flux-instance

### ClusterIssuer Configuration Pattern
- Single ClusterIssuer can be shared across both clusters
- Both staging and prod ClusterIssuers configured
- Cloudflare DNS01 solver with API token from 1Password
- ExternalSecret references existing ClusterSecretStore (onepassword)
- Uses `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}` from cluster-settings:
  - Infra: `kubernetes/infra/cert-manager/cloudflare`
  - Apps: `kubernetes/apps/cert-manager/cloudflare`
- Domain configuration uses `${SECRET_DOMAIN}` from cluster-settings (`monosense.io`)

### Flux Kustomization Structure
- cert-manager controller: Managed via bootstrap, day-2 config via Flux
- cert-manager security: Infrastructure Kustomization for issuers and certificates
- Location: `kubernetes/infrastructure/security/cert-manager/`
- Added to cluster infrastructure.yaml files
- Dependency: cert-manager security dependsOn external-secrets

### File Structure (based on project architecture)
```
kubernetes/
├── infrastructure/security/cert-manager/
│   ├── clusterissuers.yaml        # ✅ ClusterIssuer configuration (staging + prod)
│   ├── externalsecret-cloudflare.yaml  # ✅ Cloudflare API token ExternalSecret
│   ├── wildcard-certificate.yaml  # ✅ Wildcard certificate (currently staging)
│   ├── prometheusrule.yaml        # ✅ Monitoring rules
│   ├── ks.yaml                   # ✅ Flux Kustomization
│   └── kustomization.yaml        # ✅ Kustomize config
├── infrastructure/security/
│   └── kustomization.yaml        # ✅ Includes cert-manager/ks.yaml
├── clusters/infra/
│   └── infrastructure.yaml       # ✅ Includes security (deploys cert-manager)
└── clusters/apps/
    └── infrastructure.yaml       # ✅ Includes security (deploys cert-manager)
```

### Current Implementation Status
- ✅ **All cert-manager security files exist and are properly configured**
- ✅ **Flux Kustomization already integrated into infrastructure**
- ✅ **ClusterIssuers configured for both staging and production**
- ✅ **ExternalSecret configured for Cloudflare API token**
- ✅ **Wildcard certificate configured (currently using staging)**
- ⚠️ **Need to validate deployment and switch to production**

### Integration Points
- External Secrets: Uses existing 1Password Connect integration
- Cluster Settings: Uses `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}` and `${SECRET_DOMAIN}`
- Prometheus: cert-manager metrics configured via existing prometheusrule.yaml
- Gateway: Wildcard certificates will be used by Gateway HTTPS configuration
- Bootstrap: cert-manager CRDs installed in Phase 0, controller in Phase 1

## Definition of Done
- ACs met on both clusters; evidence in Dev Notes.
- ClusterIssuers Ready on both infra and apps clusters
- Wildcard certificate switched from staging to production and valid
- ExternalSecrets successfully syncing Cloudflare tokens from 1Password
- Flux Kustomizations validated (already integrated)
- Documentation updated with certificate management details
- Gateway integration noted for future HTTPS configuration

## Dev Agent Record

### Agent Model Used
- Model: Claude Sonnet 3.5 (for validation)
- Validation Date: 2025-10-22

### Debug Log References
- Validation commands: flux reconcile, kubectl get deployments
- Certificate validation: kubectl get certificate, kubectl get secret
- ExternalSecret validation: kubectl get externalsecret

### Completion Notes List
- Story validated with 9/10 readiness score
- All technical context verified against architecture documents
- Template compliance issues identified and resolved
- Implementation ready with comprehensive task breakdown

### File List
- STORY-SEC-CERT-MANAGER-ISSUERS.md (validated and updated)

## Change Log

### 2025-10-22 - Story Validation Updates
- Updated Story section to standard "As a/I want/so that" format
- Added Testing subsection under Dev Notes
- Added Change Log section
- Added Dev Agent Record section
- Clarified Dependencies section
- Story ready for implementation with 9/10 readiness score

