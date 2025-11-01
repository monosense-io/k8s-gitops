# CNPG Operations Runbook

## Overview

This runbook provides day-to-day operational procedures for CloudNativePG (CNPG) clusters, covering routine tasks, monitoring, and standard operational workflows.

## Prerequisites

- `kubectl` configured with appropriate cluster context
- Required RBAC permissions for CNPG namespace operations
- Access to monitoring dashboards (VictoriaMetrics/Grafana)
- Understanding of application database schemas and requirements

## Daily Operations

### 1. Morning Health Checks

#### 1.1 Cluster Health Verification

```bash
#!/bin/bash
# Daily health check script
echo "=== CNPG Daily Health Check - $(date) ==="

# Check cluster status
echo "1. Cluster Status:"
kubectl get cnpg -n cnpg-system

# Check instance health
echo "2. Instance Status:"
kubectl get cnpginstances -n cnpg-system -o wide

# Check pod health
echo "3. Pod Status:"
kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Check resource usage
echo "4. Resource Usage:"
kubectl top pods -n cnpg-system --no-headers

# Check storage usage
echo "5. Storage Status:"
kubectl get pvc -n cnpg-system

# Check recent events
echo "6. Recent Events:"
kubectl get events -n cnpg-system --sort-by='.lastTimestamp' | tail -10

echo "=== Health Check Complete ==="
```

#### 1.2 Application Connectivity Tests

```bash
#!/bin/bash
# Application connectivity test script
echo "=== Application Connectivity Tests - $(date) ==="

# Test Harbor connectivity
echo "1. Testing Harbor Registry:"
kubectl exec -it harbor-core-0 -n harbor -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U harbor -c "SELECT 1;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Harbor: OK"
else
    echo "✗ Harbor: FAILED"
fi

# Test Keycloak connectivity
echo "2. Testing Keycloak SSO:"
kubectl exec -it keycloak-0 -n keycloak -- curl -f http://shared-postgres-rw.cnpg-system.svc.cluster.local:8080/auth/realms/master -o /dev/null 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Keycloak: OK"
else
    echo "✗ Keycloak: FAILED"
fi

# Test GitLab connectivity
echo "3. Testing GitLab:"
kubectl exec -it gitlab-toolbox-0 -n gitlab -- psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U gitlab -c "SELECT 1;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ GitLab: OK"
else
    echo "✗ GitLab: FAILED"
fi

echo "=== Connectivity Tests Complete ==="
```

### 2. Backup Operations

#### 2.1 Daily Backup Verification

```bash
#!/bin/bash
# Daily backup verification script
echo "=== Daily Backup Verification - $(date) ==="

# Check last 24 hours of backups
echo "1. Recent Backups (Last 24h):"
kubectl get cnpgbackups -n cnpg-system --sort-by='.metadata.creationTimestamp' | \
  awk -v now="$(date +%s)" '$1 > now - 86400 {print $1}'

# Check backup status
echo "2. Backup Status:"
kubectl get cnpgbackups -n cnpg-system -o json | \
  jq -r '.items[] | select(.status.phase == "completed") | length'

# Check backup size
echo "3. Latest Backup Size:"
kubectl get cnpgbackups -n cnpg-system -o json | \
  jq -r '.items[] | sort_by(.metadata.creationTimestamp) | last | .status.backupSize'

# Verify MinIO storage
echo "4. MinIO Storage Check:"
mc ls minio/cnpg-backups/shared-postgres/ | tail -5

echo "=== Backup Verification Complete ==="
```

#### 2.2 Weekly Backup Integrity Test

