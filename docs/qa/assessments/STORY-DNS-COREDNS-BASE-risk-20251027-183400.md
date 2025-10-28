# QA Risk Profile — STORY-DNS-COREDNS-BASE (2025-10-27 rev 2)

- Story file: `docs/stories/STORY-DNS-COREDNS-BASE.md`
- Reviewer: Quinn (Test Architect & Quality Advisor)
- Method: Probability × Impact

## Executive Summary
- Total risks: 6
- Critical: 1, High: 1, Medium: 3, Low: 1
- Highest risk: TECH-001-OCI-URL (OCIRepository URL not set to approved registry)

## Risk Matrix
| ID              | Category | Description                                                                                   | Prob. | Impact | Score | Priority |
|-----------------|----------|-----------------------------------------------------------------------------------------------|-------|--------|-------|----------|
| TECH-001-OCI-URL| TECH     | OCIRepository `spec.url` uses placeholder; chart cannot be fetched                           | High (3) | High (3) | 9 | Critical |
| CONF-001-HA     | OPS      | Topology spread/PDB misconfig leads to DNS outage during drain/rolling updates               | Medium (2) | High (3) | 6 | High |
| SUB-001-VALUES  | TECH     | `${COREDNS_REPLICAS}` or `${COREDNS_CLUSTER_IP}` substitution missing/wrong                  | Medium (2) | Medium (2) | 4 | Medium |
| CIDR-001-SVC    | TECH     | ClusterIP not in Service CIDR (per cluster)                                                   | Low (1) | Medium (2) | 2 | Low |
| SCHEMA-001-CRDs | OPS      | Local schema validation fails without CRDs, masking other issues                             | Medium (2) | Low (1) | 2 | Low |
| WIRE-001-FLUX   | OPS      | Cluster Kustomization for CoreDNS omitted or missing dependsOn on `cilium-core`              | Medium (2) | Medium (2) | 4 | Medium |

## Mitigations and Tests
- TECH-001-OCI-URL: Must set approved OCI URL; preflight with `helm show chart` or Flux Source reconcile.
- CONF-001-HA: Ensure topologySpread label matches chart labels; PDB minAvailable: 1; test drain and rollout in validation story.
- SUB-001-VALUES: Flux build or yq checks verify substitution; add CI assertions.
- CIDR-001-SVC: Validate ClusterIP within CIDR ranges (infra 10.245.0.0/16, apps 10.247.0.0/16).
- SCHEMA-001-CRDs: Use `kubeconform --strict -ignore-missing-schemas` locally.
- WIRE-001-FLUX: Append CoreDNS Kustomization with dependsOn `cilium-core` and healthCheck HelmRelease.

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

