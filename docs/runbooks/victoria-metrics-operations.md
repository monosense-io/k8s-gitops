# VictoriaMetrics Operations Runbook

**Version:** v1.122.1 LTS
**Chart:** victoria-metrics-k8s-stack 0.61.11
**Last Updated:** 2025-11-01

## Overview

This runbook provides operational procedures for managing VictoriaMetrics in the multi-cluster GitOps environment.

## Quick Reference

| Operation | Command | Context |
|-----------|---------|---------|
| Check VMCluster status | `kubectl --context=infra -n observability get vmcluster` | Infra |
| Check vmagent status | `kubectl --context=apps -n observability get pods -l app.kubernetes.io/name=vmagent` | Apps |
| View metrics ingestion rate | See [Performance Monitoring](#performance-monitoring) | Both |
| Trigger Flux reconcile | `flux reconcile kustomization observability-victoria-metrics-global` | Infra |
| View component logs | `kubectl --context=infra -n observability logs -l app.kubernetes.io/component=vmstorage` | Both |

## Architecture Overview

### Infra Cluster Components
- **VMCluster**: Centralized metrics storage
  - vmstorage (3 replicas): Data persistence
  - vmselect (3 replicas): Query processing
  - vminsert (3 replicas): Data ingestion
- **VMAuth** (2 replicas): Authentication/routing
- **VMAlert** (2 replicas): Alert rule evaluation
- **Alertmanager** (3 replicas): Alert routing
- **Grafana** (2 replicas): Visualization

### Apps Cluster Components
- **VMAgent** (2 replicas): Metrics collection
- **Node Exporter** (DaemonSet): System metrics
- **Kube State Metrics** (1 replica): Kubernetes resource metrics

## Version Upgrade Procedures

### Pre-Upgrade Checklist

- [ ] Review CHANGELOG for target version
- [ ] Check for breaking changes in `docs/observability/VM-UPGRADE-NOTES.md`
- [ ] Verify cluster capacity (node resources)
- [ ] Ensure backup/snapshot of configuration exists (Git commit)
- [ ] Plan maintenance window if needed
- [ ] Notify stakeholders of potential monitoring gaps

### Upgrading VictoriaMetrics Components

**1. Update Version Variables (GitOps)**

```bash
# Edit cluster-settings.yaml for both clusters
vim kubernetes/clusters/infra/cluster-settings.yaml
vim kubernetes/clusters/apps/cluster-settings.yaml

# Change:
VICTORIAMETRICS_VERSION: "v1.122.1"  # Update to target version
VICTORIAMETRICS_K8S_STACK_VERSION: "0.61.11"  # Update chart version
```

**2. Validate Manifests Locally**

```bash
# Validate syntax
kubectl --dry-run=client apply -f kubernetes/infrastructure/observability/victoria-metrics/vmcluster/
kubectl --dry-run=client apply -f kubernetes/infrastructure/observability/victoria-metrics/vmagent/

# Build kustomizations
kustomize build kubernetes/infrastructure/observability/victoria-metrics/vmcluster/
kustomize build kubernetes/infrastructure/observability/victoria-metrics/vmagent/

# Flux build validation
flux build kustomization observability-victoria-metrics-global \
  --path kubernetes/infrastructure/observability/victoria-metrics/vmcluster/
```

**3. Commit and Push (Trigger GitOps)**

```bash
git add kubernetes/clusters/*/cluster-settings.yaml
git commit -m "feat(observability): upgrade VictoriaMetrics to vX.Y.Z"
git push origin main
```

**4. Monitor Deployment**

```bash
# Watch VMCluster rollout (infra)
kubectl --context=infra -n observability get pods -w

# Watch vmagent rollout (apps)
kubectl --context=apps -n observability get pods -w

# Check Flux reconciliation status
flux get kustomizations -A --watch
```

**5. Post-Upgrade Validation**

```bash
# Verify VMCluster status
kubectl --context=infra -n observability get vmcluster

# Check component health
kubectl --context=infra -n observability get pods

# Verify metrics ingestion (see Performance Monitoring section)

# Test query endpoint
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up' | jq '.status'
# Expected: "success"
```

### Rollback Procedure

**If upgrade fails or issues occur:**

```bash
# 1. Revert Git commit
git revert <commit-hash>
git push origin main

# 2. Force Flux reconciliation
flux reconcile source git flux-system
flux reconcile kustomization observability-victoria-metrics-global --with-source
flux reconcile kustomization observability-victoria-metrics-stack --with-source

# 3. Monitor rollback
kubectl --context=infra -n observability get pods -w
kubectl --context=apps -n observability get pods -w

# 4. Verify previous version deployed
kubectl --context=infra -n observability get pods -o jsonpath='{.items[*].spec.containers[*].image}' | grep victoria
```

## Scaling Procedures

### Horizontal Scaling

**VMStorage (increases storage capacity and parallelism):**

```bash
# Edit vmcluster helmrelease
vim kubernetes/infrastructure/observability/victoria-metrics/vmcluster/helmrelease.yaml

# Change:
vmstorage:
  replicaCount: 5  # was 3

# Commit and let GitOps apply
git add kubernetes/infrastructure/observability/victoria-metrics/vmcluster/helmrelease.yaml
git commit -m "feat(observability): scale vmstorage to 5 replicas"
git push origin main
```

**VMSelect (increases query throughput):**

```bash
# Same process, change vmselect replicaCount
vmselect:
  replicaCount: 5  # was 3
```

**VMInsert (increases ingestion throughput):**

```bash
# Same process, change vminsert replicaCount
vminsert:
  replicaCount: 5  # was 3
```

### Vertical Scaling

**Increase CPU/Memory:**

```bash
# Edit resource limits in helmrelease.yaml
vmstorage:
  resources:
    limits:
      cpu: 4  # was 2 (use whole units!)
      memory: 8Gi  # was 4Gi
    requests:
      cpu: 1000m  # was 500m
      memory: 4Gi  # was 2Gi
```

**CRITICAL:** Always use whole CPU units for limits (1, 2, 4) per VM best practices!

### Storage Scaling

**Increase PVC Size:**

```bash
# 1. Edit helmrelease.yaml
vmstorage:
  storage:
    volumeClaimTemplate:
      spec:
        resources:
          requests:
            storage: "100Gi"  # was 50Gi

# 2. Commit changes
git add kubernetes/infrastructure/observability/victoria-metrics/vmcluster/helmrelease.yaml
git commit -m "feat(observability): increase vmstorage to 100Gi"
git push origin main

# 3. Manually expand PVCs (if needed)
kubectl --context=infra -n observability edit pvc <pvc-name>
# Set: spec.resources.requests.storage: 100Gi
```

## Performance Monitoring

### Key Metrics to Watch

**Ingestion Rate:**
```bash
# Query via vmselect
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &

curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=rate(vm_rows_inserted_total[5m])' | jq
```

**Query Latency (P99):**
```promql
histogram_quantile(0.99,
  sum(rate(vm_request_duration_seconds_bucket{job="vmselect"}[5m])) by (le)
)
```

**Storage Usage:**
```bash
kubectl --context=infra -n observability get pvc -l app.kubernetes.io/component=vmstorage

# Or via metrics:
# Query: vm_data_size_bytes{job="vmstorage"}
```

**Cache Hit Rate:**
```promql
rate(vm_cache_requests_total{status="hit"}[5m])
/
rate(vm_cache_requests_total[5m])
```

**Remote-Write Success Rate (Apps → Infra):**
```bash
kubectl --context=apps -n observability logs -l app.kubernetes.io/name=vmagent --tail=100 | grep "remote write"
```

**Active Time Series:**
```promql
sum(vm_cache_entries{type="storage/tsid"})
```

### Performance Baselines

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Query P99 Latency | < 1s | > 5s | > 10s |
| Ingestion Rate | Variable | - | Stalled (0 for 15min) |
| Remote-Write Success | > 99% | < 98% | < 95% |
| Storage Free Space | > 20% | < 20% | < 10% |
| Cache Hit Rate | > 80% | < 70% | < 50% |
| Active Series | < 10M | > 10M | > 20M |

### Grafana Dashboards

**Access Grafana:**
```bash
kubectl --context=infra -n observability port-forward svc/victoria-metrics-global-grafana 3000:80 &

# Open: http://localhost:3000
# Credentials from: kubernetes/infra/observability/grafana-admin secret
```

**Recommended Dashboards:**
1. VictoriaMetrics Cluster Overview
2. VMAgent Remote-Write Stats
3. VMStorage Capacity Planning
4. Query Performance Analysis

## Troubleshooting

### VMCluster Not Available

**Symptoms:**
- `kubectl get vmcluster` shows status != Available
- VMStorage/VMSelect/VMInsert pods not Running

**Diagnosis:**
```bash
# Check VMCluster status
kubectl --context=infra -n observability describe vmcluster victoria-metrics-global-vmcluster

# Check pod status
kubectl --context=infra -n observability get pods -l app.kubernetes.io/instance=victoria-metrics-global

# Check operator logs
kubectl --context=infra -n flux-system logs -l app.kubernetes.io/name=victoria-metrics-operator
```

**Common Causes & Solutions:**
1. **CRD version mismatch:** Ensure operator version matches CRD version
2. **Resource constraints:** Check node capacity, increase limits if needed
3. **Storage issues:** Verify PVCs are Bound, check storage class availability
4. **Image pull errors:** Check image registry accessibility

### Remote-Write Failures (Apps → Infra)

**Symptoms:**
- vmagent logs show remote-write errors
- Metrics from apps cluster not visible in infra vmselect

**Diagnosis:**
```bash
# Check vmagent logs
kubectl --context=apps -n observability logs -l app.kubernetes.io/name=vmagent --tail=200 | grep -i error

# Test ClusterMesh connectivity
kubectl --context=apps -n observability exec deploy/vmagent-victoria-metrics -- \
  nslookup vminsert-victoria-metrics-global-vmcluster.observability.svc.infra.cluster.local

# Check NetworkPolicy
kubectl --context=apps -n observability get networkpolicy
```

**Common Causes & Solutions:**
1. **ClusterMesh DNS issue:** Verify Cilium ClusterMesh status
2. **NetworkPolicy blocking:** Check egress rules allow port 8480
3. **Queue full:** Increase queue capacity in vmagent config
4. **Authentication required:** Verify vmauth configuration

### High Query Latency

**Symptoms:**
- Grafana dashboards slow to load
- Query P99 latency > 5s

**Diagnosis:**
```bash
# Check slow queries
kubectl --context=infra -n observability logs -l app.kubernetes.io/component=vmselect | grep "slow query"

# Check concurrent queries
# Query: vm_concurrent_select_current{job="vmselect"}
```

**Solutions:**
1. **Increase vmselect replicas:** Scale horizontally
2. **Optimize queries:** Add time range limits, reduce cardinality
3. **Increase cache size:** Add more memory to vmselect
4. **Enable query result cache:** Already enabled by default

### Storage Space Low

**Symptoms:**
- Alert: VMStorageCapacityWarning or VMStorageCapacityCritical
- vmstorage logs show disk space warnings

**Diagnosis:**
```bash
# Check PVC usage
kubectl --context=infra -n observability get pvc -l app.kubernetes.io/component=vmstorage

# Check actual disk usage
kubectl --context=infra -n observability exec -it vmstorage-victoria-metrics-global-vmcluster-0 -- df -h /storage
```

**Solutions:**
1. **Expand PVCs:** Follow storage scaling procedure
2. **Reduce retention:** Lower `VM_RETENTION_PERIOD` in cluster-settings
3. **Increase dedup:** Verify dedup.minScrapeInterval configured
4. **Review cardinality:** Identify and reduce high-cardinality metrics

### Deduplication Not Working

**Symptoms:**
- Alert: VMDeduplicationIneffective
- Storage usage higher than expected

**Diagnosis:**
```bash
# Check dedup rate
# Query: rate(vm_deduplicated_samples_total{job="vmstorage"}[5m]) / rate(vm_rows_inserted_total{job="vmstorage"}[5m])

# Verify dedup flags
kubectl --context=infra -n observability get pods vmstorage-victoria-metrics-global-vmcluster-0 -o yaml | grep dedup
```

**Solutions:**
1. **Verify scrape interval:** Ensure `-dedup.minScrapeInterval` matches actual scrape interval
2. **Check HA setup:** Dedup works best with multiple Prometheus/vmagent instances
3. **Review metric sources:** Verify metrics are actually duplicated

## Capacity Planning

### Storage Calculations

**Formula:**
```
Total Storage = (Samples/s × Retention Days × 86400 × Sample Size) / Compression Ratio × Replication Factor
```

**Example (30-day retention, RF=2):**
- 100k samples/s ingestion rate
- 30-day retention
- ~1 byte per sample (after compression)
- RF=2 (2x storage)

```
100,000 × 30 × 86400 × 1 / 7 × 2 ≈ 74GB total
```

**Per-replica calculation:**
```
74GB / 3 replicas ≈ 25GB per vmstorage replica
```

**Current config:** 50Gi per replica = ~2x safety margin ✓

### When to Scale

**Scale VMStorage (horizontal):**
- Storage usage > 80% despite expansion
- Need better data distribution
- Planning for significant retention increase

**Scale VMSelect (horizontal):**
- Query P99 latency consistently > 5s
- High concurrent query count (> 80% of max)
- Adding more Grafana users/dashboards

**Scale VMInsert (horizontal):**
- Ingestion rate approaching limits
- High insert latency (> 1s)
- Planning significant increase in scraped targets

**Scale Vertically (CPU/Memory):**
- Pods hitting CPU throttling
- Memory pressure/OOM kills
- Complex query workloads

## Backup and Disaster Recovery

### Configuration Backup

All configuration is in Git - **no manual backup needed!**

**Verify Git backup:**
```bash
cd /Users/monosense/iac/k8s-gitops
git status
git log --oneline kubernetes/infrastructure/observability/victoria-metrics/
```

### Metrics Data Backup

**VMStorage snapshots (future enhancement):**
```bash
# Not yet implemented - planned for future
# Will use vmbackup tool to S3-compatible storage
```

**Current DR strategy:**
- 30-day retention provides historical data buffer
- RF=2 protects against single node failure
- ClusterMesh provides cross-cluster redundancy for vmagent

### Recovery Procedures

**Scenario 1: Lost VMCluster Pod**

No action needed - StatefulSet/Deployment auto-recreates

**Scenario 2: Lost VMStorage Node**

```bash
# With RF=2, cluster continues operating
# Monitor cluster health
kubectl --context=infra -n observability get vmcluster

# Data rebalances automatically when node returns
```

**Scenario 3: Complete Cluster Loss**

```bash
# 1. Restore cluster infrastructure
# 2. Flux will auto-deploy VictoriaMetrics from Git
# 3. PVCs will reattach to new pods (if PV Retain policy)
# 4. Data preserved in PVs

# Worst case: Data lost, but config restored from Git
# Historical data loss limited to retention period
```

## Maintenance Windows

### Rolling Updates (No Downtime)

VictoriaMetrics supports zero-downtime updates with proper configuration:

**PodDisruptionBudgets ensure:**
- maxUnavailable: 1 for all components
- At least 2/3 replicas always available

**Update process:**
1. Git commit triggers update
2. StatefulSets/Deployments roll pods one at a time
3. PDBs prevent simultaneous pod termination
4. Continuous operation maintained

### Planned Maintenance

**For invasive changes (rare):**

```bash
# 1. Notify stakeholders
# 2. Schedule maintenance window
# 3. Prepare rollback plan
# 4. Execute changes via GitOps
# 5. Monitor closely during window
# 6. Validate post-change
```

## Monitoring the Monitors

**Meta-monitoring queries:**

**Are alerts working?**
```promql
ALERTS{alertstate="firing"}
```

**Is Alertmanager receiving alerts?**
```promql
rate(alertmanager_notifications_total[5m])
```

**Is vmalert evaluating rules?**
```promql
vmalert_alerting_rules_last_evaluation_timestamp_seconds
```

**Is Grafana accessible?**
```bash
kubectl --context=infra -n observability get pods -l app.kubernetes.io/name=grafana
```

## Best Practices Summary

✅ **DO:**
- Use whole CPU units for limits (1, 2, 4)
- Configure deduplication (--dedup.minScrapeInterval)
- Monitor storage capacity (keep > 20% free)
- Review cardinality regularly
- Use GitOps for all changes
- Test rollback procedures periodically
- Document custom queries and dashboards

❌ **DON'T:**
- Use fractional CPU limits (500m, 2000m)
- Apply changes directly with kubectl
- Ignore capacity alerts
- Run single replica of critical components
- Skip validation of manifest changes
- Bypass Flux reconciliation
- Forget to update documentation

## Reference Links

**Official Documentation:**
- [VictoriaMetrics Docs](https://docs.victoriametrics.com/)
- [Best Practices](https://docs.victoriametrics.com/victoriametrics/bestpractices/)
- [Troubleshooting](https://docs.victoriametrics.com/victoriametrics/faq/)

**Internal Documentation:**
- [STORY-OBS-VM-STACK.md](../stories/STORY-OBS-VM-STACK.md) - Story details
- [VICTORIA-METRICS-IMPLEMENTATION.md](../observability/VICTORIA-METRICS-IMPLEMENTATION.md) - Architecture
- [VM-UPGRADE-NOTES.md](../observability/VM-UPGRADE-NOTES.md) - Version upgrade notes
- [STORY-PROGRESS.md](../STORY-PROGRESS.md) - Overall progress

## Support Escalation

**Level 1: Self-Service**
- Check this runbook
- Review Grafana dashboards
- Check pod logs
- Review PrometheusRule alerts

**Level 2: Team Review**
- Review git history for recent changes
- Check Flux reconciliation logs
- Validate manifest syntax
- Review cluster resource capacity

**Level 3: VictoriaMetrics Community**
- [GitHub Issues](https://github.com/VictoriaMetrics/VictoriaMetrics/issues)
- [Slack Community](https://victoriametrics.slack.com/)
- Official documentation

**Emergency Rollback:**
- Always an option via git revert
- Documented in rollback procedure above
- < 15 minute recovery time

---

**Document Status:** Living document - update as procedures evolve
**Next Review:** After any significant operational event or quarterly
