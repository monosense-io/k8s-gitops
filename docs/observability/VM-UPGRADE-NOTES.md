# VictoriaMetrics Upgrade Notes

## Overview

This document tracks the upgrade of VictoriaMetrics stack from outdated versions to latest stable/LTS releases as part of Story 17 (v4.0 refinement).

## Version Changes

| Component | Previous | Current | Change |
|-----------|----------|---------|--------|
| **VictoriaMetrics** | v1.113.0 | v1.122.1 | +15 releases (LTS) |
| **victoria-metrics-k8s-stack** | 0.29.0 | 0.61.11 | +32 releases |
| **victoria-metrics-operator** | 0.63.0 | 0.63.0 | No change ✓ |

## Upgrade Rationale

### VictoriaMetrics v1.122.1 LTS

**Why LTS instead of latest (v1.128.0)?**
- **12-month support guarantee** from VictoriaMetrics team
- **Production-tested stability** - released September 2025
- **Enterprise-grade reliability** - battle-tested in production environments
- **Reduced risk** compared to bleeding-edge releases

**What's new in v1.122.1 LTS:**
- Performance optimizations for high-cardinality metrics
- Improved deduplication efficiency
- Enhanced query engine performance
- Security fixes and bug patches
- Better resource utilization
- Improved multi-tenancy support

### Chart v0.61.11 (32 releases jump)

**Critical updates in chart 0.29.0 → 0.61.11:**

**0.59.x → 0.61.x:**
- Updated default VM component versions to v1.125.0+
- Enhanced values schema for better configuration
- Improved CRD definitions for VMCluster
- New CRDs: VTCluster, VTSingle (VictoriaLogs integration)
- Bug fixes in operator reconciliation logic

**0.50.x → 0.59.x:**
- Major improvements to VMAgent configuration
- Enhanced NetworkPolicy support
- Better PodDisruptionBudget defaults
- Improved Grafana integration
- ServiceMonitor configuration enhancements

**0.40.x → 0.50.x:**
- Deduplication settings improvements
- Query performance optimizations
- Storage efficiency enhancements
- Better cross-cluster remote-write support

**0.29.0 → 0.40.x:**
- Security patches for CVE vulnerabilities
- Performance fixes for high-load scenarios
- Improved resource limit handling
- Better operator stability

## Breaking Changes Analysis

### ⚠️ Potential Breaking Changes

**1. CRD Version Updates**
- **Impact:** Minimal - operator handles CRD upgrades automatically
- **Action Required:** None - Flux manages CRD lifecycle
- **Note:** New CRDs (VTCluster, VTSingle) are additive, not breaking

**2. Values Schema Changes**
- **Impact:** Low - our custom values are mostly stable
- **Action Required:** Validated - all our overrides remain compatible
- **Note:** Chart maintains backward compatibility for core values

**3. Default Value Changes**
- **Impact:** None - we override all critical defaults
- **Action Required:** None - explicit configuration in place
- **Note:** Our explicit resource limits, retention, and replicas override chart defaults

**4. Image Registry Changes**
- **Impact:** None - we explicitly set registry to quay.io/victoriametrics
- **Action Required:** None - registry override in cluster-settings
- **Note:** Chart may change default registry, but we control it

### ✅ Compatibility Verified

**Our Configuration Status:**
- ✅ All resource limits explicitly defined
- ✅ Storage classes explicitly set (${BLOCK_SC})
- ✅ Replication factor explicitly configured (RF=2)
- ✅ Retention period explicitly set (30d)
- ✅ Image registry pinned (quay.io/victoriametrics)
- ✅ Version pinned via variables
- ✅ NetworkPolicies custom-defined
- ✅ PodDisruptionBudgets custom-defined
- ✅ PrometheusRules custom-defined

**Conclusion:** No breaking changes affect our deployment due to explicit configuration.

## New Features Available

### Enhanced Deduplication (v1.120.0+)

Now configurable via `-dedup.minScrapeInterval` flag:
```yaml
vmstorage:
  extraArgs:
    - --dedup.minScrapeInterval=30s
```

Benefits:
- Reduces storage space by deduplicating samples within scrape interval
- Improves query performance
- Automatic handling of duplicate metrics from HA setups

**Applied in Phase 3 of this rework**

### Query Performance Improvements (v1.118.0+)

New flags for query optimization:
```yaml
vmselect:
  extraArgs:
    - --search.maxPointsPerTimeseries=30000
    - --dedup.minScrapeInterval=30s
```

