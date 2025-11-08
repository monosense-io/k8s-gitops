# 20 — STORY-OBS-DASHBOARDS — Create Grafana Dashboard Manifests

Sequence: 20/50 | Prev: STORY-OBS-FLUENT-BIT.md | Next: TBD
Sprint: 3 | Lane: Observability
Global Sequence: 20/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-11-08
Links: kubernetes/infrastructure/observability/dashboards

## Story

As a platform engineer, I want to **create Grafana dashboard manifests** for comprehensive observability visualization, so that when deployed in Story 45, I have:
- Production-ready dashboards for VictoriaMetrics cluster health
- Log visualization dashboards for VictoriaLogs ingestion and storage
- Fluent Bit collection metrics dashboards
- CloudNativePG database monitoring dashboards
- DragonflyDB cache performance dashboards
- Kubernetes cluster and workload dashboards
- Multi-cluster comparison and global overview dashboards
- GitOps-managed dashboard ConfigMaps for version control

## Why / Outcome

- **Complete Observability**: Visual representation of metrics, logs, and infrastructure health
- **Proactive Monitoring**: Dashboards enable early detection of issues and performance degradation
- **Multi-Cluster Visibility**: Unified view across infra and apps clusters
- **GitOps Managed**: All dashboards version-controlled and auditable
- **Production Ready**: Official dashboards from VictoriaMetrics, CloudNativePG, and community sources

## Scope

### This Story (Manifest Creation)

Create the following Grafana dashboard manifests:

**Dashboard Organization (Layer-Based):**

1. **Infrastructure Layer** (`dashboards/infrastructure/`):
   - Kubernetes Cluster Monitoring (Grafana ID: 315)
   - Rook Ceph Cluster Health (Grafana ID: 2842)
   - Cilium Networking & BGP (Grafana ID: 16611)

2. **Database Layer** (`dashboards/databases/`):
   - CloudNativePG Cluster Overview (Grafana ID: 20417)
   - CloudNativePG PgBouncer Poolers (custom)
   - DragonflyDB Cache Performance (custom)

3. **Observability Layer** (`dashboards/observability/`):
   - VictoriaMetrics Cluster Health (Grafana ID: 11176)
   - VictoriaLogs Ingestion & Storage (custom)
   - Fluent Bit Collection Metrics (Grafana ID: 18855)

4. **Workloads Layer** (`dashboards/workloads/`):
   - Keycloak Authentication & Sessions (Grafana ID: 19659)

5. **Multi-Cluster Layer** (`dashboards/multi-cluster/`):
   - Cluster Comparison Dashboard (migrate from backup)
   - Global Overview Dashboard (migrate from backup)

**Configuration Pattern:**
- ConfigMaps with label `grafana_dashboard: "1"`
- JSON dashboards embedded in YAML
- Variable substitution from cluster-settings (${CLUSTER}, ${CNPG_SHARED_CLUSTER_NAME}, etc.)
- Folder-based organization in Grafana UI
- Metadata annotations for dashboard provenance

### Deferred to Story 45 (Deployment & Validation)

- Deploy dashboard ConfigMaps to observability namespace via Flux
- Verify Grafana sidecar discovers all dashboards
- Test dashboard rendering and metrics queries
- Validate variable substitution from cluster-settings
- Verify multi-cluster dashboards show both infra and apps data
- Test alert dashboard integration with VMAlert

## Acceptance Criteria

### Manifest Creation (This Story)

1. **Directory Structure Created:**
   ```
   kubernetes/infrastructure/observability/dashboards/
   ├── kustomization.yaml (top-level aggregator)
   ├── infrastructure/
   │   ├── kubernetes-cluster.yaml
   │   ├── rook-ceph-cluster.yaml
   │   ├── cilium-networking.yaml
   │   └── kustomization.yaml
   ├── databases/
   │   ├── cloudnative-pg-cluster.yaml
   │   ├── cloudnative-pg-pooler.yaml
   │   ├── dragonfly-cache.yaml
   │   └── kustomization.yaml
   ├── observability/
   │   ├── victoria-metrics-cluster.yaml
   │   ├── victoria-logs.yaml
   │   ├── fluent-bit.yaml
   │   └── kustomization.yaml
   ├── workloads/
   │   ├── keycloak.yaml
   │   └── kustomization.yaml
   └── multi-cluster/
       ├── cluster-comparison.yaml
       ├── global-overview.yaml
       └── kustomization.yaml
   ```

