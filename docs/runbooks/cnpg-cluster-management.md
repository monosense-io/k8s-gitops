# CNPG Cluster Management Runbook

## Overview

This runbook provides comprehensive procedures for managing CloudNativePG (CNPG) clusters deployed on Talos Kubernetes infrastructure. It covers cluster lifecycle management, operational procedures, and troubleshooting for both infra and apps clusters.

## Prerequisites

- Access to Talos control plane nodes
- `kubectl` configured for target cluster
- Appropriate RBAC permissions for CNPG operations
- Access to monitoring dashboards (VictoriaMetrics/Grafana)
- Understanding of cluster networking and storage architecture

## Cluster Architecture

### Infrastructure Components

- **Talos OS**: Immutable Linux distribution v1.11.2
- **Kubernetes**: v1.34.1 with Cilium CNI
- **Storage**: OpenEBS local NVMe for primary storage
- **CNPG Operator**: v0.26.1 with PostgreSQL 16.8
- **Networking**: Bonded interfaces with VLAN segmentation
- **Monitoring**: VictoriaMetrics stack with centralized logging

### Cluster Configuration

- **Infra Cluster**: 3-node control plane + worker nodes
- **Apps Cluster**: 3-node control plane + worker nodes
- **Shared Storage**: OpenEBS local NVMe with performance tuning
- **Network Segregation**: Infra (10.25.11.0/24), Apps (10.25.12.0/24), Services (10.25.13.0/24)

## Cluster Management Procedures

### 1. Cluster Initialization

#### 1.1 New Cluster Deployment

```bash
# 1. Prepare Talos configuration
cd talos/
./generate-config.sh infra

# 2. Apply control plane configurations
talosctl apply-config -n 10.25.11.11 -f ./infra/10.25.11.11.yaml

# 3. Bootstrap control plane
talosctl bootstrap -n 10.25.11.11 -f ./infra/10.25.11.11.yaml

# 4. Generate kubeconfig
talosctl kubeconfig -n 10.25.11.11 > ~/.kube/config-infra

# 5. Deploy CNPG operator
kubectl apply -f kubernetes/bases/keycloak-operator/

# 6. Configure cluster settings
kubectl apply -f kubernetes/clusters/infra/cluster-settings.yaml

# 7. Deploy CNPG cluster
kubectl apply -f kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml
```

#### 1.2 Cluster Scaling

**Adding Worker Nodes:**

```bash
# 1. Generate new node configuration
cd talos/
./generate-config.sh worker

# 2. Apply configuration to new node
talosctl apply-config -n <NODE_IP> -f ./worker/<NODE_CONFIG>.yaml

# 3. Join node to cluster
talosctl bootstrap -n <NODE_IP> -f ./worker/<NODE_CONFIG>.yaml

# 4. Verify node join
kubectl get nodes -o wide
```

**Control Plane Scaling:**

```bash
# 1. Update control plane configuration
# Edit machineconfig-multicluster.yaml.j2
# Add new control plane node with unique ID

# 2. Apply configuration
talosctl apply-config -n <NEW_CP_IP> -f ./infra/<NEW_CP_CONFIG>.yaml

# 3. Verify etcd cluster health
kubectl get nodes -n kube-system
kubectl get pods -n kube-system
```

### 2. CNPG Cluster Operations

#### 2.1 Cluster Status Monitoring

```bash
# Check cluster status
kubectl get cnpg -n cnpg-system

# Detailed cluster information
kubectl describe cnpg shared-postgres -n cnpg-system

# Check instances
kubectl get cnpginstances -n cnpg-system

# Monitor pod status
kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Check resource usage
kubectl top pods -n cnpg-system
kubectl top nodes
```

#### 2.2 Backup and Recovery

**Manual Backup:**

```bash
# Trigger immediate backup
kubectl annotate cnpg shared-postgres \
  -n cnpg-system \
  cnpg.io/backup="$(date +%Y-%m-%dT%H:%M:%SZ)"

# Check backup status
kubectl get cnpgbackups -n cnpg-system

# Monitor backup progress
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c backup-controller
```

**Point-in-Time Recovery:**

```bash
# 1. Identify recovery point
kubectl get cnpgbackups -n cnpg-system --sort-by=.metadata.creationTimestamp

# 2. Initiate recovery
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Recovery
metadata:
  name: recovery-$(date +%s)
spec:
  cluster:
    name: shared-postgres
  source:
    name: <BACKUP_NAME>
  type: point_in_time_recovery
EOF

# 3. Monitor recovery
kubectl get recovery -n cnpg-system -w
```

