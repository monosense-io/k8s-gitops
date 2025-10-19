# Multi-Cluster Monitoring Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the comprehensive multi-cluster monitoring strategy for your k8s-gitops infrastructure.

## Prerequisites

1. **Completed infrastructure setup**: Both `infra` and `apps` clusters are fully operational
2. **Cilium ClusterMesh**: Clusters are connected via Cilium ClusterMesh
3. **Storage provisioned**: Sufficient storage capacity for global VM cluster
4. **Network connectivity**: Cross-cluster network paths configured
5. **Secrets management**: OnePassword Connect configured and accessible

## Phase 1: Global VM Cluster Setup (Infra Cluster)

### 1.1 Create Authentication Secrets

Generate password hashes for multi-tenant access:

```bash
# Generate password hashes for vmauth
htpasswd -nBC 10 "" | tr -d ':\n' > infra_user_hash.txt
htpasswd -nBC 10 "" | tr -d ':\n' > apps_user_hash.txt
htpasswd -nBC 10 "" | tr -d ':\n' > global_read_hash.txt
htpasswd -nBC 10 "" | tr -d ':\n' > business_hash.txt

# Create OnePassword entries
# 1. Create entry: kubernetes/shared/victoria-metrics-secrets
# 2. Add fields: INFRA_VMUSER_HASH, APPS_VMUSER_HASH, GLOBAL_READ_VMUSER_HASH, BUSINESS_VMUSER_HASH
# 3. Create entry: kubernetes/shared/vmcluster-backup
# 4. Add fields: access-key-id, secret-access-key, bucket-name
```

### 1.2 Deploy Global VM Cluster

The global VM cluster will be deployed automatically by Flux once the secrets are available:

```bash
# Verify cluster settings include global monitoring
kubectl get configmap cluster-settings -n flux-system -o yaml

# Check Flux reconciliation
kubectl get kustomization -n flux-system
kubectl describe kustomization cluster-infra-observability -n flux-system
```

### 1.3 Verify Global Cluster Health

```bash
# Check VM cluster components
kubectl get pods -n observability
kubectl get vmcluster
kubectl get vmagent
kubectl get vmalert

# Verify vmauth configuration
kubectl get vmauth victoria-metrics-global-vmauth -n observability -o yaml

# Test multi-tenant access
curl -u global-read:password "http://victoria-metrics-global-vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=up"
```

## Phase 2: Multi-Cluster Data Collection

### 2.1 Configure VMagent Remote Write

The VMagent configuration will automatically forward metrics from both clusters to the global VM cluster:

```bash
# Verify VMagent is running in both clusters
kubectl get vmagent vmagent-multi-cluster -n observability

# Check remote write configuration
kubectl get vmagent vmagent-multi-cluster -n observability -o yaml | grep -A 20 remoteWrite

# Monitor remote write metrics
curl "http://victoriametrics-vmagent.observability.svc.cluster.local:8429/metrics" | grep remote_write
```

### 2.2 Verify Cross-Cluster Metrics

```bash
# Query metrics from global cluster
curl -u global-read:password "http://victoria-metrics-global-vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=up"

# Check cluster labels
curl -u global-read:password "http://victoria-metrics-global-vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=up%7Bcluster%3D%22infra%22%7D"

curl -u global-read:password "http://victoria-metrics-global-vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=up%7Bcluster%3D%22apps%22%7D"
```

## Phase 3: Alerting Configuration

### 3.1 Global Alert Rules

Multi-cluster alert rules are automatically deployed with the VMAlert component:

```bash
# Check alert rules
kubectl get vmrule -n observability
kubectl get vmrule multi-cluster-alerts -n observability -o yaml

# Verify alert evaluation
curl "http://victoria-metrics-global-vmalert.observability.svc.cluster.local:8880/metrics" | grep vmalert
```

### 3.2 Alertmanager Configuration

Global Alertmanager handles cross-cluster alert routing:

```bash
# Check Alertmanager configuration
kubectl get secret victoria-metrics-global-alertmanager -n observability -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Test alert routing
curl -X POST http://victoria-metrics-global-alertmanager.observability.svc.cluster.local:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning","cluster":"infra"}}]'
```

## Phase 4: Grafana Dashboards

### 4.1 Data Sources Configuration

Multi-cluster data sources are automatically configured:

```bash
# Check Grafana datasources
kubectl get configmap grafana-datasources -n observability -o yaml

# Verify dashboard provisioning
kubectl get configmap -l app.kubernetes.io/name=grafana-dashboard -n observability
```

### 4.2 Dashboard Access

Access the dashboards through your Grafana instance:

1. **Global Overview**: Multi-cluster infrastructure health
2. **Cluster Comparison**: Performance analysis across clusters
3. **Business Impact**: Business metrics and SLA monitoring

## Phase 5: Backup and Disaster Recovery

### 5.1 Backup Configuration

