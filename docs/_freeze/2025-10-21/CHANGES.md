# Sprint Freeze Change Log — 2025-10-21

## Key Decisions
- Secrets are managed exclusively via External Secrets with 1Password Connect (removed SOPS).
- Gateway: Cilium Gateway only (no Envoy Gateway).
- Storage: Apps cluster now has dedicated Rook‑Ceph; OpenEBS LocalPV remains default SC.
- Observability: Infra hosts VictoriaMetrics Global + VictoriaLogs; Apps deploy leaf collectors only; CRDs installed on apps.
- Namespace alignment to `observability` for all observability components.
- Real cluster-settings examples embedded (infra/apps) with current ASNs, CIDRs, endpoints.

## Document Consolidation
- Merged legacy guides (bootstrap, Cilium ownership, CNPG, monitoring strategy) into architecture.
- Removed superseded docs to keep documentation clean.

## Validation
- No SOPS/Envoy references remain.
- Endpoints and namespaces match current repo.