```bash
#!/bin/bash
# Weekly backup integrity test
echo "=== Weekly Backup Integrity Test - $(date) ==="

# Select random backup from last week
BACKUP_NAME=$(kubectl get cnpgbackups -n cnpg-system -o json | \
  jq -r '.items[] | select(.status.phase == "completed") | sort_by(.metadata.creationTimestamp) | last | .metadata.name')

echo "Testing backup: $BACKUP_NAME"

# Create test recovery
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Recovery
metadata:
  name: weekly-test-$(date +%Y%m%d)
  namespace: cnpg-system
spec:
  cluster:
    name: shared-postgres
  source:
    name: $BACKUP_NAME
  type: point_in_time_recovery
EOF

# Monitor recovery
echo "Monitoring recovery progress..."
kubectl get recovery weekly-test-$(date +%Y%m%d) -n cnpg-system -w

# Clean up test recovery
kubectl delete recovery weekly-test-$(date +%Y%m%d) -n cnpg-system

echo "=== Weekly Backup Test Complete ==="
```

### 3. Performance Monitoring

#### 3.1 Performance Metrics Collection

```bash
#!/bin/bash
# Performance metrics collection script
echo "=== CNPG Performance Metrics - $(date) ==="

# Collect database size metrics
echo "1. Database Sizes:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  datname,
  pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database_size 
WHERE datname NOT IN ('postgres', 'template1', 'template0')
ORDER BY pg_database_size(datname) DESC;"

# Collect connection metrics
echo "2. Connection Statistics:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  count(*) as total_connections,
  count(*) FILTER (WHERE state = 'active') as active_connections,
  count(*) FILTER (WHERE state = 'idle') as idle_connections
FROM pg_stat_activity;"

# Collect query performance
echo "3. Top 10 Slow Queries:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  left(query, 80) as query,
  calls,
  total_exec_time,
  mean_exec_time,
  stddev_exec_time
FROM pg_stat_statements 
WHERE mean_exec_time > 100
ORDER BY total_exec_time DESC 
LIMIT 10;"

# Collect lock information
echo "4. Lock Statistics:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  count(*) FILTER (WHERE granted = true) as granted_locks,
  count(*) FILTER (WHERE wait_start IS NOT NULL) as waiting_locks
FROM pg_locks;"

echo "=== Performance Metrics Collection Complete ==="
```

#### 3.2 Resource Usage Analysis

```bash
#!/bin/bash
# Resource usage analysis script
echo "=== CNPG Resource Usage Analysis - $(date) ==="

# Pod resource usage
echo "1. Pod Resource Usage:"
kubectl top pods -n cnpg-system --no-headers | \
  awk 'NR>1 {print $1": "$2" (CPU: "$3", Memory: "$5")}'

# PVC usage
echo "2. PVC Usage:"
kubectl get pvc -n cnpg-system -o custom-columns=NAME:.metadata.name,CAPACITY:.status.capacity.storage,USED:.status.capacity.storage

# Node resource pressure
echo "3. Node Resource Pressure:"
kubectl describe nodes | \
  awk '/Conditions:/ {print; /MemoryPressure/ {print "  Memory Pressure: " $0}; /DiskPressure/ {print "  Disk Pressure: " $0}; /PIDPressure/ {print "  PID Pressure: " $0}}'

# Performance alerts check
echo "4. Active Alerts:"
kubectl get prometheusrules -n observability | \
  grep -E "(cnpg|postgres)" | \
  awk '{print "  Alert: " $1 " - " $2}'

echo "=== Resource Usage Analysis Complete ==="
```

### 4. Maintenance Operations

#### 4.1 Weekly Maintenance Tasks

```bash
#!/bin/bash
# Weekly maintenance script
echo "=== CNPG Weekly Maintenance - $(date) ==="

# 1. Update statistics
echo "1. Updating database statistics:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "ANALYZE;"

# 2. Rebuild indexes (if needed)
echo "2. Checking index fragmentation:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  schemaname,
  tablename,
  attname,
  attvalue
FROM pg_attribute 
WHERE attname = 'heap' AND attoptions = 'i' AND attvalue > '0';"

# 3. Clean up old WAL files
echo "3. WAL cleanup check:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "SELECT pg_walfile_name();"

# 4. Check vacuum status
echo "4. Vacuum status:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  schemaname,
  tablename,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables;"

# 5. Certificate expiry check
echo "5. Certificate expiry check:"
kubectl get certificates -n cnpg-system -o json | \
  jq -r '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status == "False")) | {name: .metadata.name, reason: .status.reason}'

echo "=== Weekly Maintenance Complete ==="
```

