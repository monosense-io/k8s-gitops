# Risk Profile: Story 06 — STORY-SEC-CERT-MANAGER-ISSUERS — Create cert-manager Issuer Manifests

Date: 2025-10-28
Reviewer: Quinn (Test Architect)
Story File: docs/stories/STORY-SEC-CERT-MANAGER-ISSUERS.md

## risk_summary (paste into gate file)

```yaml
risk_summary:
  totals:
    critical: 0
    high: 3
    medium: 4
    low: 3
  highest:
    id: SEC-001
    score: 6
    title: 'Over-privileged Cloudflare API token (DNS zone write)'
  recommendations:
    must_fix:
      - 'Scope Cloudflare token to DNS zone with minimum privileges; verify secret key mapping (api-token)' 
      - 'Validate Flux dependsOn target exists (external-secrets) and matches name used elsewhere'
      - 'Confirm cluster-settings keys present in both clusters (LETSENCRYPT_EMAIL, SECRET_DOMAIN, CERTMANAGER_CLOUDFLARE_SECRET_PATH)'
      - 'Ensure required CRDs exist before applying PrometheusRule and cert-manager resources'
    monitor:
      - 'Watch for noisy CertificateNotReady alerts during initial rollout'
      - 'Verify healthChecks timeouts don’t block reconciliation when controllers are absent/deferred'
```

## Executive Summary

- Total Risks Identified: 10
- Critical Risks: 0
- High Risks: 3
- Risk Score: 36/100 (aggregate severity heuristic)

Context: This story adds manifests only (issuers, ExternalSecret, wildcard Certificate, PrometheusRule, Kustomization). Deployment is deferred to Story 45. Primary risks are secret scope, Flux wiring/ordering, and CRD availability.

## Critical Risks Requiring Immediate Attention

None. Highest risks are High (score 6) and can be mitigated in design/config before deployment.

## Risk Matrix

| Risk ID  | Description                                                                                   | Prob | Impact | Score | Priority |
|--------- |----------------------------------------------------------------------------------------------- |-----:|------:|------:|---------:|
| SEC-001  | Over‑privileged Cloudflare API token (zone‑wide write; wildcard issuance blast radius)         | 2    | 3      | 6     | High     |
| TECH-001 | Flux dependsOn name mismatch or missing `external-secrets` Kustomization causing deadlock      | 2    | 3      | 6     | High     |
| OPS-001  | Misconfigured `SECRET_DOMAIN` leading to wrong DNS zone selection or issuance failure          | 2    | 3      | 6     | High     |
| SEC-002  | ExternalSecret `remoteRef.property` mismatch; secret key not materialized as `api-token`       | 2    | 2      | 4     | Medium   |
| TECH-002 | PrometheusRule CRD missing on target cluster(s)                                                | 2    | 2      | 4     | Medium   |
| TECH-003 | HealthChecks (ClusterIssuer/Certificate) time out when controllers are not yet installed       | 2    | 2      | 4     | Medium   |
| OPS-003  | Namespace assumptions: `cert-manager` may not exist if controller not deployed yet             | 2    | 2      | 4     | Medium   |
| OPS-002  | Unsubstituted `${LETSENCRYPT_EMAIL}` reduces ACME notices; minor operational visibility gap    | 1    | 2      | 2     | Low      |
| TECH-004 | YAML composition/formatting errors in multi‑document files                                     | 1    | 2      | 2     | Low      |
| OPS-004  | Alert noise from `CertificateNotReady` during first reconciliation                              | 1    | 2      | 2     | Low      |

Legend: Probability (1=Low, 2=Medium, 3=High); Impact (1=Low, 2=Medium, 3=High)

## Detailed Risk Register

### SEC-001: Over‑privileged Cloudflare API token
- Category: Security
- Affected: `externalsecret-cloudflare.yaml`, Cloudflare account/zone
- Detection: Review of manifests shows zone‑wide token usage pattern; wildcard issuance raises blast radius
- Probability: Medium (2) — token scope often defaults broader than needed
- Impact: High (3) — token compromise enables DNS manipulation and mis‑issuance
- Score: 6 (High)
- Mitigation: Scope token to specific zone and limited DNS permissions; rotate token; use distinct staging vs prod tokens if feasible
- Testing: Validate ExternalSecret sync; confirm secret created with only `api-token`; attempt limited DNS operations in a dry‑run sandbox