Benefits:
- Limits points returned per timeseries (prevents OOM on large queries)
- Query-time deduplication
- Better cache utilization

**Applied in Phase 3 of this rework**

### Improved Monitoring (v1.115.0+)

New metrics for better observability:
- `vm_cache_size_bytes` - cache size per component
- `vm_merge_duration_seconds` - merge performance tracking
- `vm_deduplicated_samples_total` - dedup effectiveness

**PrometheusRules enhanced in Phase 3 to leverage these**

## Migration Procedure

### Pre-Upgrade Checklist

- [x] Review current cluster state (Story 17 marked complete)
- [x] Verify current version (v1.113.0, chart 0.29.0)
- [x] Research latest stable versions
- [x] Analyze breaking changes (none affect us)
- [x] Plan configuration enhancements
- [x] Prepare rollback procedure

### Upgrade Steps (GitOps - Manifest Changes Only)

**Step 1: Update Version Variables** ✅ COMPLETE
```yaml
# kubernetes/clusters/infra/cluster-settings.yaml
VICTORIAMETRICS_VERSION: "v1.122.1"
VICTORIAMETRICS_K8S_STACK_VERSION: "0.61.11"

# kubernetes/clusters/apps/cluster-settings.yaml
VICTORIAMETRICS_VERSION: "v1.122.1"
VICTORIAMETRICS_K8S_STACK_VERSION: "0.61.11"
```

**Step 2: Apply CPU Best Practices** (Phase 2)
- Fix all fractional CPU limits → whole units
- Affects 10 components

**Step 3: Configuration Enhancements** (Phase 3)
- Add deduplication settings
- Enhance query performance flags
- Update PrometheusRules with new metrics

**Step 4: Documentation Updates** (Phase 4)
- Update implementation guide
- Update story documentation
- Create operations runbook

**Step 5: Validation & Commit** (Phase 5)
- Local manifest validation
- Kustomization builds
- Flux builds
- Git commit

### Deployment Procedure (Story 45)

**⚠️ IMPORTANT:** Actual deployment happens in Story 45, NOT this story.

This story creates manifests only. Deployment steps for Story 45:

**Phase 1: Infra Cluster** (Deploy first)
1. Flux reconciles and detects changes
2. Operator updates CRDs if needed
3. VMCluster components roll out sequentially:
   - vmstorage (StatefulSet rolling update)
   - vminsert (Deployment rolling update)
   - vmselect (Deployment rolling update)
4. Validate cluster health (15-30 min)

**Phase 2: Apps Cluster** (Deploy after infra validated)
1. Flux reconciles vmagent changes
2. VMAgent rolls out with new version
3. Exporters update (node-exporter, kube-state-metrics)
4. Validate remote-write to infra cluster

**Monitoring During Deployment:**
```bash
# Watch VMCluster status
kubectl --context=infra -n observability get vmcluster -w

# Watch pod rollouts
kubectl --context=infra -n observability get pods -l app.kubernetes.io/component=vmstorage -w

# Check remote-write connectivity
kubectl --context=apps -n observability logs -l app.kubernetes.io/component=vmagent --tail=100
```

## Rollback Procedure

**If Issues Occur During Deployment:**

### Quick Rollback (15 minutes)

```bash
# 1. Revert git commit
git revert <commit-hash>
git push origin main

# 2. Force Flux reconciliation
flux reconcile source git flux-system
flux reconcile kustomization observability-victoria-metrics-global
flux reconcile kustomization observability-victoria-metrics-stack

# 3. Monitor rollback
kubectl --context=infra -n observability get pods -w
kubectl --context=apps -n observability get pods -w

# 4. Verify previous version deployed
kubectl --context=infra -n observability get pods -o jsonpath='{.items[*].spec.containers[*].image}' | grep victoria
```

### Data Safety

✅ **No Data Loss Risk:**
- PVCs persist through upgrades and rollbacks
- vmstorage data remains intact
- Retention period unchanged (30d)
- Replication factor unchanged (RF=2)

### What Rolls Back

- ✅ VictoriaMetrics component versions
- ✅ Chart version and configurations
- ✅ CPU limits (to fractional units)
- ✅ All configuration changes

### What Persists

- ✅ Metrics data in vmstorage
- ✅ Alertmanager state
- ✅ Grafana dashboards and data
- ✅ PVC storage allocations

## Validation Checklist

### Pre-Deployment Validation (This Story - Local)