#### 4.2 Monthly Maintenance Tasks

```bash
#!/bin/bash
# Monthly maintenance script
echo "=== CNPG Monthly Maintenance - $(date) ==="

# 1. Full database vacuum
echo "1. Full database vacuum:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "VACUUM ANALYZE;"

# 2. Update table statistics
echo "2. Comprehensive statistics update:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  'ANALYZE ' || schemaname || 'ALL' || 'ALL' || tablename || 'ALL' || 'ALL' || 'ALL' || 'ALL' || 'ALL' || 'ALL' || false) as cmd
FROM pg_stat_progress 
WHERE relid IS NOT NULL;"

# 3. Review and optimize slow queries
echo "3. Slow query optimization review:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  stddev_exec_time,
  total_exec_time / calls as avg_time_per_call
FROM pg_stat_statements 
WHERE total_exec_time > 1000
ORDER BY total_exec_time DESC 
LIMIT 20;"

# 4. Security audit
echo "4. Security audit:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  r.rolname,
  r.rolsuper,
  ARRAY_AGG(r.grantee) as grantees
FROM pg_roles r
LEFT JOIN pg_auth_members m ON r.oid = m.roleid
LEFT JOIN pg_authid g ON m.member = g.rolname
WHERE r.rolsuper = true;"

# 5. Capacity planning review
echo "5. Capacity planning:"
echo "Current database sizes:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  pg_size_pretty(pg_database_size(datname)) as size,
  pg_size_pretty(pg_total_relation_size(datname)) as relations_size
FROM pg_database_size 
WHERE datname NOT IN ('template1', 'template0')
ORDER BY pg_database_size(datname) DESC;"

echo "Growth trends (last 30 days):"
# This would require additional metrics collection setup

echo "=== Monthly Maintenance Complete ==="
```

### 5. User and Access Management

#### 5.1 Application User Management

```bash
#!/bin/bash
# Application user management script
echo "=== CNPG Application User Management - $(date) ==="

# List current application roles
echo "1. Current Application Roles:"
kubectl get roles -n cnpg-system -o custom-columns=NAME:.metadata.name,DATABASE:.spec.database,LOGIN:.spec.login,REPLICATION:.spec.replication

# Create new application user
create_app_user() {
    local app_name=$1
    local password=$(openssl rand -base64 32 | tr -d '\n')
    
    echo "Creating user for $app_name..."
    
    # Create password secret
    kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${app_name}-db-credentials
  namespace: cnpg-system
type: Opaque
stringData:
  username: ${app_name}
  password: ${password}
EOF

    # Create role
    kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Role
metadata:
  name: ${app_name}
  namespace: cnpg-system
spec:
  database: postgres
  schema: public
  name: ${app_name}
  login: true
  passwordSecret:
    name: ${app_name}-db-credentials
    key: password
  inherit: true
  replication: false
  createdb: false
  createrole: false
EOF

    echo "✓ Created user and role for $app_name"
    echo "Password: $password"
}

# Usage examples
echo "2. User Creation Examples:"
echo "  create_app_user new-service"
echo "  create_app_user analytics-app"
echo "  create_app_user reporting-tool"

echo "=== User Management Script Ready ==="
```

#### 5.2 Password Rotation

