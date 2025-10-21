Sprint Documentation Freeze — 2025-10-21

This folder contains a read-only snapshot of the architecture and PRD for the current sprint.

Included:
- architecture.v4.md — Multi-Cluster GitOps Architecture (v4.0)
- prd.v4.md — PRD: Multi-Cluster Kubernetes GitOps Platform (v4)
- manifest.json — file metadata and checksums

Source commit recorded in manifest.json.

Scope/Decisions frozen:
- Secrets: 1Password-only via External Secrets (no SOPS)
- Networking: Cilium + Cilium Gateway + ClusterMesh + SPIRE
- Storage: Dedicated Rook-Ceph on apps; OpenEBS LocalPV default on apps
- Observability: Infra runs VictoriaMetrics Global + VictoriaLogs; Apps run vmagent + kube-state-metrics + node-exporter + Fluent Bit; CRDs installed on apps
- Namespace: observability (no monitoring namespace)
- Cluster settings examples replaced with real repo values (infra/apps)
