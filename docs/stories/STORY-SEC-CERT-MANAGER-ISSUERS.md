# STORY-SEC-CERT-MANAGER-ISSUERS — Issuers and Wildcard Certificates

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §8; kubernetes/infrastructure/security/cert-manager; kubernetes/infrastructure/security/cert-manager/ks.yaml

## Story
Deploy cert-manager via Flux and configure ClusterIssuers (e.g., Let’s Encrypt DNS‑01 with Cloudflare) and a wildcard certificate per cluster.

## Why / Outcome
- Automated TLS issuance and renewal; TLS for Gateway.

## Scope
- Resources: `bases/cert-manager` HelmRelease, `clusterissuers.yaml`, `externalsecret-cloudflare.yaml`, `wildcard-certificate.yaml`.

## Acceptance Criteria
1) cert-manager controller/webhook Available on infra/apps.
2) ClusterIssuer Ready; wildcard Certificate Ready with a valid Secret.
3) Metrics rules present and healthy.

## Dependencies / Inputs
- STORY-SEC-EXTERNAL-SECRETS-BASE; Cloudflare API token in 1Password at `${CERTMANAGER_CLOUDFLARE_SECRET_PATH}`.

## Tasks / Subtasks
- [ ] Reconcile `cert-manager` Kustomization; verify issuers and wildcard certs.
- [ ] Attach to Gateway story for HTTPS validation.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cert-manager --with-source
- kubectl --context=<ctx> -n cert-manager get deploy
- kubectl --context=<ctx> -n cert-manager get certificate -A

## Definition of Done
- ACs met on both clusters; evidence in Dev Notes.