```bash
#!/bin/bash
# Password rotation script
echo "=== CNPG Password Rotation - $(date) ==="

# Function to rotate application user password
rotate_app_password() {
    local app_name=$1
    local new_password=$(openssl rand -base64 32 | tr -d '\n')
    
    echo "Rotating password for $app_name..."
    
    # Update secret
    kubectl patch secret ${app_name}-db-credentials -n cnpg-system --type='merge' -p "{\"stringData\":{\"password\":\"${new_password}\"}}"
    
    # Force role renewal to pick up new password
    kubectl delete role ${app_name} -n cnpg-system
    sleep 5
    
    # Recreate role (will pick up new password)
    kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Role
metadata:
  name: ${app_name}
  namespace: cnpg-system
spec:
  database: postgres
  schema: public
  name: ${app_name}
  login: true
  passwordSecret:
    name: ${app_name}-db-credentials
    key: password
  inherit: true
  replication: false
  createdb: false
  createrole: false
EOF

    echo "✓ Rotated password for $app_name"
}

# Rotate superuser password
echo "1. Rotating superuser password..."
kubectl delete secret cnpg-superuser -n cnpg-system

# Rotate application passwords
echo "2. Rotating application passwords..."
rotate_app_password harbor
rotate_app_password keycloak
rotate_app_password gitlab

echo "=== Password Rotation Complete ==="
```

### 6. Troubleshooting Procedures

#### 6.1 Common Issues Diagnosis

```bash
#!/bin/bash
# Common issues diagnosis script
echo "=== CNPG Issues Diagnosis - $(date) ==="

# Check 1: High connection count
echo "1. High Connection Count Diagnosis:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  count(*) as total_connections,
  count(*) FILTER (WHERE state = 'active') as active_connections,
  round((count(*) FILTER (WHERE state = 'active')::numeric / count(*)::numeric) * 100, 2) as active_percentage
FROM pg_stat_activity;"

if [ $active_percentage -gt 80 ]; then
    echo "  ⚠️  High connection usage: ${active_percentage}%"
    echo "  Consider increasing max_connections or connection pooling"
fi

# Check 2: Long-running queries
echo "2. Long-running Queries Diagnosis:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  pid,
  now() - pg_stat_activity.query_start,
  age(now(), pg_stat_activity.query_start) as duration_seconds,
  query
FROM pg_stat_activity 
WHERE state = 'active' 
  AND now() - pg_stat_activity.query_start > interval '5 minutes'
ORDER BY duration_seconds DESC 
LIMIT 10;"

# Check 3: Storage space
echo "3. Storage Space Diagnosis:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- df -h
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  pg_size_pretty(pg_database_size('postgres')) as db_size,
  pg_size_pretty(pg_total_relation_size('postgres')) as relations_size;"

# Check 4: Replication lag
echo "4. Replication Lag Diagnosis:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  application_name,
  client_addr,
  sync_state,
  reply_time
FROM pg_stat_replication;"

# Check 5: Lock contention
echo "5. Lock Contention Diagnosis:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
  count(*) FILTER (WHERE granted = true AND wait_start IS NOT NULL) as granted_immediate,
  count(*) FILTER (WHERE granted = true AND wait_start IS NOT NULL) as granted_total,
  round((granted_immediate::numeric / granted_total::numeric) * 100, 2) as immediate_percentage
FROM pg_locks;"

if [ $immediate_percentage -gt 50 ]; then
    echo "  ⚠️  High lock contention: ${immediate_percentage}%"
    echo "  Consider query optimization or reducing transaction size"
fi

echo "=== Diagnosis Complete ==="
```

#### 6.2 Performance Issues Resolution

