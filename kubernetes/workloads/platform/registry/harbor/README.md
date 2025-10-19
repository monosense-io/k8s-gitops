# Harbor Private Container Registry

Production-ready Harbor private container registry deployment for the infra cluster, providing secure Docker image storage, vulnerability scanning with Trivy, and content trust with Notary.

## Overview

Harbor is deployed with:
- **High Availability**: 2 replicas for all components
- **External PostgreSQL**: CloudNative-PG cluster (3 instances)
- **External Redis**: DragonflyDB (shared with other services)
- **Persistent Storage**: Rook-Ceph block storage (200GB for registry images)
- **Security Scanning**: Trivy vulnerability scanner
- **Content Trust**: Notary for image signing
- **Metrics**: Prometheus metrics for Victoria Metrics

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Infra Cluster - Harbor                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────────────────────────────────────────────┐     │
│  │            Harbor Namespace                            │     │
│  ├───────────────────────────────────────────────────────┤     │
│  │  • Portal (UI) - 2 replicas                           │     │
│  │  • Core (API) - 2 replicas                            │     │
│  │  • Registry - 2 replicas                              │     │
│  │  • JobService - 2 replicas                            │     │
│  │  • Trivy Scanner - 1 replica                          │     │
│  │  • Notary Server - 1 replica                          │     │
│  │  • Notary Signer - 1 replica                          │     │
│  │  ─────────────────────────────────────────────────    │     │
│  │  • PostgreSQL (CloudNative-PG) - 3 instances          │     │
│  │    - registry DB                                       │     │
│  │    - notary_server DB                                  │     │
│  │    - notary_signer DB                                  │     │
│  │  • DragonflyDB (shared, namespace: dragonfly)         │     │
│  │  • Persistent Storage (200GB, rook-ceph-block)        │     │
│  └───────────────────────────────────────────────────────┘     │
│                           │                                      │
│                           │ HTTPS (via Envoy Gateway)           │
│                           ▼                                      │
│                  harbor.monosense.io                             │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Core Components

| Component | Replicas | Purpose | Resources (Request/Limit) |
|-----------|----------|---------|---------------------------|
| Portal | 2 | Web UI | 100m/500m CPU, 256Mi/512Mi RAM |
| Core | 2 | API server | 250m/1000m CPU, 512Mi/1Gi RAM |
| Registry | 2 | Image storage backend | 250m/1000m CPU, 512Mi/1Gi RAM |
| JobService | 2 | Asynchronous jobs | 250m/1000m CPU, 512Mi/1Gi RAM |
| Trivy | 1 | Vulnerability scanning | 200m/1000m CPU, 512Mi/1Gi RAM |
| Notary Server | 1 | Content trust server | 100m/500m CPU, 256Mi/512Mi RAM |
| Notary Signer | 1 | Content trust signing | 100m/500m CPU, 256Mi/512Mi RAM |

### Database Components

- **PostgreSQL**: CloudNative-PG cluster (3 instances)
  - Database: `registry` (Harbor core)
  - Database: `notary_server` (Notary server)
  - Database: `notary_signer` (Notary signer)
  - Storage: 30GB per instance
  - Backup: S3 with 30-day retention

- **Redis**: DragonflyDB (external, shared)
  - Database 1: Core cache
  - Database 2: JobService queue
  - Database 3: Registry cache
  - Database 4: Trivy cache

## Deployment

### Prerequisites

- Infra cluster with:
  - CloudNative-PG operator
  - DragonflyDB deployed
  - Rook-Ceph storage provider
  - External Secrets Operator
  - Victoria Metrics (for monitoring)
- Vault secrets configured
- DNS record for `harbor.monosense.io`

### Secrets Required

Store these secrets in Vault:

```bash
# Harbor admin password
vault kv put harbor/core \
  admin_password="<strong-password>" \
  secret_key="<random-secret-32chars>"

# Harbor registry HTTP secret
vault kv put harbor/registry \
  http_secret="<random-secret-32chars>"

# PostgreSQL password
vault kv put postgresql/harbor \
  password="<strong-password>"

# S3 backup credentials
vault kv put s3/backup \
  access_key_id="<aws-access-key>" \
  secret_access_key="<aws-secret-key>"
```

### Deployment Options

#### Option 1: GitOps with Flux (Recommended)

```bash
# Apply Flux Kustomization
kubectl apply -f /Users/monosense/iac/k8s-gitops/kubernetes/clusters/infra/harbor.yaml

# Monitor deployment
flux get kustomizations -n flux-system | grep harbor
kubectl get helmrelease -n harbor
kubectl get pods -n harbor -w
```

#### Option 2: Manual Deployment

```bash
# Deploy manifests
kubectl apply -k /Users/monosense/iac/k8s-gitops/kubernetes/workloads/platform/registry/harbor

# Wait for PostgreSQL
kubectl wait --for=condition=Ready cluster/harbor-db -n harbor --timeout=600s

# Wait for Harbor
kubectl wait --for=condition=Ready helmrelease/harbor -n harbor --timeout=900s
```

### Verification

```bash
# Check all components
kubectl get all -n harbor

# Check PostgreSQL cluster
kubectl get cluster -n harbor

# Check HelmRelease status
kubectl describe helmrelease harbor -n harbor

# Check logs
kubectl logs -n harbor -l app=harbor,component=core --tail=50
kubectl logs -n harbor -l app=harbor,component=registry --tail=50
```

## Configuration

### Access Harbor

**URL**: https://harbor.monosense.io

**Default Credentials**:
- Username: `admin`
- Password: Stored in Vault at `harbor/core/admin_password`

### Create Robot Account for SynergyFlow

1. Login to Harbor UI
2. Navigate to Projects → Create Project → `synergyflow`
3. Go to Project → Robot Accounts → New Robot Account
4. Name: `synergyflow-puller`
5. Permissions: Pull, Push
6. Save credentials to Vault:

```bash
vault kv put harbor/robot-accounts/synergyflow \
  username="robot$synergyflow-puller" \
  password="<generated-token>"
```

### Push Images to Harbor

```bash
# Login to Harbor
docker login harbor.monosense.io -u admin

# Tag image
docker tag synergyflow-backend:latest harbor.monosense.io/synergyflow/backend:latest

# Push image
docker push harbor.monosense.io/synergyflow/backend:latest
```

### Use Harbor in Kubernetes

The SynergyFlow deployment is already configured to pull from Harbor:

```yaml
spec:
  imagePullSecrets:
    - name: harbor-registry-secret
  containers:
    - name: synergyflow
      image: harbor.monosense.io/synergyflow/backend:latest
```

The `harbor-registry-secret` is automatically created from Vault via External Secrets Operator.

## Features

### Vulnerability Scanning with Trivy

Harbor automatically scans all pushed images with Trivy:

1. Push image to Harbor
2. Harbor triggers Trivy scan
3. View scan results in Harbor UI
4. Set policies to prevent vulnerable images from being pulled

### Content Trust with Notary

Enable Docker Content Trust to sign and verify images:

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://harbor.monosense.io:4443

# Push signed image
docker push harbor.monosense.io/synergyflow/backend:v1.0.0

# Pull will verify signature
docker pull harbor.monosense.io/synergyflow/backend:v1.0.0
```

### Replication

Set up replication to mirror images to other registries:

1. Harbor UI → Administration → Replications
2. Create replication rule
3. Configure source/destination
4. Set trigger (manual, scheduled, event-based)

### Webhooks

Configure webhooks for CI/CD integration:

1. Harbor UI → Project → Webhooks
2. Add webhook endpoint
3. Select events (push, pull, scan complete, etc.)
4. Harbor will POST events to your endpoint

## Monitoring

### Metrics

Harbor exposes Prometheus metrics on multiple components:

- **Core**: `http://<core-pod>:8001/metrics`
- **Registry**: `http://<registry-pod>:8001/metrics`
- **JobService**: `http://<jobservice-pod>:8001/metrics`
- **Exporter**: `http://<exporter-pod>:8001/metrics`

ServiceMonitors are configured for automatic scraping by Victoria Metrics.

### Key Metrics

- `harbor_project_total` - Total number of projects
- `harbor_repo_total` - Total number of repositories
- `harbor_artifact_total` - Total number of artifacts (images)
- `harbor_quota_usage_bytes` - Storage quota usage
- `harbor_task_queue_size` - Job queue size
- `harbor_task_scheduled_total` - Total scheduled tasks

### Dashboards

Import Harbor Grafana dashboards from:
- https://github.com/goharbor/harbor/tree/main/contrib/grafana-dashboards

## Backup and Recovery

### Automatic PostgreSQL Backups

PostgreSQL backups are automated via CloudNative-PG:
- **Schedule**: Continuous WAL archiving + daily full backups
- **Retention**: 30 days
- **Storage**: S3-compatible storage
- **Encryption**: AES256

### Manual Backup

```bash
# Trigger manual PostgreSQL backup
kubectl create -n harbor backup harbor-db-manual-$(date +%Y%m%d-%H%M%S) --from=harbor-db

# Verify backup
kubectl get backup -n harbor
```

### Registry Data Backup

Registry images are stored in persistent volumes:

```bash
# List PVCs
kubectl get pvc -n harbor

# Backup PVC using velero or volumesnapshot
velero backup create harbor-registry-backup --include-namespaces=harbor --include-resources=pvc,pv
```

### Recovery

Follow CloudNative-PG recovery procedures:

```bash
# Create recovery cluster
kubectl apply -f harbor-db-restore.yaml
```

## Troubleshooting

### Harbor Pods Not Starting

```bash
# Check HelmRelease status
kubectl describe helmrelease harbor -n harbor

# Check events
kubectl get events -n harbor --sort-by='.lastTimestamp'

# Check PostgreSQL connectivity
kubectl exec -n harbor <harbor-core-pod> -- \
  pg_isready -h harbor-db-rw.harbor.svc.cluster.local -p 5432
```

### Login Issues

```bash
# Reset admin password (from database)
kubectl exec -n harbor harbor-db-1 -- \
  psql -U harbor -d registry -c \
  "UPDATE harbor_user SET password='<new-bcrypt-hash>', salt='<new-salt>' WHERE username='admin';"
```

### Image Push/Pull Failures

```bash
# Check registry logs
kubectl logs -n harbor -l app=harbor,component=registry --tail=100

# Check storage
kubectl get pvc -n harbor
kubectl describe pvc harbor-registry -n harbor

# Test registry endpoint
kubectl run curl-test --rm -it --image=curlimages/curl:latest --restart=Never -- \
  curl -v http://harbor-registry.harbor.svc.cluster.local:5000/v2/
```

### Trivy Scan Failures

```bash
# Check Trivy logs
kubectl logs -n harbor -l app=harbor,component=trivy --tail=100

# Check Trivy database updates
kubectl exec -n harbor <trivy-pod> -- trivy --version
kubectl exec -n harbor <trivy-pod> -- trivy image --download-db-only
```

## Performance Tuning

### Registry Configuration

For high-throughput scenarios, consider:

```yaml
# In helmrelease.yaml
registry:
  replicas: 4  # Increase replicas
  resources:
    requests:
      cpu: "1"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "4Gi"
```

### Database Tuning

For large deployments, tune PostgreSQL:

```yaml
# In postgres-cluster.yaml
postgresql:
  parameters:
    max_connections: "200"
    shared_buffers: "512MB"
    effective_cache_size: "1536MB"
```

### Storage Performance

Use faster storage class for registry PVC:

```yaml
# In helmrelease.yaml
persistence:
  persistentVolumeClaim:
    registry:
      storageClass: rook-ceph-block-fast  # Use faster storage
      size: 500Gi  # Increase size for larger deployments
```

## Resource Requirements

### Minimum Resources

- **CPU**: ~3 cores (requests), ~8 cores (limits)
- **Memory**: ~4 GiB (requests), ~8 GiB (limits)
- **Storage**: ~240 GiB (200GB registry + 30GB database + 10GB logs)

### Production Recommendations

- **CPU**: ~6 cores (requests), ~16 cores (limits)
- **Memory**: ~8 GiB (requests), ~16 GiB (limits)
- **Storage**: ~500+ GiB depending on image count

## Security

### Authentication

- **Local Users**: Username/password stored in PostgreSQL
- **OIDC/LDAP**: Configure via Harbor UI → Administration → Authentication
- **Robot Accounts**: Service accounts for CI/CD

### Authorization

- **Projects**: Logical grouping of repositories
- **RBAC**: Project Admin, Master, Developer, Guest roles
- **Robot Accounts**: Fine-grained permissions per project

### Network Policies

Harbor pods are isolated via Kubernetes NetworkPolicies:
- Ingress only from Envoy Gateway
- Egress to PostgreSQL, DragonflyDB, Internet (for Trivy DB updates)

### TLS

- **External TLS**: Terminated at Envoy Gateway
- **Internal**: Plain HTTP within cluster (trusted network)

## Integration

### CI/CD Pipelines

**GitHub Actions Example**:

```yaml
- name: Build and push to Harbor
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: harbor.monosense.io/synergyflow/backend:${{ github.sha }}
    build-args: |
      VERSION=${{ github.sha }}
```

**GitLab CI Example**:

```yaml
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login harbor.monosense.io -u $HARBOR_USER -p $HARBOR_PASSWORD
    - docker build -t harbor.monosense.io/synergyflow/backend:$CI_COMMIT_SHA .
    - docker push harbor.monosense.io/synergyflow/backend:$CI_COMMIT_SHA
```

### Kubernetes Integration

All Kubernetes workloads can pull from Harbor using imagePullSecrets:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  imagePullSecrets:
    - name: harbor-registry-secret
  containers:
    - name: app
      image: harbor.monosense.io/my-project/my-app:latest
```

## Maintenance

### Garbage Collection

Harbor automatically runs garbage collection to free storage:

1. Harbor UI → Administration → Garbage Collection
2. Schedule: Daily at 2 AM UTC
3. Dry run first to see what will be deleted

### Database Maintenance

PostgreSQL maintenance is automated via CloudNative-PG:
- **Autovacuum**: Enabled
- **Statistics**: Collected automatically
- **Logs**: Rotated daily

### Upgrade Harbor

```bash
# Update Helm chart version in helmrelease.yaml
# Flux will automatically upgrade

# Monitor upgrade
kubectl get helmrelease harbor -n harbor -w
kubectl rollout status deployment -n harbor
```

## References

- [Harbor Official Docs](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Notary Documentation](https://github.com/notaryproject/notary)
- [CloudNative-PG Documentation](https://cloudnative-pg.io/documentation/)

## Support

For issues or questions:
- Harbor Issues: https://github.com/goharbor/harbor/issues
- Internal Support: Contact platform team