#### 2.3 Instance Management

**Creating New Instances:**

```bash
# 1. Create new instance
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Instance
metadata:
  name: new-instance
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  replicas: 1
  storage:
    size: 20Gi
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
EOF

# 2. Monitor instance creation
kubectl get instances -n cnpg-system -w
```

**Instance Scaling:**

```bash
# Scale up instances
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"instances":4}}'

# Scale down instances
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"instances":2}}'

# Verify scaling
kubectl get cnpginstances -n cnpg-system
```

#### 2.4 Database Operations

**Database Access:**

```bash
# Connect to primary instance
kubectl port-forward svc/shared-postgres-rw 5432:5432 -n cnpg-system &
psql -h localhost -p 5432 -U postgres -d postgres

# Connect to specific instance
kubectl exec -it <INSTANCE_POD> -n cnpg-system -- psql -U postgres

# List databases
psql -h localhost -p 5432 -U postgres -c "\l"

# Check database size
psql -h localhost -p 5432 -U postgres -c "SELECT pg_size_pretty(pg_database_size('postgres'))"
```

**User and Role Management:**

```bash
# Create application user
kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-user-credentials
  namespace: cnpg-system
type: Opaque
stringData:
  username: app_user
  password: <GENERATED_PASSWORD>
EOF

# Create role for application
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Role
metadata:
  name: app-role
  namespace: cnpg-system
spec:
  database: postgres
  schema: public
  name: app_user
  login: true
  passwordSecret:
    name: app-user-credentials
    key: password
  inherit: true
  replication: false
  createdb: false
  createrole: false
EOF

# Apply role to cluster
kubectl apply -f app-role.yaml
```

### 3. Maintenance Operations

#### 3.1 Rolling Updates

**CNPG Operator Updates:**

```bash
# 1. Check current version
kubectl get deployment cnpg-controller-manager -n cnpg-system -o yaml | grep image

# 2. Update operator version
# Edit cluster-settings.yaml to update CNPG_OPERATOR_VERSION
kubectl apply -f kubernetes/clusters/<cluster>/cluster-settings.yaml

# 3. Monitor rollout
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system

# 4. Verify upgrade
kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

**PostgreSQL Major Version Updates:**

```bash
# 1. Update cluster configuration
# Edit cluster-settings.yaml to update CNPG_POSTGRES_VERSION

# 2. Apply configuration
kubectl apply -f kubernetes/clusters/<cluster>/cluster-settings.yaml

# 3. Monitor rolling update
kubectl get cnpg -n cnpg-system -w
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c controller

# 4. Verify all instances updated
kubectl get cnpginstances -n cnpg-system -o wide
```

#### 3.2 Resource Management

**Storage Expansion:**

```bash
# 1. Check current storage usage
kubectl get pvc -n cnpg-system
kubectl describe cnpg shared-postgres -n cnpg-system

# 2. Expand storage
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"storage":{"size":"100Gi"}}'

# 3. Monitor storage expansion
kubectl get pvc -n cnpg-system -w
```

**Resource Limit Adjustments:**

```bash
# Update resource requests/limits
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"resources":{"requests":{"memory":"2Gi","cpu":"1000m"},"limits":{"memory":"4Gi","cpu":"4000m"}}'

# Verify resource changes
kubectl describe cnpg shared-postgres -n cnpg-system
```

#### 3.3 Performance Tuning

**PostgreSQL Configuration Updates:**

```bash
# 1. Connect to primary instance
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres

# 2. Update configuration
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '2GB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET work_mem = '5242kB';

# 3. Reload configuration
SELECT pg_reload_conf();

# 4. Verify changes
SHOW ALL;
```

**Connection Pool Optimization:**

```bash
# Check current connection usage
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

# Adjust max_connections if needed
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"postgresql":{"parameters":{"max_connections":"300"}}'
```

### 4. Security and Access Control

#### 4.1 Network Security

**NetworkPolicy Verification:**

```bash
# Check current policies
kubectl get networkpolicy -n cnpg-system

# Verify deny-all policy is applied
kubectl describe networkpolicy deny-all -n cnpg-system