### TECH-001: Flux dependsOn mismatch/missing target
- Category: Technical
- Affected: `cert-manager/ks.yaml`
- Probability: Medium (2) — name drift between stories is common; repo currently lacks `kubernetes/infrastructure/security/external-secrets/`
- Impact: High (3) — reconciliation may stall or retry indefinitely
- Score: 6 (High)
- Mitigation: Align dependsOn name with actual Kustomization for External Secrets; ensure it exists before enabling issuers
- Testing: `flux get kustomizations -n flux-system` in target clusters; confirm `external-secrets` present

### OPS-001: Wrong `SECRET_DOMAIN`
- Category: Operational
- Probability: Medium (2)
- Impact: High (3) — ACME challenges fail or issue for undesired zone
- Score: 6 (High)
- Mitigation: Validate cluster-settings in both clusters; add preflight `flux build | yq` checks already listed in story
- Testing: Ensure `dnsZones` selector matches `${SECRET_DOMAIN}` and that ExternalDNS/Cloudflare settings agree

### SEC-002: ExternalSecret property mismatch
- Category: Security
- Probability: Medium (2)
- Impact: Medium (2) — secret key not present → issuers fail to authenticate
- Score: 4 (Medium)
- Mitigation: Confirm 1Password item field name is `credential` and maps to `api-token`; align with consumers
- Testing: `kubectl -n cert-manager get secret cloudflare-api-token -o yaml | yq '.data["api-token"]'`

### TECH-002: Missing PrometheusRule CRD
- Category: Technical
- Probability: Medium (2)
- Impact: Medium (2) — apply fails on CRD‑less cluster
- Score: 4 (Medium)
- Mitigation: Install prometheus‑operator CRDs in Phase 0 for both clusters (per PRD); gate apply until present
- Testing: `kubectl api-resources | grep monitoring.coreos.com`

### TECH-003: HealthChecks timeout without controllers
- Category: Technical
- Probability: Medium (2)
- Impact: Medium (2)
- Score: 4 (Medium)
- Mitigation: Keep deployment deferred (Story 45). If `ks.yaml` is applied early, set `timeout` appropriately or disable issuer healthChecks until controllers are present
- Testing: Reconcile in a dry lab with controllers off to observe behavior

### OPS-003: Namespace assumptions
- Category: Operational
- Probability: Medium (2)
- Impact: Medium (2)
- Score: 4 (Medium)
- Mitigation: Ensure `cert-manager` namespace exists via the chart before ExternalSecret and PrometheusRule live
- Testing: `kubectl get ns cert-manager`

### OPS-002: Unsubstituted ACME email
- Category: Operational
- Probability: Low (1)
- Impact: Medium (2)
- Score: 2 (Low)
- Mitigation: Validate presence of `LETSENCRYPT_EMAIL` in cluster-settings with `flux build | yq`

### TECH-004: YAML composition errors
- Category: Technical
- Probability: Low (1)
- Impact: Medium (2)
- Score: 2 (Low)
- Mitigation: `kubeconform`/`kustomize build` CI gates; editor schema hints

### OPS-004: Alert noise at first reconciliation
- Category: Operational
- Probability: Low (1)
- Impact: Medium (2)
- Score: 2 (Low)
- Mitigation: Tune alert `for` durations; temporarily silence during initial rollout window

## Risk Distribution

- Security: 2 risks (High: 1)
- Technical: 4 risks (High: 1)
- Operational: 4 risks (High: 1)
- Performance: 0 risks
- Data: 0 risks
- Business: 0 risks

## Risk-Based Testing Strategy

Priority 1: High Risks (SEC-001, TECH-001, OPS-001)
- Validate Cloudflare token scope and ExternalSecret mapping; confirm secret key `api-token`
- Verify `dependsOn` target exists and matches name; dry‑run reconciliation plan
- Preflight domain substitution via `flux build | yq` for both clusters

Priority 2: Medium Risks (SEC-002, TECH-002, TECH-003, OPS-003)
- Check 1Password item field names vs ExternalSecret `remoteRef.property`
- Ensure monitoring CRDs installed prior to PrometheusRule apply
- Simulate reconciliation with/without controllers to check healthChecks behavior
- Confirm `cert-manager` namespace existence when applying resources

Priority 3: Low Risks (OPS-002, TECH-004, OPS-004)
- Validate email substitution
- Run `kubeconform` and `kustomize build` locally/CI
- Monitor and tune alert noise post‑deployment

## Risk Acceptance Criteria

Must Fix Before Enabling Issuer Reconciliation (pre‑Story 45):
- SEC-001 token scope
- TECH-001 dependsOn naming/target
- OPS-001 cluster-settings domain values validated for both clusters

All other items may be addressed during Story 45 deployment and validation.

