# Test Design: STORY-DNS-COREDNS-BASE (rev 2)

Date: 2025-10-27
Designer: Quinn (Test Architect)

## Strategy Overview
- Total scenarios: 16
- Levels: Unit 0, Integration 16, E2E 0 (runtime in Story 45)
- Priorities: P0: 8, P1: 6, P2: 2

## AC Mapping

AC‑1 HelmRelease
- 04.DNS-INT-001 (P0): values.replicaCount == ${COREDNS_REPLICAS}
- 04.DNS-INT-002 (P0): service.clusterIP == ${COREDNS_CLUSTER_IP}
- 04.DNS-INT-003 (P1): topologySpreadConstraints present and labelSelector matches k8s-app: kube-dns
- 04.DNS-INT-004 (P1): PDB minAvailable: 1
- 04.DNS-INT-005 (P1): securityContext hardened (non-root, readOnlyRootFilesystem, drop ALL)
- 04.DNS-INT-006 (P2): probes present (health 8080, ready 8181)

AC‑2 OCIRepository
- 04.DNS-INT-007 (P0): spec.ref.semver == 1.38.0
- 04.DNS-INT-008 (P0): spec.url set to approved (no placeholders); preflight “helm show chart …” available

AC‑3 PrometheusRule
- 04.DNS-INT-009 (P1): rules present (Absent, Down, HighErrorRate, LatencyHigh)

AC‑4 Kustomization
- 04.DNS-INT-010 (P0): component kustomization lists all files
- 04.DNS-INT-011 (P0): cluster-level Kustomization exists in both clusters with dependsOn cilium-core and HelmRelease healthCheck

AC‑5 Cluster Settings
- 04.DNS-INT-012 (P0): COREDNS_REPLICAS present per cluster
- 04.DNS-INT-013 (P0): COREDNS_CLUSTER_IP present per cluster

AC‑6 Local Validation
- 04.DNS-INT-014 (P1): kustomize build succeeds
- 04.DNS-INT-015 (P1): kubeconform strict with ignore-missing-schemas passes
- 04.DNS-INT-016 (P2): flux build shows no unresolved placeholders

## Risk-driven Tests
- Map to risks: TECH-001-OCI-URL → 04.DNS-INT-008; CONF-001-HA → 003/004; SUB-001-VALUES → 001/002/016; CIDR-001-SVC → CIDR check; WIRE-001-FLUX → 011; SCHEMA-001-CRDs → 015.

## Gate Block
```yaml
test_design:
  scenarios_total: 16
  by_level: { unit: 0, integration: 16, e2e: 0 }
  by_priority: { p0: 8, p1: 6, p2: 2 }
  coverage_gaps: []
```