# Verify allowed connections
kubectl describe networkpolicy allow-dns -n cnpg-system
kubectl describe networkpolicy allow-kube-api -n cnpg-system
kubectl describe networkpolicy allow-internal -n cnpg-system
```

**TLS Certificate Management:**

```bash
# Check certificate status
kubectl get certificates -n cnpg-system
kubectl describe certificate shared-postgres-tls -n cnpg-system

# Force certificate renewal
kubectl annotate certificate shared-postgres-tls \
  -n cnpg-system \
  cert-manager.io/renew-before="2024-01-01T00:00:00Z"

# Verify certificate chain
openssl s_client -connect -showcerts -connect localhost:5432 -servername shared-postgres-rw.cnpg-system.svc.cluster.local
```

#### 4.2 Authentication and Authorization

**Superuser Access Control:**

```bash
# Enable/disable superuser access
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"enableSuperuserAccess":true}}'

# Rotate superuser password
kubectl delete secret cnpg-superuser -n cnpg-system
# New password will be automatically generated

# Verify superuser access
kubectl get secret cnpg-superuser -n cnpg-system -o yaml
```

**Application Role Management:**

```bash
# List current roles
kubectl get roles -n cnpg-system

# Update role permissions
kubectl patch role harbor -n cnpg-system --type='merge' -p='{"spec":{"ensure":{"present":true,"login":true,"superuser":false,"createdb":true}}'

# Remove role
kubectl delete role gitlab -n cnpg-system

# Verify role changes
kubectl get roles -n cnpg-system -o wide
```

### 5. Monitoring and Troubleshooting

#### 5.1 Health Monitoring

**Cluster Health Checks:**

```bash
# Overall cluster status
kubectl get cnpg -n cnpg-system
kubectl describe cnpg shared-postgres -n cnpg-system

# Instance health
kubectl get cnpginstances -n cnpg-system -o wide

# Pod health and resource usage
kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
kubectl top pods -n cnpg-system

# Storage health
kubectl get pvc -n cnpg-system
kubectl df -h /var/mnt/openebs
```

**Performance Monitoring:**

```bash
# Connection metrics
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  datname,
  numbackends,
  xact_commit,
  blks_hit,
  blks_read,
  tup_returned,
  tup_fetched
FROM pg_stat_database 
WHERE datname = 'postgres';"

# Query performance
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;"

# Lock monitoring
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  relation,
  mode,
  locktype,
  transactionid,
  pid,
  mode,
  granted
FROM pg_locks 
WHERE granted = true;"
```

#### 5.2 Log Analysis

**Controller Logs:**

```bash
# Controller logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c controller

# Backup controller logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c backup-controller

# Instance manager logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c instance-manager

# Follow logs in real-time
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c controller -f
```

**Database Logs:**

```bash
# PostgreSQL logs
kubectl logs -n cnpg-system -l cnpg.io/cluster=shared-postgres -c postgres

# Export logs for analysis
kubectl logs -n cnpg-system -l cnpg.io/cluster=shared-postgres -c postgres > cnpg-logs-$(date +%Y%m%d).log

# Check for errors
kubectl logs -n cnpg-system -l cnpg.io/cluster=shared-postgres -c postgres | grep -i error
```

#### 5.3 Common Issues and Solutions

**High CPU Usage:**

```bash
# 1. Identify high CPU queries
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 5;"

# 2. Check for missing indexes
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT schemaname, tablename, attname 
FROM pg_attribute 
WHERE attname = 'heap' AND attoptions = 'i';"

# 3. Add missing indexes
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "CREATE INDEX CONCURRENTLY ON table_name (column_name);"

# 4. Update resource limits
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"resources":{"limits":{"cpu":"4000m"}}}'
```

**Storage Issues:**

```bash
# 1. Check disk usage
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- df -h

# 2. Check PostgreSQL disk usage
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT pg_size_pretty(pg_database_size('postgres')) as database_size;"

# 3. Clean up old WAL files
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "SELECT pg_walfile_name();"

# 4. Expand storage if needed
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"storage":{"size":"200Gi"}}'
```

**Connection Issues:**

```bash
# 1. Check service endpoints
kubectl get endpoints -n cnpg-system

# 2. Test connectivity
kubectl run pg-test --image=postgres:16 --rm -i --restart=Never -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U postgres -c "SELECT 1;"

# 3. Check network policies
kubectl get networkpolicy -n cnpg-system

# 4. Verify DNS resolution
nslookup shared-postgres-rw.cnpg-system.svc.cluster.local