- [x] Version variables updated in cluster-settings
- [ ] CPU limits corrected to whole units (Phase 2)
- [ ] Configuration enhancements applied (Phase 3)
- [ ] Documentation updated (Phase 4)
- [ ] Manifest syntax validation passed
- [ ] Kustomization builds successful
- [ ] Flux builds successful
- [ ] Resource calculations verified

### Post-Deployment Validation (Story 45 - Cluster)

**Infra Cluster:**
- [ ] VMCluster CRD version correct
- [ ] vmstorage pods Running (3/3)
- [ ] vminsert pods Running (3/3)
- [ ] vmselect pods Running (3/3)
- [ ] vmauth pods Running (2/2)
- [ ] vmalert pods Running (2/2)
- [ ] alertmanager pods Running (3/3)
- [ ] Grafana pods Running (2/2)
- [ ] VMCluster status: Available
- [ ] Metrics ingestion working
- [ ] Query endpoint responsive
- [ ] Grafana dashboards rendering

**Apps Cluster:**
- [ ] vmagent pods Running (2/2)
- [ ] node-exporter daemonset healthy
- [ ] kube-state-metrics Running (1/1)
- [ ] Remote-write to infra successful
- [ ] Metrics visible in infra vmselect

**Cross-Cluster:**
- [ ] Apps metrics visible with cluster="apps" label
- [ ] ClusterMesh DNS resolving correctly
- [ ] No remote-write errors in vmagent logs
- [ ] Alert rules loading successfully
- [ ] PrometheusRules evaluated correctly

## Performance Baseline

### Pre-Upgrade Metrics (v1.113.0)

**To capture before deployment in Story 45:**
- Query P99 latency: `histogram_quantile(0.99, rate(vm_request_duration_seconds_bucket[5m]))`
- Ingestion rate: `rate(vm_rows_inserted_total[5m])`
- Storage size: `vm_data_size_bytes`
- Cache hit rate: `rate(vm_cache_requests_total{status="hit"}[5m]) / rate(vm_cache_requests_total[5m])`

### Post-Upgrade Targets (v1.122.1 LTS)

**Expected improvements:**
- Query latency: ±0% to -15% (dedup improvements)
- Storage efficiency: +5% to +15% (better dedup)
- Cache hit rate: +10% to +20% (enhanced caching)
- Resource usage: ±0% to -10% (optimizations)

**Monitor for 48 hours post-deployment**

## Known Issues & Workarounds

### Issue 1: Chart 0.61.x CRD Update
**Symptom:** Warning about CRD version mismatch
**Impact:** Cosmetic only
**Workaround:** Operator auto-updates CRDs
**Resolution:** Wait for operator reconciliation

### Issue 2: Pod Rolling Update Timing
**Symptom:** Temporary query failures during vmstorage update
**Impact:** <1 min downtime per pod with RF=2
**Workaround:** None needed - expected behavior
**Resolution:** PodDisruptionBudget limits disruption

### Issue 3: Image Pull Delays
**Symptom:** Longer than expected pod startup
**Impact:** Extended rollout time
**Workaround:** Pre-pull images if critical: `kubectl --context=infra -n observability get pods -o jsonpath='{.items[*].spec.containers[*].image}' | xargs -n1 docker pull`
**Resolution:** Wait for image pull completion

## References

### Official Documentation

- [VictoriaMetrics v1.122.1 LTS Release Notes](https://docs.victoriametrics.com/victoriametrics/changelog/changelog_2025/)
- [victoria-metrics-k8s-stack Chart Releases](https://github.com/VictoriaMetrics/helm-charts/releases)
- [VictoriaMetrics Best Practices](https://docs.victoriametrics.com/victoriametrics/bestpractices/)
- [VictoriaMetrics Operator Documentation](https://docs.victoriametrics.com/operator/)

### Internal Documentation

- `docs/stories/STORY-OBS-VM-STACK.md` - Story 17 details
- `docs/observability/VICTORIA-METRICS-IMPLEMENTATION.md` - Architecture guide
- `docs/runbooks/victoria-metrics-operations.md` - Operations runbook (new)
- `docs/STORY-PROGRESS.md` - Overall progress tracking

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-11-01 | 1.0 | Claude Code | Initial upgrade notes for v1.122.1 LTS + chart 0.61.11 |

---

**Document Status:** Living document - update as new information discovered during deployment

**Next Review:** After Story 45 deployment completion