2. **Dashboard ConfigMaps Created:**
   - All ConfigMaps have label `grafana_dashboard: "1"`
   - Namespace: `observability`
   - Metadata annotations include:
     - `dashboard.grafana.io/grafana-id`: Original Grafana.com dashboard ID
     - `dashboard.grafana.io/revision`: Downloaded revision number
     - `dashboard.grafana.io/source`: Source URL
     - `dashboard.grafana.io/downloaded-date`: Download timestamp
     - `dashboard.grafana.io/layer`: Infrastructure layer (infrastructure, databases, observability, workloads, multi-cluster)

3. **Dashboard JSON Embedded in ConfigMaps:**
   - JSON format (Grafana native)
   - Datasource references updated to `VictoriaMetrics`
   - Variable substitution for cluster-specific values
   - Valid JSON structure (validated via `yq | fromjson`)

4. **Grafana HelmRelease Updated:**
   - `victoria-metrics/vmcluster/helmrelease.yaml` modified
   - `dashboardProviders` configured with 5 folders:
     - Infrastructure
     - Databases
     - Observability
     - Workloads
     - Multi-Cluster
   - Grafana sidecar enabled with:
     - `searchNamespace: observability`
     - `label: grafana_dashboard`
     - `labelValue: "1"`
     - `foldersFromFilesStructure: true`

5. **VMCluster Kustomization Updated:**
   - `victoria-metrics/vmcluster/kustomization.yaml` includes `../dashboards` resource
   - All dashboard ConfigMaps deployed with vmcluster

6. **Variable Substitution Configured:**
   - Cluster-settings variables used:
     - `${CLUSTER}` - Cluster identifier (infra/apps)
     - `${CNPG_SHARED_CLUSTER_NAME}` - PostgreSQL cluster name
     - `${DRAGONFLY_NAMESPACE}` - DragonflyDB namespace
     - `${GRAFANA_DASHBOARD_REFRESH}` - Default refresh interval
     - `${GRAFANA_DASHBOARD_TIMEZONE}` - Dashboard timezone
   - Flux postBuild.substituteFrom handles replacement

7. **Manifest Validation Passes:**
   - `yamllint` passes on all dashboard YAML files
   - Embedded JSON validates via `yq '.data | .[] | fromjson'`
   - All referenced variables exist in cluster-settings.yaml
   - `flux build kustomization` succeeds for vmcluster

8. **Dashboard Metadata Documentation:**
   - Each ConfigMap has clear annotations
   - Source dashboards pinned to specific revisions
   - Custom dashboards documented with metrics sources
   - Migration from backup dashboards tracked

## Implementation Details

### Dashboard Catalog with Pinned Versions

**Tier 1: Official Dashboards**

| Dashboard | Grafana ID | Version | Source | Layer |
|-----------|-----------|---------|--------|-------|
| VictoriaMetrics Cluster | 11176 | Latest | VictoriaMetrics Official | observability |
| CloudNativePG Cluster | 20417 | Latest | CloudNativePG Official | databases |
| Kubernetes Cluster | 315 | Latest | instrumentisto | infrastructure |
| Rook Ceph Cluster | 2842 | Latest | Ceph Official | infrastructure |
| Fluent Bit | 18855 | Latest | Community | observability |
| Cilium Networking | 16611 | Latest | Cilium Official | infrastructure |
| Keycloak | 19659 | Latest | Community | workloads |

**Tier 2: Custom Dashboards**

| Dashboard | Type | Metrics Source | Layer |
|-----------|------|----------------|-------|
| DragonflyDB Cache | Custom | VMServiceScrape (components/dragonfly/) | databases |
| VictoriaLogs | Custom | VictoriaLogs metrics + VMAuth | observability |
| CloudNativePG Pooler | Custom | cnpg_pgbouncer_pools_* metrics | databases |
| Cluster Comparison | Migrated | Multi-cluster external labels | multi-cluster |
| Global Overview | Migrated | Aggregated cluster metrics | multi-cluster |

