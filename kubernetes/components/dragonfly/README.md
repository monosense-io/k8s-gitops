# DragonflyDB Component

Reusable Kustomize Component for deploying DragonflyDB instances with production-ready defaults.

## Overview

This component provides a complete, production-hardened DragonflyDB deployment template including:
- High availability configuration (3 replicas by default)
- Pod Disruption Budget (PDB)
- Cilium Network Policies (zero-trust security)
- VictoriaMetrics monitoring and alerting
- External Secrets integration (1Password)
- Security hardening (PSA restricted compliance)

## Usage

### Basic Instance

Create a new DragonflyDB instance by referencing this component:

```yaml
# kubernetes/workloads/platform/databases/dragonfly-cache/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dragonfly-cache

components:
  - ../../../../components/dragonfly

resources:
  - namespace.yaml

replacements:
  - source:
      kind: ConfigMap
      name: dragonfly-config
    targets:
      - select:
          kind: Dragonfly
        fieldPaths:
          - metadata.name
          - metadata.namespace
      - select:
          kind: ExternalSecret
        fieldPaths:
          - metadata.namespace
      # ... (additional targets as needed)

configMapGenerator:
  - name: dragonfly-config
    literals:
      - DRAGONFLY_NAME=cache
      - DRAGONFLY_NAMESPACE=dragonfly-cache
      - DRAGONFLY_COMPONENT=cache
      - DRAGONFLY_MEMORY_LIMIT=4Gi
      - DRAGONFLY_MAXMEMORY=3600Mi
      - DRAGONFLY_CACHE_MODE=true
      - DRAGONFLY_DATA_SIZE=20Gi
      - DRAGONFLY_AUTH_SECRET_PATH=kubernetes/infra/dragonfly-cache/auth
```

### Available Parameters

All parameters have sensible defaults using `${VAR:=default}` syntax:

#### Instance Configuration
- `DRAGONFLY_NAME` (default: `dragonfly`) - Instance name
- `DRAGONFLY_NAMESPACE` (default: `dragonfly-system`) - Namespace
- `DRAGONFLY_COMPONENT` (default: `database`) - Component label

#### Image & Scaling
- `DRAGONFLY_IMAGE_TAG` (default: `v1.34.1`) - DragonflyDB image version
- `DRAGONFLY_REPLICAS` (default: `3`) - Number of replicas

#### Resources
- `DRAGONFLY_CPU_REQUEST` (default: `200m`)
- `DRAGONFLY_CPU_LIMIT` (default: `1000m`)
- `DRAGONFLY_MEMORY_REQUEST` (default: `512Mi`)
- `DRAGONFLY_MEMORY_LIMIT` (default: `2Gi`)
- `DRAGONFLY_MAXMEMORY` (default: `1800Mi`) - 90% of memory limit
- `DRAGONFLY_CACHE_MODE` (default: `false`) - Enable LRU eviction

#### Storage
- `DRAGONFLY_STORAGE_CLASS` (default: `openebs-local-nvme`)
- `DRAGONFLY_DATA_SIZE` (default: `10Gi`)
- `DRAGONFLY_SNAPSHOT_CRON` (default: `0 */6 * * *`) - Every 6 hours

#### Security
- `DRAGONFLY_SECRET_NAME` (default: `dragonfly-auth`)
- `DRAGONFLY_AUTH_SECRET_PATH` - **REQUIRED** - 1Password secret path
- `EXTERNAL_SECRET_STORE` (default: `onepassword`)
- `DRAGONFLY_USER_ID` (default: `10001`)
- `DRAGONFLY_FS_GROUP` (default: `10001`)

#### Network
- `DRAGONFLY_PORT` (default: `6379`)
- `DRAGONFLY_ADMIN_PORT` (default: `6380`)
- `DRAGONFLY_SERVICE_NAME` (default: `dragonfly-global`)
- `DRAGONFLY_SERVICE_GLOBAL` (default: `true`) - Cilium ClusterMesh
- `DRAGONFLY_SERVICE_SHARED` (default: `true`)

#### Network Policies
- `DRAGONFLY_ALLOW_GITLAB_NS` (default: `gitlab-system`)
- `DRAGONFLY_ALLOW_HARBOR_NS` (default: `harbor`)
- `DRAGONFLY_ALLOW_OBSERVABILITY_NS` (default: `observability`)

#### High Availability
- `DRAGONFLY_PDB_MIN_AVAILABLE` (default: `2`)
- `DRAGONFLY_TOPOLOGY_MAX_SKEW` (default: `1`)
- `DRAGONFLY_TOPOLOGY_WHEN_UNSATISFIABLE` (default: `ScheduleAnyway`)