# 5. Check certificate validity
openssl s_client -connect -showcerts -connect shared-postgres-rw.cnpg-system.svc.cluster.local:5432
```

**Replication Lag:**

```bash
# 1. Check replication status
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  application_name,
  client_addr,
  state,
  sync_state,
  reply_time
FROM pg_stat_replication;"

# 2. Check lag metrics
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  pg_size_pretty(pg_database_size('postgres')) as db_size,
  pg_wal_lsn_diff() as wal_lsn_diff;"

# 3. Restart replication if needed
kubectl delete pod <REPLICA_POD> -n cnpg-system
```

### 6. Disaster Recovery

#### 6.1 Backup Verification

**Backup Integrity:**

```bash
# 1. List recent backups
kubectl get cnpgbackups -n cnpg-system --sort-by=.metadata.creationTimestamp

# 2. Verify backup metadata
kubectl describe cnpgbackup <BACKUP_NAME> -n cnpg-system

# 3. Check backup files in MinIO
mc ls minio/cnpg-backups/shared-postgres/

# 4. Test backup restoration
kubectl create -f test-recovery.yaml
# (See Point-in-Time Recovery section)
```

#### 6.2 Full Cluster Recovery

**Cluster-Wide Failure Recovery:**

```bash
# 1. Assess damage
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# 2. Restore from backup if available
# Follow Point-in-Time Recovery procedure

# 3. Rebuild cluster components
kubectl delete cnpg shared-postgres -n cnpg-system
# Wait for cleanup
kubectl apply -f kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml

# 4. Verify recovery
kubectl get cnpg -n cnpg-system
kubectl get cnpginstances -n cnpg-system

# 5. Test applications connectivity
kubectl run connectivity-test --image=postgres:16 --rm -i -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U <APP_USER> -c "SELECT 1;"
```

#### 6.3 Data Center Failover

**Manual Failover Procedures:**

```bash
# 1. Update DNS records
# Update monosense.io DNS to point to backup data center

# 2. Verify external connectivity
# Test from external monitoring systems

# 3. Check application failover
# Verify applications reconnect to new cluster endpoint

# 4. Monitor performance
# Check VictoriaMetrics for performance degradation

# 5. Prepare for failback
# Document changes made during failover
```

### 7. Automation and GitOps Integration

#### 7.1 Configuration Management

**GitOps Workflow Updates:**

```bash
# 1. Update cluster configuration
git checkout -b feature/cnpg-enhancement
# Edit configuration files
git add .
git commit -m "feat: Update CNPG cluster configuration"

# 2. Push changes
git push origin feature/cnpg-enhancement

# 3. Monitor Flux reconciliation
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system
flux get kustomization cnpg-cluster -n flux-system

# 4. Verify deployment
flux reconcile kustomization cnpg-cluster -n flux-system --with-source
```

**Configuration Drift Detection:**

```bash
# 1. Compare desired vs actual state
kubectl get cnpg shared-postgres -n cnpg-system -o yaml > current-state.yaml
diff kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml current-state.yaml

# 2. Correct drift
# Apply desired configuration
kubectl apply -f kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml

# 3. Verify reconciliation
flux reconcile kustomization cnpg-cluster -n flux-system
```

#### 7.2 Automated Scaling

**Horizontal Pod Autoscaler:**

```bash
# 1. Deploy HPA for CNPG instances
kubectl create -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cnpg-hpa
  namespace: cnpg-system
spec:
  scaleTargetRef:
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    name: shared-postgres
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# 2. Monitor HPA activity
kubectl get hpa -n cnpg-system -w
kubectl describe hpa cnpg-hpa -n cnpg-system
```

**Vertical Pod Autoscaler:**

```bash
# 1. Enable VPA
kubectl create -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: cnpg-vpa
  namespace: cnpg-system
spec:
  targetRef:
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    name: shared-postgres
  updatePolicy: Auto
  resourcePolicy:
    minValues:
      cpu: 100m
      memory: 512Mi
EOF

# 2. Monitor VPA recommendations
kubectl get vpa cnpg-vpa -n cnpg-system -o yaml
kubectl describe vpa cnpg-vpa -n cnpg-system
```

### 8. Integration with Other Services

#### 8.1 Application Integration

**Harbor Registry Integration:**

```bash
# 1. Verify Harbor database access
kubectl exec -it harbor-core-0 -n harbor -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U harbor -c "\dt"

