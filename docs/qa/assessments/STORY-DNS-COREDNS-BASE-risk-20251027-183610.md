# QA Risk Profile — STORY-DNS-COREDNS-BASE (2025-10-27 rev 3)

- Story file: `docs/stories/STORY-DNS-COREDNS-BASE.md`
- Reviewer: Quinn (Test Architect & Quality Advisor)
- Method: Probability × Impact (BMAD)

## Executive Summary
- Total risks: 6
- Critical: 1, High: 1, Medium: 3, Low: 1
- Highest risk: TECH-001-OCI-URL — OCIRepository URL not set to approved registry (score 9)

## Risk Matrix
| ID                | Category | Description                                                                                          | Prob. | Impact | Score | Priority |
|-------------------|----------|------------------------------------------------------------------------------------------------------|-------|--------|-------|----------|
| TECH-001-OCI-URL  | TECH     | OCIRepository `spec.url` uses placeholder; chart cannot be fetched                                   | High (3) | High (3) | 9 | Critical |
| CONF-001-HA       | OPS      | Topology spread/PDB misconfig can cause DNS outage during drain/rollout                              | Medium (2) | High (3) | 6 | High |
| WIRE-001-FLUX     | OPS      | Cluster-level CoreDNS Kustomization omitted or missing dependsOn on `cilium-core`                    | Medium (2) | Medium (2) | 4 | Medium |
| SUB-001-VALUES    | TECH     | `${COREDNS_REPLICAS}` or `${COREDNS_CLUSTER_IP}` substitution missing/wrong                           | Medium (2) | Medium (2) | 4 | Medium |
| WIRE-002-HEALTH   | OPS      | Missing HelmRelease health check in cluster Kustomization leads to silent failures                   | Low (1) | Medium (2) | 2 | Low |
| SCHEMA-001-CRDs   | OPS      | Local schema validation fails without CRDs, disguising other issues unless `-ignore-missing-schemas` | Medium (2) | Low (1) | 2 | Low |

## Mitigations and Testing Focus
- TECH-001-OCI-URL: Must set approved OCI URL; preflight with `helm show chart` or Flux Source reconcile.
- CONF-001-HA: Ensure topologySpread labelSelector matches chart labels (k8s-app: kube-dns); PDB minAvailable: 1; validate in Story 45.
- WIRE-001-FLUX: Append CoreDNS Kustomizations in both clusters; `dependsOn: cilium-core`; add HelmRelease healthCheck.
- SUB-001-VALUES: Flux build/yq checks for replicaCount and clusterIP; CI assertion.
- WIRE-002-HEALTH: Include healthChecks for HelmRelease coredns.
- SCHEMA-001-CRDs: Use `kubeconform --strict -ignore-missing-schemas` locally.

## Gate Snippet
```yaml
risk_summary:
  totals: { critical: 1, high: 1, medium: 3, low: 1 }
  highest: { id: TECH-001-OCI-URL, score: 9, title: OCIRepository URL placeholder not set }
  recommendations:
    must_fix:
      - Set approved OCI chart URL and preflight
      - Add cluster CoreDNS Kustomizations with dependsOn
    monitor:
      - Validate HA spread/PDB configuration
      - Enforce substitution and CIDR checks in CI
```