#### Monitoring
- `DRAGONFLY_METRICS_INTERVAL` (default: `30s`)
- `DRAGONFLY_METRICS_TIMEOUT` (default: `10s`)

#### Advanced
- `DRAGONFLY_THREADS` (default: `0`) - Auto-detect CPU cores
- `DRAGONFLY_CLUSTER_MODE` (default: `emulated`)
- `DRAGONFLY_LUA_FLAGS` (default: `allow-undeclared-keys`)

## Use Cases

### Cache Instance (API Response Caching)
```yaml
configMapGenerator:
  - name: dragonfly-config
    literals:
      - DRAGONFLY_NAME=cache
      - DRAGONFLY_NAMESPACE=dragonfly-cache
      - DRAGONFLY_COMPONENT=cache
      - DRAGONFLY_CACHE_MODE=true          # Enable LRU eviction
      - DRAGONFLY_MEMORY_LIMIT=4Gi         # Large memory for caching
      - DRAGONFLY_MAXMEMORY=3600Mi         # 90% of limit
      - DRAGONFLY_DATA_SIZE=5Gi            # Minimal disk (cache only)
      - DRAGONFLY_SNAPSHOT_CRON=""         # No snapshots for cache
```

### Session Store (Persistent User Sessions)
```yaml
configMapGenerator:
  - name: dragonfly-config
    literals:
      - DRAGONFLY_NAME=sessions
      - DRAGONFLY_NAMESPACE=dragonfly-sessions
      - DRAGONFLY_COMPONENT=sessions
      - DRAGONFLY_CACHE_MODE=false         # No eviction (persistent)
      - DRAGONFLY_MEMORY_LIMIT=2Gi
      - DRAGONFLY_MAXMEMORY=1800Mi
      - DRAGONFLY_DATA_SIZE=20Gi           # Larger disk for persistence
      - DRAGONFLY_SNAPSHOT_CRON=0 */2 * * * # Snapshot every 2 hours
```

### Job Queue Backing (Async Task Processing)
```yaml
configMapGenerator:
  - name: dragonfly-config
    literals:
      - DRAGONFLY_NAME=queue
      - DRAGONFLY_NAMESPACE=dragonfly-queue
      - DRAGONFLY_COMPONENT=queue
      - DRAGONFLY_CACHE_MODE=false
      - DRAGONFLY_MEMORY_LIMIT=1Gi         # Smaller memory for queue
      - DRAGONFLY_MAXMEMORY=900Mi
      - DRAGONFLY_DATA_SIZE=10Gi
      - DRAGONFLY_SNAPSHOT_CRON=0 * * * *  # Snapshot every hour
```

## Files Included

- `dragonfly.yaml` - Main Dragonfly CR with comprehensive configuration
- `externalsecret.yaml` - 1Password integration for authentication
- `service.yaml` - ClusterIP service with Cilium ClusterMesh annotations
- `pdb.yaml` - Pod Disruption Budget for high availability
- `networkpolicy.yaml` - Cilium zero-trust network policies
- `servicemonitor.yaml` - VictoriaMetrics service scraping
- `prometheusrule.yaml` - Comprehensive alerting rules
- `kustomization.yaml` - Component definition

## Integration with Flux

Create a Flux Kustomization to deploy the instance:

```yaml
# kubernetes/workloads/platform/databases/dragonfly-cache/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: dragonfly-cache
  namespace: flux-system
spec:
  interval: 30m
  path: ./kubernetes/workloads/platform/databases/dragonfly-cache
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  dependsOn:
    - name: dragonfly-operator
  healthChecks:
    - apiVersion: dragonflydb.io/v1alpha1
      kind: Dragonfly
      name: cache
      namespace: dragonfly-cache
```

## Benefits

✅ **DRY**: Single template for multiple instances
✅ **Production-Ready**: PDB, NetworkPolicies, Security hardening
✅ **Self-Documenting**: Default values show expected configuration
✅ **Consistent**: All instances use the same battle-tested template
✅ **Flexible**: Override any parameter per instance
✅ **Secure**: Zero-trust networking, PSA restricted compliance
✅ **Observable**: Comprehensive metrics and alerting

## Migration from Direct Deployment

If you have an existing DragonflyDB deployment, migrate by:

1. Extract instance-specific values
2. Create a new kustomization referencing this component
3. Use `configMapGenerator` to override defaults
4. Validate with `flux build kustomization`
5. Apply and monitor

## References

- [Kustomize Components Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/components/)
- [DragonflyDB Operator](https://www.dragonflydb.io/docs/getting-started/kubernetes-operator)
- [Flux Kustomization API](https://fluxcd.io/flux/components/kustomize/kustomization/)
