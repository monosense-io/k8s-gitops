# 05 — STORY-SEC-EXTERNAL-SECRETS-BASE — External Secrets Operator Base

Sequence: 05/26 | Prev: STORY-NET-CILIUM-CORE-GITOPS.md | Next: STORY-SEC-CERT-MANAGER-ISSUERS.md
Sprint: 1 | Lane: Bootstrap & Platform
Global Sequence: 5/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §8; kubernetes/infrastructure/security/external-secrets; kubernetes/infrastructure/security/external-secrets/ks.yaml

## Story
Deploy External Secrets operator via Flux and configure a ClusterSecretStore (1Password Connect) for both clusters.

## Why / Outcome
- Zero plaintext secrets in Git; unified secret sourcing.

## Scope
- Resources: `bases/external-secrets` HelmRelease, `clustersecretstore.yaml`, monitoring rules.

## Acceptance Criteria
1) External Secrets controller and webhook Deployments Available on infra/apps.
2) ClusterSecretStore Ready; a smoke ExternalSecret materializes a test Secret.
3) ServiceMonitor present and producing metrics.

## Dependencies / Inputs
- STORY-BOOT-CRDS; `ONEPASSWORD_CONNECT_*` settings in cluster-settings; bootstrap secret `onepassword-connect-token` exists.

## Tasks / Subtasks
- [ ] Reconcile `external-secrets` Kustomization.
- [ ] Create smoke ExternalSecret under `kubernetes/components/externalsecret/` (optional).

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks external-secrets --with-source
- kubectl --context=<ctx> -n external-secrets get deploy
- kubectl --context=<ctx> -n default get secret smoke-secret (if created)

## Definition of Done
- ACs met on both clusters with evidence.