# 2. Test Harbor connectivity
kubectl exec -it harbor-core-0 -n harbor -- curl -f http://shared-postgres-rw.cnpg-system.svc.cluster.local:5000/v2/

# 3. Verify Harbor database setup
kubectl get role harbor -n cnpg-system
kubectl describe role harbor -n cnpg-system
```

**Keycloak Integration:**

```bash
# 1. Verify Keycloak database access
kubectl exec -it keycloak-0 -n keycloak -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U keycloak -c "\dt"

# 2. Test Keycloak connectivity
kubectl exec -it keycloak-0 -n keycloak -- curl -f http://shared-postgres-rw.cnpg-system.svc.cluster.local:8080/auth/

# 3. Verify Keycloak database setup
kubectl get role keycloak -n cnpg-system
kubectl describe role keycloak -n cnpg-system
```

**GitLab Integration:**

```bash
# 1. Verify GitLab database access
kubectl exec -it gitlab-toolbox-0 -n gitlab -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U gitlab -c "\dt"

# 2. Test GitLab connectivity
kubectl exec -it gitlab-toolbox-0 -n gitlab -- curl -f http://shared-postgres-rw.cnpg-system.svc.cluster.local:5432

# 3. Verify GitLab database setup
kubectl get role gitlab -n cnpg-system
kubectl describe role gitlab -n cnpg-system
```

#### 8.2 Monitoring Integration

**VictoriaMetrics Integration:**

```bash
# 1. Check PostgreSQL metrics collection
kubectl get servicemonitor -n cnpg-system
kubectl describe servicemonitor cnpg-postgres-metrics -n cnpg-system

# 2. Verify metrics endpoint
kubectl port-forward svc/victoria-metrics-k8s-stack 8428:8428 -n observability &
curl http://localhost:8428/metrics

# 3. Check Grafana dashboards
kubectl get configmap grafana-dashboards -n observability
kubectl describe configmap grafana-dashboards -n observability
```

### 9. Best Practices and Optimization

#### 9.1 Performance Optimization

**Connection Pool Tuning:**

```bash
# Calculate optimal connections
# Formula: (total_memory * 0.75) / (work_mem * 2MB)
# For 2GB memory with 128MB work_mem: (2048MB * 0.75) / (128MB * 2MB) = 6 connections

# Apply optimal configuration
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"postgresql":{"parameters":{"max_connections":"150"}}'
```

**Query Optimization:**

```bash
# Enable query statistics
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "ALTER SYSTEM SET track_activities = on;"

# Analyze slow queries
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  stddev_exec_time
FROM pg_stat_statements 
WHERE mean_exec_time > 100 
ORDER BY total_exec_time DESC 
LIMIT 10;"

# Create appropriate indexes
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "CREATE INDEX CONCURRENTLY IF NOT EXISTS slow_query_index (user_id, created_at);"
```

**Memory Optimization:**

```bash
# Check memory usage
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  name,
  setting,
  unit,
  short_desc
FROM pg_settings 
WHERE name LIKE '%memory%' OR name LIKE '%buffer%';"

# Optimize memory settings
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"postgresql":{"parameters":{"shared_buffers":"512MB","effective_cache_size":"2GB"}}'
```

#### 9.2 Security Hardening

**Network Security:**

```bash
# Verify network isolation
kubectl get networkpolicy -n cnpg-system
kubectl describe networkpolicy deny-all -n cnpg-system

# Check allowed connections
kubectl describe networkpolicy allow-dns -n cnpg-system
kubectl describe networkpolicy allow-kube-api -n cnpg-system

# Test network policies
kubectl run network-test --image=nicolaka/netshoot --rm -i -- nslookup shared-postgres-rw.cnpg-system.svc.cluster.local
```

**Access Control:**

```bash
# Review user permissions
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "
SELECT 
  r.rolname,
  r.rolsuper,
  ARRAY_AGG(r.grantee) as grantees
FROM pg_roles r
LEFT JOIN pg_auth_members m ON r.oid = m.roleid
LEFT JOIN pg_authid g ON m.member = g.rolname
WHERE r.rolname = 'harbor';"

# Remove unnecessary superuser privileges
kubectl exec -it <PRIMARY_POD> -n cnpg-system -- psql -U postgres -c "REVOKE ALL ON SCHEMA public FROM harbor;"
```

**Encryption and Certificates:**

```bash
# Verify TLS configuration
kubectl get certificates -n cnpg-system
openssl s_client -connect -showcerts -connect shared-postgres-rw.cnpg-system.svc.cluster.local:5432

# Check certificate rotation
kubectl describe certificate shared-postgres-tls -n cnpg-system
kubectl get events -n cnpg-system --field-selector involvedObject.kind=Certificate
```

#### 9.3 Backup and Recovery Optimization

**Backup Performance:**

```bash
# Configure backup retention
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"backup":{"retentionPolicy":"60d"}}'

# Optimize backup compression
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"backup":{"barmanObjectStore":{"wal":{"compression":"lz4"}}}}'

# Schedule backups during low-usage periods
kubectl annotate cnpg shared-postgres \
  -n cnpg-system \
  cnpg.io/backup-schedule="0 2 * * *"  # 2:00 AM daily
```

**Recovery Testing:**

```bash
# Regular recovery drills
# Schedule monthly recovery tests
kubectl create -f recovery-drill.yaml

# Document recovery procedures
# Update this runbook with lessons learned
```

### 10. Emergency Procedures

#### 10.1 Incident Response

**Database Outage Response:**

```bash
# 1. Immediate assessment (Time: 0-5 minutes)
kubectl get pods -n cnpg-system
kubectl get events -n cnpg-system --sort-by='.lastTimestamp'
kubectl top pods -n cnpg-system

# 2. Isolation and diagnosis (Time: 5-15 minutes)
kubectl scale deployment cnpg-controller-manager -n cnpg-system --replicas=0
kubectl exec -it <AFFECTED_POD> -n cnpg-system -- bash
# Investigate logs and system state

# 3. Recovery (Time: 15-60 minutes)
# Apply fixes based on diagnosis
kubectl scale deployment cnpg-controller-manager -n cnpg-system --replicas=1
kubectl get pods -n cnpg-system -w

# 4. Verification (Time: 60+ minutes)
# Test application connectivity
# Monitor system performance
# Document incident and lessons learned
```

**Storage Failure Response:**

```bash
# 1. Identify failed storage
kubectl get pvc -n cnpg-system
kubectl describe pvc <PVC_NAME> -n cnpg-system

# 2. Failover to standby (if available)
kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"instances":1}}'

# 3. Storage recovery
# Replace failed storage device
# Restore from backup if necessary

# 4. Service restoration
kubectl scale cnpg shared-postgres -n cnpg-system --type='merge' -p='{"spec":{"instances":3}}'
```

**Network Partition Response:**

```bash
# 1. Assess impact
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# 2. Local operations mode
# Document current state
# Continue operations with available resources

# 3. Recovery preparation
# Prepare for network restoration
# Document changes made during partition

# 4. Post-recovery verification
# Full system health check
# Data consistency verification
```

### 11. Runbook Maintenance

#### 11.1 Regular Updates

**Monthly Review:**

- [ ] Review and update cluster configurations
- [ ] Test backup and recovery procedures
- [ ] Update security policies and certificates
- [ ] Review performance metrics and optimize
- [ ] Update documentation with lessons learned

**Quarterly Review:**

- [ ] Full cluster performance audit
- [ ] Security assessment and penetration testing
- [ ] Disaster recovery drill execution
- [ ] Capacity planning and scaling review
- [ ] Documentation update and team training

#### 11.2 Version Control

**Runbook Versioning:**

- Current version: 1.0
- Last updated: 2025-01-31
- Next review date: 2025-02-28

**Change Log:**

```markdown
| Date | Change | Author | Description |
|------|--------|-------------|
| 2025-01-31 | Initial Creation | Complete CNPG cluster management runbook |
```

---

## Quick Reference Commands

### Essential Commands
```bash
# Cluster status
kubectl get cnpg -n cnpg-system

# Instance details
kubectl get cnpginstances -n cnpg-system -o wide

# Connect to database
kubectl port-forward svc/shared-postgres-rw 5432:5432 -n cnpg-system &
psql -h localhost -p 5432 -U postgres

# Check logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c controller

# Backup status
kubectl get cnpgbackups -n cnpg-system
```

### Emergency Contacts
- **Platform Engineering**: platform-team@monosense.io
- **On-Call Engineer**: +1-555-XXX-XXXX
- **Incident Response**: incidents@monosense.io

---

*This runbook should be reviewed quarterly and updated based on operational experience and platform evolution.*