Daily backups are configured via CronJob:

```bash
# Check backup job
kubectl get cronjob vmcluster-backup -n observability

# Monitor backup execution
kubectl get jobs -n observability
kubectl logs job/vmcluster-backup-<timestamp> -n observability

# Verify backup metrics
curl "http://victoria-metrics-global-vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=vm_backup_last_success_timestamp_seconds"
```

### 5.2 Restore Testing

Test disaster recovery procedures:

```bash
# Simulate backup restore (test environment only)
kubectl create job --from=cronjob/vmcluster-backup vmcluster-backup-test -n observability

# Monitor restore process
kubectl logs -f job/vmcluster-backup-test-<pod> -n observability
```

## Phase 6: Performance Optimization

### 6.1 Monitor Resource Usage

```bash
# Check VM cluster resource usage
kubectl top pods -n observability -l app.kubernetes.io/name=victoria-metrics-global

# Monitor storage usage
kubectl exec -it victoria-metrics-global-vmstorage-0 -n observability -- df -h /storage
```

### 6.2 Tune Configuration

Optimize based on workload:

```yaml
# Example tuning for high throughput
vmcluster:
  spec:
    vminsert:
      maxInsertRequestSize: 33554432  # 32MB
      maxInsertRequestDuration: 30s
    vmstorage:
      maxHourlySeries: 1000000
      maxDailySeries: 10000000
```

## Phase 7: Security Hardening

### 7.1 Network Policies

Apply network policies for monitoring components:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmcluster-netpol
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: victoria-metrics-global
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: observability
    ports:
    - protocol: TCP
      port: 8480  # vminsert
    - protocol: TCP
      port: 8481  # vmselect
    - protocol: TCP
      port: 9428  # vmauth
```

### 7.2 RBAC Configuration

Ensure proper RBAC for monitoring components:

```bash
# Check service accounts
kubectl get serviceaccount -n observability

# Verify RBAC bindings
kubectl get clusterrole | grep monitoring
kubectl get clusterrolebinding | grep monitoring
```

## Monitoring and Maintenance

### Daily Checks

1. **Cluster health**: Verify all VM cluster components are running
2. **Metric ingestion**: Check remote write latency and success rates
3. **Alert evaluation**: Ensure alerts are being evaluated correctly
4. **Backup execution**: Verify daily backups are completing successfully
5. **Storage usage**: Monitor disk space and plan for capacity growth

### Weekly Tasks

1. **Performance review**: Analyze query performance and optimize if needed
2. **Capacity planning**: Review storage and memory utilization trends
3. **Alert tuning**: Review alert thresholds and reduce noise
4. **Dashboard updates**: Update dashboards based on new requirements

### Monthly Tasks

1. **Backup verification**: Test restore procedures in a non-production environment
2. **Security audit**: Review access logs and audit trails
3. **Cost analysis**: Review monitoring infrastructure costs
4. **Documentation updates**: Update operational procedures and runbooks

## Troubleshooting

### Common Issues

1. **VMagent remote write failures**
   ```bash
   # Check remote write status
   kubectl logs -l app.kubernetes.io/name=vmagent-multi-cluster -n observability | grep remote_write

   # Verify network connectivity
   kubectl exec -it vmagent-multi-cluster-<pod> -n observability -- nc -zv victoria-metrics-global-vminsert.observability.svc.cluster.local 8480
   ```

2. **Alertmanager not receiving alerts**
   ```bash
   # Check VMAlert configuration
   kubectl get vmalert victoria-metrics-global-vmalert -n observability -o yaml

   # Verify Alertmanager connectivity
   kubectl exec -it victoria-metrics-global-vmalert-<pod> -n observability -- nc -zv victoria-metrics-global-alertmanager.observability.svc.cluster.local 9093
   ```

3. **High memory usage in VM cluster**
   ```bash
   # Check memory usage by component
   kubectl top pods -n observability -l app.kubernetes.io/name=victoria-metrics-global

   # Review retention settings
   kubectl get vmcluster victoria-metrics-global -n observability -o yaml | grep retentionPeriod
   ```

### Performance Tuning

1. **Increase VM storage memory limits**
2. **Optimize query performance with proper indexing**
3. **Adjust remote write queue settings**
4. **Implement data retention policies**

## Scaling Considerations

### Horizontal Scaling

- Add more VM select replicas for query capacity
- Scale out VM insert replicas for write throughput
- Add VM storage replicas for data durability

### Vertical Scaling

- Increase CPU and memory limits based on workload
- Allocate more storage capacity based on retention needs
- Optimize network bandwidth for cross-cluster traffic

## Conclusion

This multi-cluster monitoring implementation provides unified visibility across your k8s-gitops infrastructure while maintaining cluster autonomy and resilience. Regular monitoring and maintenance will ensure optimal performance and reliability.

For additional support or questions, refer to the runbooks and documentation in your internal knowledge base.