# Bootstrap Guide

This repository now separates Flux bootstrap from workload reconciliation. To bring a cluster
under GitOps control:

1. Ensure Talos has provisioned the nodes and a kubeconfig context exists (for example `infra`).
2. Run `task bootstrap:infra` (or `task bootstrap:apps`). The helper task will:
   - Execute `flux install` against the target cluster to seed CRDs and controllers.
   - Apply the cluster-specific `flux-system` kustomization so the controllers sync this repo.
3. Verify readiness with `flux get kustomizations --context <cluster> --watch`.
4. Flux upgrades are managed via the HelmRelease defined at `kubernetes/infrastructure/gitops/flux`.
   Bump the chart version there to roll controllers forward in a controlled way.

> The bootstrap directory intentionally avoids committing controller manifests; instead the Tasks
> rely on the Flux CLI to generate the correct version for the target cluster.
