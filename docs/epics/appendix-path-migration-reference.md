# Appendix: Path Migration Reference

For reference when migrating documentation or scripts:

| Old Epic Path | New Actual Path | Layer |
|--------------|-----------------|-------|
| `kubernetes/infra/base/cilium/` | `kubernetes/infrastructure/networking/cilium/` | Infrastructure |
| `kubernetes/apps/base/cilium/` | (Same shared base, different variables) | N/A |
| `kubernetes/infra/base/rook-ceph/` | `kubernetes/infrastructure/storage/rook-ceph/` | Infrastructure |
| `kubernetes/infra/base/cert-manager/` | `kubernetes/infrastructure/security/cert-manager/` | Infrastructure |
| `kubernetes/infra/base/victoria-metrics/` | `kubernetes/workloads/platform/observability/victoria-metrics/` | Workloads |
| `kubernetes/infra/base/cloudnative-pg/` | `kubernetes/workloads/platform/databases/cloudnative-pg/` | Workloads |
| `kubernetes/apps/base/gitlab/` | `kubernetes/workloads/tenants/gitlab/` | Workloads |

**Base HelmReleases:** All in `kubernetes/bases/<component>/helmrelease.yaml`
**Cluster Variables:** All in `kubernetes/clusters/<name>/infrastructure.yaml` or `workloads.yaml`