### ConfigMap Pattern Template

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-{component}
  namespace: observability
  labels:
    grafana_dashboard: "1"
    app.kubernetes.io/name: grafana
    app.kubernetes.io/component: dashboard
    dashboard.grafana.io/layer: {layer}
  annotations:
    dashboard.grafana.io/grafana-id: "{id}"
    dashboard.grafana.io/revision: "{revision}"
    dashboard.grafana.io/source: "https://grafana.com/grafana/dashboards/{id}"
    dashboard.grafana.io/downloaded-date: "2025-11-08"
data:
  {component}.json: |
    {
      "dashboard": {
        "title": "{Component} - {View Type} [${CLUSTER}]",
        "uid": "{component}-{view}",
        "tags": ["{tags}", "${CLUSTER}"],
        "timezone": "${GRAFANA_DASHBOARD_TIMEZONE}",
        "refresh": "${GRAFANA_DASHBOARD_REFRESH}",
        "templating": {
          "list": [
            {
              "name": "cluster",
              "type": "constant",
              "current": {"value": "${CLUSTER}"}
            }
          ]
        },
        "panels": [...]
      }
    }
```

### Grafana HelmRelease Update

**File**: `kubernetes/infrastructure/observability/victoria-metrics/vmcluster/helmrelease.yaml`

**Additions**:
```yaml
grafana:
  enabled: true
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'infrastructure'
          orgId: 1
          folder: 'Infrastructure'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/infrastructure
        - name: 'databases'
          orgId: 1
          folder: 'Databases'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/databases
        - name: 'observability'
          orgId: 1
          folder: 'Observability'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/observability
        - name: 'workloads'
          orgId: 1
          folder: 'Workloads'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/workloads
        - name: 'multi-cluster'
          orgId: 1
          folder: 'Multi-Cluster'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/multi-cluster
  sidecar:
    dashboards:
      enabled: true
      searchNamespace: observability
      label: grafana_dashboard
      labelValue: "1"
      provider:
        foldersFromFilesStructure: true
```

### Variable Substitution from cluster-settings

**Existing Variables** (kubernetes/clusters/infra/cluster-settings.yaml):
- `CLUSTER: infra`
- `CNPG_SHARED_CLUSTER_NAME: shared-postgres`
- `GLOBAL_VM_SELECT_ENDPOINT: victoria-metrics-global-vmselect.observability.svc.cluster.local:8481`
- `OBSERVABILITY_GRAFANA_SECRET_PATH: kubernetes/infra/grafana-admin`

**New Variables to Add**:
```yaml
# Grafana Dashboard Configuration
GRAFANA_DASHBOARD_REFRESH: "30s"
GRAFANA_DASHBOARD_TIMEZONE: "browser"