```bash
#!/bin/bash
# Performance issues resolution script
echo "=== CNPG Performance Issues Resolution - $(date) ==="

# Resolve high CPU usage
resolve_high_cpu() {
    echo "Resolving high CPU usage..."
    
    # Identify top CPU consuming queries
    kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
    SELECT 
      query,
      calls,
      total_exec_time,
      mean_exec_time
    FROM pg_stat_statements 
    ORDER BY total_exec_time DESC 
    LIMIT 5;" > /tmp/top_queries.sql
    
    # Add missing indexes if needed
    kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
    SELECT 
      schemaname,
      tablename,
      attname
    FROM pg_attribute 
    WHERE attname = 'heap' AND attoptions = 'i';" > /tmp/missing_indexes.sql
    
    echo "Review top queries and missing indexes for optimization"
}

# Resolve memory issues
resolve_memory_issues() {
    echo "Resolving memory issues..."
    
    # Check current memory settings
    kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
    SHOW ALL;" | grep -E "(shared_buffers|effective_cache_size|work_mem)"
    
    # Optimize memory settings
    kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p '{
        "spec": {
            "postgresql": {
                "parameters": {
                    "shared_buffers": "512MB",
                    "effective_cache_size": "2GB",
                    "work_mem": "128MB"
                }
            }
        }
    }'
    
    echo "Applied memory optimization settings"
}

# Resolve connection issues
resolve_connection_issues() {
    echo "Resolving connection issues..."
    
    # Check current max_connections
    kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "SHOW max_connections;"
    
    # Increase connection limit if needed
    kubectl patch cnpg shared-postgres -n cnpg-system --type='merge' -p '{
        "spec": {
            "postgresql": {
                "parameters": {
                    "max_connections": "300"
                }
            }
        }
    }'
    
    echo "Increased max_connections to 300"
}

# Menu for issue resolution
echo "Select issue to resolve:"
echo "1) High CPU usage"
echo "2) Memory issues"
echo "3) Connection issues"
echo "4) Exit"

read -p "Enter choice [1-4]: " choice

case $choice in
    1) resolve_high_cpu ;;
    2) resolve_memory_issues ;;
    3) resolve_connection_issues ;;
    4) exit ;;
    *) echo "Invalid choice" ;;
esac

echo "=== Resolution Complete ==="
```

#### 6.3 Connectivity Issues Resolution

```bash
#!/bin/bash
# Connectivity issues resolution script
echo "=== CNPG Connectivity Issues Resolution - $(date) ==="

# Test basic connectivity
test_basic_connectivity() {
    echo "Testing basic database connectivity..."
    
    # Test service resolution
    nslookup shared-postgres-rw.cnpg-system.svc.cluster.local
    
    # Test port connectivity
    kubectl run pg-connectivity-test --image=postgres:16 --rm -i --restart=Never -- \
        psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U postgres -c "SELECT 1;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Basic connectivity: OK"
        return 0
    else
        echo "✗ Basic connectivity: FAILED"
        return 1
    fi
}

# Test application-specific connectivity
test_app_connectivity() {
    local app_name=$1
    local db_user=$2
    
    echo "Testing $app_name connectivity..."
    
    kubectl exec -it ${app_name}-0 -n ${app_name} -- \
        psql -h shared-postgres-rw.cnpg-system.svc.cluster.local -U ${db_user} -c "SELECT 1;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ $app_name connectivity: OK"
    else
        echo "✗ $app_name connectivity: FAILED"
    fi
}

# Check network policies
check_network_policies() {
    echo "Checking network policies..."
    
    kubectl get networkpolicy -n cnpg-system -o wide
    
    echo "Checking if required policies exist:"
    kubectl get networkpolicy deny-all allow-dns allow-kube-api allow-internal -n cnpg-system -o name
}

# Main diagnostic flow
echo "1. Basic connectivity test"
test_basic_connectivity

echo "2. Application connectivity tests"
test_app_connectivity harbor harbor
test_app_connectivity keycloak keycloak
test_app_connectivity gitlab gitlab

echo "3. Network policy verification"
check_network_policies

echo "4. Certificate verification"
kubectl get certificates -n cnpg-system
openssl s_client -connect -showcerts -connect shared-postgres-rw.cnpg-system.svc.cluster.local:5432

echo "=== Connectivity Resolution Complete ==="
```

### 7. Automation Scripts

#### 7.1 Automated Health Monitoring

