# Actions Runner Controller - Base Definitions

## Overview

This directory contains reusable base definitions for GitHub Actions Runner Controller (ARC). These are cluster-agnostic templates that can be referenced by workload implementations.

## Structure

```
actions-runner-controller/
├── controller/              # Scale set controller base
│   ├── ocirepository.yaml   # Helm chart source
│   ├── helmrelease.yaml     # Controller deployment
│   └── kustomization.yaml
└── runner-scale-set/        # Runner scale set templates (reference only)
    ├── ocirepository.yaml   # Runner chart source
    ├── helmrelease.yaml     # Runner configuration template
    ├── externalsecret.yaml  # GitHub App credentials template
    ├── rbac.yaml            # RBAC template
    └── kustomization.yaml
```

## Usage

### Controller Base

The controller base is referenced directly by workload overlays:

```yaml
# In workloads/platform/cicd/actions-runner/controller/kustomization.yaml
resources:
  - ../../../../../bases/actions-runner-controller/controller
```

### Runner Scale Set Templates

The `runner-scale-set/` directory contains **templates** for reference. Due to kustomize security restrictions, these cannot be directly referenced across directory boundaries. Instead:

1. Copy the template files to your runner instance directory
2. Customize for your specific use case
3. Deploy as a standalone kustomization

**Example:** See `workloads/platform/cicd/actions-runner/runners/k8s-gitops/`

## Variables

These bases use Flux postBuild.substitute variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_CONFIG_URL` | GitHub repo or org URL | `https://github.com/org/repo` |
| `GITHUB_SECRET_NAME` | Secret containing GitHub App creds | `k8s-gitops-runner-secret` |
| `RUNNER_SCALE_SET_NAME` | Name of runner scale set | `k8s-gitops-runner` |
| `MIN_RUNNERS` | Minimum runner pods | `0` |
| `MAX_RUNNERS` | Maximum runner pods | `3` |
| `OPENEBS_STORAGE_CLASS` | StorageClass for runner workspace | `openebs-hostpath` |
| `RUNNER_STORAGE_SIZE` | Storage per runner | `25Gi` |
| `EXTERNAL_SECRET_STORE` | ClusterSecretStore name | `onepassword` |
| `ACTIONS_RUNNER_NAMESPACE` | Deployment namespace | `actions-runner-system` |

## Versions

- **Controller Chart:** 0.12.1
- **Runner Chart:** 0.12.1
- **Chart Registry:** `oci://ghcr.io/actions/actions-runner-controller-charts/`

## Architecture

```
GitHub Workflow Queue
         ↓
    Webhook (GitHub API)
         ↓
Actions Runner Controller (this base)
         ↓
AutoscalingRunnerSet CRD
         ↓
Runner Pods (scale 0→N based on demand)
         ↓
Execute Workflow Jobs
```

## Reference Implementation

See `workloads/platform/cicd/actions-runner/` for a complete implementation using these bases.

## Updates

To update ARC version:

1. Update `tag:` in both `ocirepository.yaml` files
2. Commit and push
3. Flux will reconcile automatically
4. Test in non-production first

## Resources

- **Upstream:** https://github.com/actions/actions-runner-controller
- **Charts:** https://github.com/actions/actions-runner-controller/tree/master/charts
- **Docs:** https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller
