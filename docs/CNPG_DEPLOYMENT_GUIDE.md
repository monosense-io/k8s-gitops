# CloudNative-PG (CNPG) Deployment Guide

## Current Status

✅ **CNPG Operator**: Deployed via `workloads/platform/databases/cloudnative-pg`
✅ **Configuration**: Defined in `cluster-settings.yaml`
✅ **CNPG Cluster**: Defined but may not be deploying properly
⚠️ **Issue**: Backup validation pod showing `CreateContainerConfigError`

---

## Deployment Architecture

```
workloads/platform/kustomization.yaml (ACTIVE)
  ├─ databases
      ├─ cloudnative-pg/kustomization.yaml
      │   ├─ namespace.yaml (cnpg-system)
      │   ├─ shared-cluster/
      │   │   ├─ cluster.yaml (Cluster CR)
      │   │   ├─ externalsecrets.yaml (1Password secrets)
      │   │   ├─ backup-validation.yaml (CronJob)
      │   │   ├─ scheduledbackup.yaml
      │   │   ├─ services.yaml
      │   │   ├─ prometheusrule.yaml
      │   │   └─ monitoring-configmap.yaml
      │   └─ poolers/
      │       ├─ gitlab-pooler.yaml
      │       ├─ harbor-pooler.yaml
      │       ├─ mattermost-pooler.yaml
      │       ├─ keycloak-pooler.yaml
      │       └─ synergyflow-pooler.yaml
```

---

## Configuration (Already Set in cluster-settings.yaml)

### Storage Configuration
```yaml
CNPG_STORAGE_CLASS: "openebs-local-nvme"  # ✅ Set
CNPG_DATA_SIZE: "80Gi"                    # ✅ Set
CNPG_WAL_SIZE: "20Gi"                     # ✅ Set
```

### External Secrets Configuration
```yaml
EXTERNAL_SECRET_STORE: "onepassword"      # ✅ Set
CNPG_SUPERUSER_SECRET_PATH: "kubernetes/infra/cloudnative-pg/superuser"
CNPG_MINIO_SECRET_PATH: "kubernetes/infra/cloudnative-pg/minio"
```

### MinIO Backup Configuration
```yaml
CNPG_BACKUP_BUCKET: "monosense-cnpg"
CNPG_BACKUP_SCHEDULE: "0 2 * * *"
CNPG_MINIO_ENDPOINT_URL: "http://10.25.11.3:9000"
```

---

## Required Secrets in 1Password

For CNPG to deploy properly, these secrets must exist in 1Password:

### 1. Superuser Credentials
**Path**: `kubernetes/infra/cloudnative-pg/superuser`
**Fields**:
```
username: postgres
password: <strong_random_password>
```

### 2. MinIO Credentials
**Path**: `kubernetes/infra/cloudnative-pg/minio`
**Fields**:
```
accessKey: <minio_access_key>
secretKey: <minio_secret_key>
```

---

## Deployment Steps

### Step 1: Verify External Secrets Setup
```bash
# Check if ExternalSecret is pulling secrets
kubectl describe externalsecret cnpg-superuser -n cnpg-system
kubectl describe externalsecret cnpg-minio-credentials -n cnpg-system

# Check if secrets are created
kubectl get secrets -n cnpg-system | grep cnpg
```

### Step 2: Verify CNPG Operator Deployment
```bash
# Check operator status
kubectl get deployment -n cnpg-system cloudnative-pg
kubectl logs -n cnpg-system deployment/cloudnative-pg -f

# Check for operator errors
kubectl get events -n cnpg-system --sort-by='.lastTimestamp' | tail -20
```

### Step 3: Trigger CNPG Cluster Deployment
```bash
# Force reconciliation of the workload
flux reconcile kustomization cluster-infra-workloads -n flux-system

# Watch CNPG cluster status
kubectl get cluster -n cnpg-system shared-postgres -w

# Describe cluster for errors
kubectl describe cluster shared-postgres -n cnpg-system
```

### Step 4: Monitor Cluster Initialization
```bash
# Check pod status
kubectl get pods -n cnpg-system -l postgresql=shared-postgres

# Watch pod startup
kubectl logs -n cnpg-system shared-postgres-1 -f

# Check instance status
kubectl describe instanceid -n cnpg-system
```

### Step 5: Verify Connection Poolers
```bash
# Check pooler status
kubectl get pooler -n cnpg-system

# List all poolers
kubectl get pods -n cnpg-system -l cnpg.io/pooler

# Check pooler logs
kubectl logs -n cnpg-system gitlab-pooler-1 -f
```

---

## Troubleshooting

### Issue: Backup Validation Pod - CreateContainerConfigError

**Symptoms**:
```
cnpg-backup-validation-29349000-7d4h9  0/1  CreateContainerConfigError
```

**Causes**:
1. ExternalSecrets not pulling credentials
2. MinIO endpoint not accessible
3. Missing environment variables in CronJob