```bash
#!/bin/bash
# Automated health monitoring with alerting
echo "=== CNPG Automated Health Monitoring ==="

# Configuration
ALERT_EMAIL="ops@monosense.io"
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
LOG_FILE="/var/log/cnpg-health-monitor.log"

# Health check function
health_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status="HEALTHY"
    
    # Check cluster status
    local cluster_health=$(kubectl get cnpg shared-postgres -n cnpg-system -o json | jq -r '.status.phase')
    
    # Check instance health
    local instances_health=$(kubectl get cnpginstances -n cnpg-system -o json | jq -r '.items[] | map(select(.ready == true)) | length')
    local total_instances=$(kubectl get cnpginstances -n cnpg-system -o json | jq -r '.items | length')
    
    # Check pod health
    local healthy_pods=$(kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --field-selector=status.phase=Running | wc -l)
    local total_pods=$(kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg | wc -l)
    
    # Determine overall status
    if [ "$cluster_health" != "Healthy" ] || [ $instances_health -lt $total_instances ] || [ $healthy_pods -lt $total_pods ]; then
        status="UNHEALTHY"
    fi
    
    # Log result
    echo "$timestamp: $status (Cluster: $cluster_health, Instances: $instances_health/$total_instances, Pods: $healthy_pods/$total_pods)" >> $LOG_FILE
    
    # Send alert if unhealthy
    if [ "$status" = "UNHEALTHY" ]; then
        echo "Sending alert for unhealthy status..."
        curl -X POST -H 'Content-type: application/json' \
            -d "{\"text\":\"CNPG cluster unhealthy: $status\"}" \
            $SLACK_WEBHOOK 2>/dev/null
        
        echo "Alert email sent to $ALERT_EMAIL"
    fi
}

# Continuous monitoring
while true; do
    health_check
    sleep 300  # Check every 5 minutes
done
```

#### 7.2 Automated Backup Verification

```bash
#!/bin/bash
# Automated backup verification script
echo "=== CNPG Automated Backup Verification ==="

# Configuration
BACKUP_RETENTION_HOURS=24
MINIO_ENDPOINT="http://10.25.11.3:9000"
MINIO_ACCESS_KEY="YOUR_ACCESS_KEY"
MINIO_SECRET_KEY="YOUR_SECRET_KEY"

# Check recent backups
check_recent_backups() {
    echo "Checking backups from last $BACKUP_RETENTION_HOURS hours..."
    
    local cutoff_time=$(date -d "$BACKUP_RETENTION_HOURS hours ago" '+%Y-%m-%dT%H:%M:%SZ')
    
    kubectl get cnpgbackups -n cnpg-system -o json | \
        jq -r ".items[] | select(.status.phase == \"completed\" and .metadata.creationTimestamp > \"$cutoff_time\")"
    
    echo "Backup verification complete"
}

# Verify backup integrity
verify_backup_integrity() {
    local backup_name=$1
    
    echo "Verifying backup integrity: $backup_name"
    
    # Check backup metadata
    kubectl describe cnpgbackup $backup_name -n cnpg-system
    
    # Check MinIO object exists
    mc ls minio/cnpg-backups/shared-postgres/$backup_name
    
    echo "Backup integrity verification complete"
}

# Main execution
echo "1. Checking recent backups"
check_recent_backups

echo "2. Verifying latest backup integrity"
LATEST_BACKUP=$(kubectl get cnpgbackups -n cnpg-system -o json | jq -r '.items[] | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
verify_backup_integrity $LATEST_BACKUP

echo "=== Automated Backup Verification Complete ==="
```

### 8. Integration with Monitoring Stack

#### 8.1 VictoriaMetrics Integration

```bash
#!/bin/bash
# VictoriaMetrics integration for CNPG monitoring
echo "=== CNPG VictoriaMetrics Integration ==="

# Check ServiceMonitor configuration
echo "1. ServiceMonitor Status:"
kubectl get servicemonitor -n cnpg-system -o wide

# Check metrics collection
echo "2. Metrics Collection Test:"
kubectl port-forward svc/victoria-metrics-k8s-stack 8428:8428 -n observability &
sleep 2
curl -s http://localhost:8428/metrics | grep -E "(cnpg|postgres)" | head -10
kill %1  # Kill port-forward

# Check PrometheusRules
echo "3. Alerting Rules:"
kubectl get prometheusrules -n observability | grep -E "(cnpg|postgres)"

# Test Grafana dashboard access
echo "4. Grafana Dashboard Test:"
kubectl port-forward svc/grafana 3000:3000 -n observability &
sleep 2
curl -s http://localhost:3000/api/dashboards/name/cnpg-overview 2>/dev/null
kill %1  # Kill port-forward

echo "=== VictoriaMetrics Integration Complete ==="
```

