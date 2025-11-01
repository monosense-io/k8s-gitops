# VictoriaMetrics Implementation

**Version:** v1.122.1 LTS
**Chart:** victoria-metrics-k8s-stack 0.61.11
**Last Updated:** 2025-11-01 (Story 17 v4.0 refinement)

## Overview

This document describes the implementation of VictoriaMetrics as a centralized observability solution for the multi-cluster GitOps environment using production-grade best practices and latest stable versions.

## Architecture

### Multi-Cluster Setup

**Infrastructure Cluster (`infra`)**
- **VMCluster**: Centralized metrics storage and query engine
  - VMSelect: Query endpoint (port 8481)
  - VMInsert: Ingestion endpoint (port 8480)
  - VMStorage: Data storage with persistent volumes
  - VMAuth: Authentication (port 8428)
  - VMAlert: Alerting (port 8888)
  - Grafana: Visualization (port 3000)
  - Alertmanager: Alert routing (port 9093)

**Applications Cluster (`apps`)**
- **VMAgent**: Metrics collection and remote-write
  - Collects metrics from all services
  - Remote-writes to infra cluster VMInsert
  - Node Exporter for system metrics
  - Kube State Metrics for Kubernetes resources

## Network Configuration

### Cross-Cluster Communication
- VMAgent (apps) → VMInsert (infra): Port 8480
- Cilium ClusterMesh enables cross-cluster connectivity
- Network policies restrict traffic to necessary ports only

### Allowed Metrics Ports
Based on existing services in the cluster:
- `6379`: Dragonfly Redis
- `6380`: Dragonfly admin
- `8080`: Dragonfly metrics, Cloudflared, Keycloak HTTP
- `8443`: Keycloak HTTPS
- `9000`: Keycloak management/metrics
- `9153`: CoreDNS metrics
- `7979`: External DNS

## Security

### Network Policies
- Default deny all ingress/egress
- Explicit allow rules for required traffic
- DNS access (UDP/TCP 53)
- HTTPS egress (443, 80)
- Cross-cluster remote-write (8480)

### Secrets Management
- ExternalSecrets for sensitive configuration
- 1Password integration for secret storage
- Encrypted secret references

## Storage

### VMCluster Storage
- **VMSelect**: 2Gi memory limit, 2 CPU limit
- **VMInsert**: 1Gi memory limit, 1 CPU limit
- **VMStorage**: 4Gi memory limit, 2 CPU limit, 50Gi storage per replica
- Persistent storage with Retain policy
- StorageClass: `ceph-block` (Rook-Ceph)
- **Retention**: 30 days
- **Replication Factor**: 2 (tolerates 1 node failure)

## High Availability

### Pod Disruption Budgets
- **VMSelect**: minAvailable: 1
- **VMInsert**: minAvailable: 1
- **VMStorage**: minAvailable: 1

### Replication
- VMSelect: 2 replicas
- VMInsert: 2 replicas
- VMStorage: 2 replicas
- VMAgent: 2 replicas

## Monitoring

### ServiceMonitors
- Dragonfly metrics collection
- Keycloak management metrics
- Additional services can be added as VMServiceScrape

### Alerting
- PrometheusRule compatibility
- Alertmanager integration
- Custom alert rules for VictoriaMetrics

## Deployment

### Prerequisites
1. Flux CD installed and configured
2. Cilium CNI with ClusterMesh
3. OpenEBS storage provisioner
4. 1Password Connect for secrets

### Installation Order
1. Infrastructure cluster components first
2. Applications cluster components
3. Configure cross-cluster networking
4. Set up monitoring and alerting

### Configuration
- Environment variables in cluster-settings ConfigMap
- Helm chart versioning
- Resource limits and requests
- Health check configurations

## Configuration Best Practices

### CPU Limits
All CPU limits use whole units (1, 2) instead of fractional (500m, 2000m) per VictoriaMetrics best practices for Go runtime optimization.

### Deduplication
Configured with `-dedup.minScrapeInterval=30s` across vmstorage, vmselect, and vminsert for:
- Reduced storage space
- Improved query performance
- Automatic handling of duplicate metrics from HA setups

### Query Optimization
- `--search.maxPointsPerTimeseries=30000` - Prevents OOM on large queries
- `--search.maxConcurrentRequests=100` - Concurrent query limit
- `--search.maxQueryDuration=5m` - Query timeout protection

### Capacity Planning Alerts
- Warning at 20% free space
- Critical at 10% free space
- High cardinality detection (>10M series)
- Query performance monitoring (P99 latency)

## Operations

### Version Information
- **VictoriaMetrics Components**: v1.122.1 LTS (12-month support)
- **Helm Chart**: victoria-metrics-k8s-stack 0.61.11
- **Operator**: victoria-metrics-operator 0.63.0

### Scaling
- Horizontal scaling via replica adjustments
- Storage scaling via PVC size increases
- Memory tuning based on workload

### Backup
- VMStorage data backup via snapshots
- Configuration backup via Git
- Disaster recovery procedures

### Troubleshooting
- Check cross-cluster connectivity
- Verify remote-write configuration
- Monitor resource utilization
- Check NetworkPolicy rules

## Integration Points

### Existing Services
- **Dragonfly**: Metrics on port 6379/6380
- **Keycloak**: Management metrics on port 9000
- **CoreDNS**: Metrics on port 9153
- **Cloudflared**: Health checks on port 8080
- **External DNS**: Metrics on port 7979

### Future Additions
- Application-specific ServiceMonitors
- Custom alerting rules
- Dashboard templates
- Log aggregation integration

## Configuration Files

### Infrastructure Cluster
- `vmcluster/helmrelease.yaml`: Main VMCluster configuration
- `vmcluster/externalsecret.yaml`: Secret references
- `vmcluster/networkpolicy.yaml`: Network security
- `vmcluster/pdb.yaml`: High availability
- `vmcluster/prometheusrule.yaml`: Alerting rules
- `vmcluster/ks.yaml`: Flux Kustomization

### Applications Cluster
- `vmagent/helmrelease.yaml`: VMAgent configuration
- `vmagent/networkpolicy.yaml`: Metrics collection rules
- `vmagent/ks.yaml`: Flux Kustomization

## Validation

### Pre-deployment
- YAML syntax validation
- Resource requirement verification
- Network policy testing
- Secret availability check

### Post-deployment
- Health check verification
- Metrics collection testing
- Cross-cluster connectivity
- Alert rule validation

## Maintenance

### Updates
- Helm chart version updates
- Configuration changes via GitOps
- Rolling updates with zero downtime
- Backup before major changes

### Monitoring
- Component health monitoring
- Performance metrics tracking
- Storage utilization monitoring
- Network traffic analysis