**Solutions**:

```bash
# 1. Check if secrets exist
kubectl get secret cnpg-superuser -n cnpg-system -o yaml
kubectl get secret cnpg-minio-credentials -n cnpg-system -o yaml

# 2. Check external-secrets status
kubectl get externalsecret -n cnpg-system
kubectl describe externalsecret cnpg-minio-credentials -n cnpg-system

# 3. Check CronJob for environment variable issues
kubectl describe cronjob cnpg-backup-validation -n cnpg-system
kubectl get job -n cnpg-system | grep backup-validation

# 4. Check last job logs
kubectl logs -n cnpg-system -l job-name=$(kubectl get job -n cnpg-system --sort-by='.metadata.creationTimestamp' | tail -1 | awk '{print $1}')
```

### Issue: Cluster Pods Not Starting

**Causes**:
1. Storage class not available
2. PVCs not binding
3. Operator errors

**Solutions**:

```bash
# Check storage class exists
kubectl get storageclass openebs-local-nvme

# Check PVC status
kubectl get pvc -n cnpg-system
kubectl describe pvc shared-postgres-1 -n cnpg-system

# Check operator logs
kubectl logs -n cnpg-system deployment/cloudnative-pg | grep -i error
```

### Issue: ExternalSecrets Not Pulling from 1Password

**Causes**:
1. 1Password Connect not configured
2. Secret path wrong in 1Password
3. Credentials expired

**Solutions**:

```bash
# Check external-secrets controller
kubectl logs -n external-secrets deployment/external-secrets -f

# Verify ClusterSecretStore
kubectl get clustersecretstore onepassword -o yaml

# Check 1Password Connect connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://opconnect.monosense.dev:8080/health
```

---

## Expected Deployment Timeline

Once all configuration is correct:

| Time | Component | Status |
|------|-----------|--------|
| T+0s | Flux reconciles workloads | Starts deployment |
| T+15s | CNPG Operator pods | Running |
| T+30s | ExternalSecrets pull | Secrets created |
| T+45s | Cluster CR created | Operator processes |
| T+60s | Primary pod initializes | PostInitSQL runs |
| T+90s | Replicas join cluster | HA configured |
| T+120s | Poolers connect | Services ready |
| T+180s | Full convergence | All healthy ✓ |

---

## Verification Checklist

```bash
# Run these commands to verify deployment

echo "=== Operator Status ==="
kubectl get deployment -n cnpg-system cloudnative-pg
kubectl get pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

echo "=== Cluster Status ==="
kubectl get cluster -n cnpg-system
kubectl get pods -n cnpg-system -l postgresql=shared-postgres

echo "=== Pooler Status ==="
kubectl get pooler -n cnpg-system
kubectl get pods -n cnpg-system -l cnpg.io/pooler

echo "=== Secrets Status ==="
kubectl get secrets -n cnpg-system

echo "=== ExternalSecrets Status ==="
kubectl get externalsecrets -n cnpg-system
kubectl get secretstore -n cnpg-system

echo "=== Cluster Details ==="
kubectl describe cluster shared-postgres -n cnpg-system
```

---

## CNPG Resources

- **Cluster**: `shared-postgres` - 3-node PostgreSQL cluster
- **Poolers**:
  - `gitlab-pooler` - For GitLab database connections
  - `harbor-pooler` - For Harbor/Registry database connections
  - `mattermost-pooler` - For Mattermost database connections
  - `keycloak-pooler` - For Keycloak database connections
  - `synergyflow-pooler` - For SynergyFlow database connections

## Connection Details

Once deployed, applications connect via PgBouncer poolers:

```
Application → PgBouncer Pooler (port 5432) → Shared PostgreSQL Cluster
```

Example connection string:
```
postgresql://gitlab:password@gitlab-pooler-rw.cnpg-system.svc.cluster.local:5432/gitlab
```

---

## Database Extensions Installed

The CNPG cluster auto-installs these extensions on initialization:

### Monitoring
- `pg_stat_statements` - Query statistics
- `pgaudit` - Audit logging

### GitLab Required
- `pg_trgm` - Text similarity and trigram indexing
- `btree_gist` - GiST indexing for common datatypes
- `plpgsql` - PL/pgSQL procedural language
- `amcheck` - Relation integrity verification

### Harbor
- `uuid-ossp` - UUID generation

---

## Next Steps

1. **Verify 1Password secrets exist** at specified paths
2. **Check MinIO connectivity** to `http://10.25.11.3:9000`
3. **Monitor deployment** with `kubectl get pods -n cnpg-system -w`
4. **Verify cluster health** with `kubectl get cluster -n cnpg-system -o wide`
5. **Test pooler connections** from applications

---

## Related Files

- Configuration: `/kubernetes/clusters/infra/cluster-settings.yaml`
- Deployment: `/kubernetes/workloads/platform/databases/cloudnative-pg/`
- Operator: `/kubernetes/bases/cloudnative-pg/`