#### 8.2 Log Aggregation

```bash
#!/bin/bash
# Log aggregation for CNPG
echo "=== CNPG Log Aggregation ==="

# Configure Fluent Bit for CNPG logs
echo "1. Fluent Bit Configuration Check:"
kubectl get configmap fluent-bit -n observability -o yaml | grep -A 20 -B 20 "cnpg"

# Check log collection status
echo "2. Log Collection Status:"
kubectl get pods -n observability -l app.kubernetes.io/name=fluent-bit

# Test log endpoint
echo "3. Log Endpoint Test:"
kubectl port-forward svc/victoria-logs-vmauth 9428:9428 -n observability &
sleep 2
curl -X POST -H 'Content-type: application/json' \
    -d '{"logs":[{"timestamp":"'$(date -Iseconds)'","message":"test log","level":"info"}]' \
    http://localhost:9428/insert
kill %1  # Kill port-forward

# Verify log retention
echo "4. Log Retention Check:"
kubectl get configmap victoria-logs-k8s-stack -n observability -o yaml | grep retention

echo "=== Log Aggregation Complete ==="
```

### 9. Security Operations

#### 9.1 Security Monitoring

```bash
#!/bin/bash
# Security monitoring for CNPG
echo "=== CNPG Security Monitoring ==="

# Check for failed authentication attempts
echo "1. Authentication Failures:"
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -c postgres | \
    grep -i "FATAL\|authentication\|password\|connection" | tail -20

# Check for privilege escalation
echo "2. Privilege Escalation Check:"
kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
SELECT 
    r.rolname,
  r.rolsuper,
  ARRAY_AGG(r.grantee) as grantees
FROM pg_roles r
LEFT JOIN pg_auth_members m ON r.oid = m.roleid
WHERE r.rolsuper = true
  AND r.rolname NOT IN ('postgres', 'cnpg')
ORDER BY r.rolname;"

# Check network policy violations
echo "3. Network Policy Violations:"
kubectl get events -n cnpg-system --field-selector 'reason=NetworkPolicy' | tail -10

# Check certificate issues
echo "4. Certificate Issues:"
kubectl get certificates -n cnpg-system -o json | \
    jq -r '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status == "False"))'

echo "=== Security Monitoring Complete ==="
```

#### 9.2 Access Control Verification

```bash
#!/bin/bash
# Access control verification for CNPG
echo "=== CNPG Access Control Verification ==="

# Verify application user permissions
verify_app_permissions() {
    local app_name=$1
    
    echo "Verifying permissions for $app_name..."
    
    kubectl exec -it shared-postgres-rw-0 -n cnpg-system -- psql -U postgres -c "
    SELECT 
        n.nspname,
        c.relname,
        ARRAY_AGG(p.type) as privileges
    FROM pg_namespace n
    JOIN pg_class c ON n.oid = c.relnamespace
    JOIN pg_auth_members m ON c.relname = m.roleid
    WHERE m.member = '$app_name';"
}

# Check superuser access control
echo "1. Superuser Access Verification:"
kubectl get secret cnpg-superuser -n cnpg-system -o yaml | grep -A 5 "password:"

# Review application roles
echo "2. Application Roles Review:"
kubectl get roles -n cnpg-system -o custom-columns=NAME:.metadata.name,LOGIN:.spec.login,SUPERUSER:.spec.superuser,CREATEDB:.spec.createdb

# Verify network isolation
echo "3. Network Isolation Verification:"
kubectl get networkpolicy -n cnpg-system
kubectl describe networkpolicy deny-all -n cnpg-system

# Test least privilege access
echo "4. Testing Application Access:"
for app in harbor keycloak gitlab; do
    verify_app_permissions $app
done

echo "=== Access Control Verification Complete ==="
```

### 10. Runbook Execution Framework