# Component-specific filters
DRAGONFLY_NAMESPACE: "dragonfly-system"
KEYCLOAK_NAMESPACE: "keycloak-system"
```

## Implementation Phases

### Phase 1: Directory Structure & Base Configuration (30 min)
- Create dashboards/ directory tree
- Create layer kustomizations (5 files)
- Create top-level kustomization.yaml
- Update vmcluster/kustomization.yaml to include dashboards/

**Files**: 6 kustomization.yaml files

### Phase 2: Core Dashboard ConfigMaps (90 min)
- Download Tier 1 official dashboards from Grafana.com
- Create ConfigMaps for 5 dashboards:
  - VictoriaMetrics Cluster
  - CloudNativePG Cluster
  - Kubernetes Cluster
  - Rook Ceph Cluster
  - Fluent Bit
- Update datasource references to VictoriaMetrics
- Add variable substitution
- Validate JSON structure

**Files**: 5 ConfigMap YAML files

### Phase 3: Custom & Enhanced Dashboards (60 min)
- Create DragonflyDB dashboard from metrics
- Create VictoriaLogs dashboard
- Create CloudNativePG Pooler dashboard
- Validate metrics queries

**Files**: 3 ConfigMap YAML files

### Phase 4: Multi-Cluster Dashboards (30 min)
- Migrate from .backup/kubernetes/components/monitoring/
- Modernize cluster-comparison-dashboard.json
- Modernize global-dashboards.json
- Update datasources and cluster filtering

**Files**: 2 ConfigMap YAML files

### Phase 5: Grafana Configuration Update (15 min)
- Update victoria-metrics/vmcluster/helmrelease.yaml
- Add dashboardProviders configuration
- Enable sidecar with proper labels

**Files**: 1 HelmRelease modification

### Phase 6: Validation & Testing (30 min)
- yamllint validation
- JSON validation via yq
- Variable reference validation
- flux build kustomization test
- Documentation review

**Total Effort**: 3.75 hours (within 3-4 hour estimate)

## Validation Checklist

### Pre-Commit Validation
- [ ] All YAML files pass `yamllint`
- [ ] All embedded JSON validates via `yq '.data | .[] | fromjson'`
- [ ] All `${VARIABLE}` references exist in cluster-settings.yaml
- [ ] Dashboard UIDs are unique across all ConfigMaps
- [ ] Kustomize builds successfully: `kustomize build kubernetes/infrastructure/observability/victoria-metrics/vmcluster/`
- [ ] Flux build succeeds: `flux build kustomization observability-victoria-metrics-vmcluster --path ./kubernetes/infrastructure/observability/victoria-metrics/vmcluster`

### Post-Deploy Validation (Story 45)
- [ ] All dashboard ConfigMaps created in observability namespace
- [ ] Grafana sidecar discovers dashboards (check logs)
- [ ] Dashboards appear in correct Grafana folders
- [ ] VictoriaMetrics datasource returns data
- [ ] Dashboard variables work (cluster, namespace selectors)
- [ ] No "No Data" errors in panels
- [ ] Multi-cluster dashboards show both infra and apps
- [ ] Variable substitution complete (no `${VAR}` in deployed ConfigMaps)

## Technical Debt & Future Enhancements

**Known Limitations**:
- VictoriaLogs datasource requires Loki compatibility mode (future: native VictoriaLogs datasource plugin)
- Custom dashboards need manual metric discovery (future: automated dashboard generation)
- Dashboard updates require manual re-download (future: automated update checks)

**Future Enhancements**:
- Add more Cilium dashboards (ClusterMesh, Hubble, NetworkPolicy)
- Create Talos Linux node health dashboards
- Add application-specific dashboards (GitLab, Harbor, Mattermost)
- Implement dashboard templates for common patterns
- Add SLO/SLI dashboards for service reliability

## Dependencies

**Required (All Complete)**:
- ✅ **Story 17** (STORY-OBS-VM-STACK): VictoriaMetrics cluster + Grafana deployed
- ✅ **Story 18** (STORY-OBS-VICTORIA-LOGS): VictoriaLogs for log visualization
- ✅ **Story 19** (STORY-OBS-FLUENT-BIT): Fluent Bit metrics collection

**Deployment Dependency**:
- ⏳ **Story 45** (VALIDATE-NETWORKING): Deploys and validates all manifests

## References

**Grafana Dashboard Sources**:
- VictoriaMetrics: https://grafana.com/orgs/victoriametrics/dashboards
- CloudNativePG: https://github.com/cloudnative-pg/grafana-dashboards
- Kubernetes: https://grafana.com/grafana/dashboards/315
- Rook Ceph: https://grafana.com/grafana/dashboards/2842
- Fluent Bit: https://grafana.com/grafana/dashboards/18855
- Cilium: https://grafana.com/grafana/dashboards/16611

**Repository Documentation**:
- CLAUDE.md: Repository patterns and GitOps principles
- docs/observability/VICTORIA-METRICS-IMPLEMENTATION.md: VictoriaMetrics setup
- kubernetes/components/dragonfly/: DragonflyDB metrics examples
- .backup/kubernetes/components/monitoring/: Legacy dashboard references

**Implementation Notes**:
- ConfigMap-based provisioning (no Grafana Operator)
- Layer-based organization (infrastructure, databases, observability, workloads, multi-cluster)
- Variable substitution via Flux postBuild.substituteFrom
- Git as single source of truth (GitOps compliance)
- Grafana sidecar auto-discovery pattern

---

## Story Completion Criteria

This story is **COMPLETE** when:
1. ✅ All dashboard ConfigMaps created with proper labels and annotations
2. ✅ Directory structure follows layer-based organization pattern
3. ✅ Grafana HelmRelease updated with dashboardProviders configuration
4. ✅ VMCluster kustomization includes dashboards/
5. ✅ All manifests pass validation (yamllint, JSON, flux build)
6. ✅ Variable substitution configured for cluster-specific values
7. ✅ Documentation updated with dashboard catalog and sources
8. ✅ Git commit follows repository conventions
9. ✅ Ready for deployment in Story 45

**Next Story**: Story 45 (VALIDATE-NETWORKING) will deploy and validate these dashboards.