#### 10.1 Script Execution Environment

```bash
#!/bin/bash
# CNPG Operations execution framework
echo "=== CNPG Operations Framework ==="

# Environment setup
set -euo pipefail  # Exit on any error
export KUBECONFIG="$HOME/.kube/config"

# Logging setup
LOG_DIR="/var/log/cnpg-operations"
mkdir -p $LOG_DIR
exec > >(tee -a "$LOG_DIR/cnpg-ops-$(date +%Y%m%d).log")

# Error handling
trap 'echo "Error occurred at line $LINENO: $BASH_COMMAND"; exit 1' ERR

# Common functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl access
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access cluster"
        exit 1
    fi
    
    # Check CNPG namespace access
    if ! kubectl auth can-i get pods -n cnpg-system &> /dev/null; then
        log_error "Cannot access cnpg-system namespace"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}
```

#### 10.2 Menu-Driven Operations

```bash
#!/bin/bash
# Menu-driven CNPG operations
echo "=== CNPG Operations Menu ==="

show_menu() {
    clear
    echo "CNPG Operations Menu"
    echo "=================="
    echo "1) Health Checks"
    echo "2) Backup Operations"
    echo "3) Performance Monitoring"
    echo "4) User Management"
    echo "5) Troubleshooting"
    echo "6) Security Operations"
    echo "7) Maintenance Tasks"
    echo "8) Exit"
    echo "=================="
}

# Main menu loop
while true; do
    show_menu
    read -p "Select operation [1-8]: " choice
    
    case $choice in
        1) 
            echo "Executing Health Checks..."
            ./cnpg-health-check.sh
            ;;
        2) 
            echo "Executing Backup Operations..."
            ./cnpg-backup-ops.sh
            ;;
        3) 
            echo "Executing Performance Monitoring..."
            ./cnpg-performance-monitor.sh
            ;;
        4) 
            echo "Executing User Management..."
            ./cnpg-user-management.sh
            ;;
        5) 
            echo "Executing Troubleshooting..."
            ./cnpg-troubleshooting.sh
            ;;
        6) 
            echo "Executing Security Operations..."
            ./cnpg-security-ops.sh
            ;;
        7) 
            echo "Executing Maintenance Tasks..."
            ./cnpg-maintenance.sh
            ;;
        8) 
            echo "Exiting CNPG Operations"
            exit 0
            ;;
        *) 
            echo "Invalid choice. Please select 1-8."
            ;;
    esac
    
    echo "Press Enter to continue..."
    read
done
```

---

## Quick Reference

### Essential Commands
```bash
# Cluster status
kubectl get cnpg -n cnpg-system

# Instance status
kubectl get cnpginstances -n cnpg-system -o wide

# Database connection
kubectl port-forward svc/shared-postgres-rw 5432:5432 -n cnpg-system &
psql -h localhost -p 5432 -U postgres

# Backup status
kubectl get cnpgbackups -n cnpg-system

# Role management
kubectl get roles -n cnpg-system

# Certificate status
kubectl get certificates -n cnpg-system
```

### Alert Thresholds
```yaml
# CNPG Alerting Thresholds
performance:
  high_cpu_usage: 80%
  high_memory_usage: 85%
  slow_query_threshold: 1000ms
  connection_threshold: 80%

storage:
  disk_usage_threshold: 85%
  backup_age_threshold: 24h
  wal_growth_threshold: 10GB/hour

availability:
  pod_restart_threshold: 3/hour
  connection_failure_threshold: 5%
  replication_lag_threshold: 10MB

security:
  auth_failure_threshold: 10/hour
  privilege_escalation_alert: immediate
  certificate_expiry_threshold: 7 days
```

### Emergency Contacts
- **Platform Engineering**: platform-team@monosense.io
- **On-Call Engineer**: +1-555-XXX-XXXX
- **Incident Response**: incidents@monosense.io
- **Security Team**: security@monosense.io

---

*This operations runbook should be used in conjunction with the cluster management runbook for comprehensive CNPG administration.*