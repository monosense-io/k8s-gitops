# GitLab Deployment

GitLab Community Edition deployment on Kubernetes with external PostgreSQL (CloudNative-PG), Redis (Dragonfly), and object storage (MinIO).

## Architecture Overview

```
GitLab Components
├── Webservice (2 replicas) → Rails application
├── Sidekiq (1 replica) → Background job processor
├── Gitaly (1 replica) → Git repository storage
├── GitLab Shell → SSH access
└── Migrations → Database initialization

External Dependencies
├── PostgreSQL: postgres-rw.databases.svc.cluster.local:5432
│   └── Database: gitlab (with pg_trgm, btree_gist extensions)
├── Redis: gitlab-dragonfly.selfhosted.svc.cluster.local:6379
│   └── Dragonfly cluster with emulated cluster mode
├── MinIO: minio.storage.svc.cluster.local:9000
│   ├── gitlab-artifacts (CI/CD artifacts)
│   ├── gitlab-lfs (Large files)
│   ├── gitlab-uploads (Avatars, attachments)
│   ├── gitlab-packages (Package registry)
│   ├── gitlab-backups (Backups)
│   ├── gitlab-terraform-state (Terraform state)
│   └── gitlab-dependency-proxy (Dependency proxy cache)
└── Gateway API: envoy-external → git.monosense.dev
```

## Prerequisites

### 1. Create MinIO Buckets

Before deploying GitLab, create the required S3 buckets in MinIO:

```bash
# Access MinIO console at https://console.monosense.dev
# Or use mc CLI:
mc alias set myminio https://s3.monosense.dev <access-key> <secret-key>

mc mb myminio/gitlab-artifacts
mc mb myminio/gitlab-lfs
mc mb myminio/gitlab-uploads
mc mb myminio/gitlab-packages
mc mb myminio/gitlab-backups
mc mb myminio/gitlab-terraform-state
mc mb myminio/gitlab-dependency-proxy
mc mb myminio/gitlab-tmp
```

### 2. Configure OnePassword Secrets

Create a vault in OnePassword named `dev-gitlab` with the following fields:

```yaml
# Required secrets
GITLAB_ROOT_PASSWORD: <strong-password-for-root-user>
GITLAB_SHELL_SECRET: <64-char-hex-string>
GITLAB_RAILS_SECRET: <128-char-hex-string>
GITLAB_GITALY_TOKEN: <random-secure-token>
GITLAB_WORKHORSE_SECRET: <random-secure-token>

# Optional (for Container Registry if enabling later)
GITLAB_REGISTRY_HTTP_SECRET: <random-secret>
GITLAB_REGISTRY_NOTIFICATION_SECRET: <random-secret>
```

Generate secure random values:
```bash
# Shell secret (64 chars hex)
openssl rand -hex 32

# Rails secret (128 chars hex)
openssl rand -hex 64

# Gitaly token (base64, 32 bytes)
openssl rand -base64 32

# Workhorse secret (base64, 32 bytes)
openssl rand -base64 32
```

Also ensure your `dev-minio` vault in OnePassword has:
```yaml
MINIO_ACCESS_KEY: <your-minio-access-key>
MINIO_SECRET_KEY: <your-minio-secret-key>
```

### 3. PostgreSQL Configuration

The CloudNative-PG component will automatically:
- Create a database named `gitlab`
- Create user credentials
- Generate init and user secrets

Ensure PostgreSQL has required extensions (should be included by default):
- `pg_trgm` - Trigram matching for fuzzy search
- `btree_gist` - For exclusion constraints
- `plpgsql` - Procedural language

### 4. DNS Configuration

Configure DNS records:
```
git.monosense.dev     → Envoy Gateway External IP
registry.monosense.dev → Envoy Gateway External IP (if enabling registry)
```

## Deployment

### 1. Enable GitLab in FluxCD

Uncomment the GitLab entry in the selfhosted kustomization:

```bash
# Edit kubernetes/apps/selfhosted/kustomization.yaml
# Change:
#   # - ./gitlab/ks.yaml
# To:
#   - ./gitlab/ks.yaml
```

### 2. Commit and Push

```bash
git add .
git commit -m "feat: add GitLab deployment"
git push
```

### 3. Monitor Deployment

```bash
# Watch FluxCD reconciliation
flux get kustomizations -n flux-system

# Watch GitLab resources
watch kubectl get pods -n selfhosted -l app.kubernetes.io/name=gitlab

# Check HelmRelease status
kubectl get helmrelease -n selfhosted gitlab

# View GitLab logs
kubectl logs -n selfhosted -l app=webservice --tail=100 -f
```

### 4. Initial Setup

GitLab will take 10-15 minutes to fully deploy. Once ready:

1. **Access GitLab**: https://git.monosense.dev
2. **Login**:
   - Username: `root`
   - Password: From `GITLAB_ROOT_PASSWORD` in OnePassword
3. **Change password** (recommended)
4. **Configure settings** in Admin Area

## Post-Installation Configuration

### 1. Configure SMTP (Email)

Edit `helmrelease.yaml` and add to `global.smtp`:

```yaml
global:
  smtp:
    enabled: true
    address: smtp.gmail.com
    port: 587
    user_name: your-email@gmail.com
    password:
      secret: gitlab-smtp-password
      key: password
    domain: gmail.com
    authentication: login
    starttls_auto: true
```

Create SMTP secret in OnePassword and update externalsecret.yaml.

### 2. Enable Container Registry

In `helmrelease.yaml`, change:
```yaml
registry:
  enabled: true
  storage:
    secret: gitlab-minio-secret
    key: connection
  httpSecret:
    secret: gitlab-registry-secret
    key: registry-http-secret
```

Uncomment the registry HTTPRoute in `httproute.yaml`.

### 3. Configure Authentik SSO (OIDC)

1. Create OAuth2/OIDC provider in Authentik
2. Configure GitLab OIDC in `helmrelease.yaml`:

```yaml
global:
  appConfig:
    omniauth:
      enabled: true
      allowSingleSignOn: ['openid_connect']
      blockAutoCreatedUsers: false
      providers:
        - secret: gitlab-authentik-secret
```

### 4. Deploy GitLab Runner

Create a separate deployment for GitLab Runner:
```bash
mkdir -p kubernetes/apps/selfhosted/gitlab-runner/app
# Add HelmRelease for gitlab-runner chart
```

### 5. Configure Monitoring

ServiceMonitors are automatically created. Verify metrics in Grafana:
- GitLab Webservice metrics
- Sidekiq queue metrics
- Gitaly performance metrics
- GitLab Shell metrics

### 6. Set up Backups

Configure backup schedule in `helmrelease.yaml`:

```yaml
global:
  appConfig:
    backups:
      bucket: gitlab-backups
      tmpBucket: gitlab-tmp
    cron_jobs:
      backup_create_schedule:
        cron: "0 2 * * *"  # Daily at 2 AM
```

Or use external backup tool (Velero recommended):
```bash
velero backup create gitlab-backup \
  --include-namespaces selfhosted \
  --selector app.kubernetes.io/name=gitlab
```

## Troubleshooting

### Check Component Health

```bash
# Overall status
kubectl get pods -n selfhosted -l app.kubernetes.io/name=gitlab

# Migrations status
kubectl logs -n selfhosted -l app=migrations

# Database connectivity
kubectl exec -n selfhosted deploy/gitlab-webservice-default -- \
  gitlab-rake gitlab:db:check

# Redis connectivity
kubectl exec -n selfhosted deploy/gitlab-webservice-default -- \
  gitlab-rake gitlab:redis:check

# Object storage connectivity
kubectl exec -n selfhosted deploy/gitlab-webservice-default -- \
  gitlab-rake gitlab:lfs:check
```

### Common Issues

**1. Migrations Timeout**
```bash
# Increase timeout in ks.yaml
timeout: 15m

# Check migrations logs
kubectl logs -n selfhosted -l app=migrations --tail=200
```

**2. Webservice CrashLoopBackOff**
```bash
# Check logs
kubectl logs -n selfhosted -l app=webservice --tail=100

# Common causes:
# - Database not ready → Check CNPG cluster
# - Redis not ready → Check Dragonfly cluster
# - Secrets missing → Check ExternalSecrets
# - Object storage misconfigured → Check MinIO access
```

**3. Object Storage Connection Errors**
```bash
# Verify MinIO connectivity from pod
kubectl exec -n selfhosted deploy/gitlab-webservice-default -- \
  curl -v http://minio.storage.svc.cluster.local:9000

# Verify S3 credentials
kubectl get secret -n selfhosted gitlab-minio-secret -o yaml
```

**4. SSH Not Working**
```bash
# Check GitLab Shell service
kubectl get svc -n selfhosted -l app=gitlab-shell

# Test SSH connectivity
ssh -T git@git.monosense.dev -p 22
```

**5. Performance Issues**
```bash
# Scale webservice replicas
kubectl scale -n selfhosted deploy/gitlab-webservice-default --replicas=3

# Scale sidekiq workers
kubectl scale -n selfhosted deploy/gitlab-sidekiq-all-in-1-v2 --replicas=2

# Check resource usage
kubectl top pods -n selfhosted -l app.kubernetes.io/name=gitlab
```

### Database Maintenance

```bash
# Run database migrations manually
kubectl exec -n selfhosted deploy/gitlab-toolbox -- \
  gitlab-rake db:migrate

# Check database size
kubectl exec -n databases postgres-1 -- \
  psql -U gitlab -d gitlab -c "SELECT pg_size_pretty(pg_database_size('gitlab'));"

# Vacuum and analyze
kubectl exec -n selfhosted deploy/gitlab-toolbox -- \
  gitlab-rake gitlab:cleanup:orphan_job_artifact_files
```

## Scaling Recommendations

### For Light Usage (< 10 users)
- Current configuration is sufficient
- Webservice: 2 replicas
- Sidekiq: 1 replica

### For Medium Usage (10-50 users)
```yaml
gitlab:
  webservice:
    replicas: 3
    resources:
      requests:
        cpu: 1500m
        memory: 2Gi
  sidekiq:
    replicas: 2
    resources:
      requests:
        cpu: 750m
        memory: 1536Mi
  gitaly:
    persistence:
      size: 250Gi  # Increase storage
```

### For Heavy Usage (50+ users)
- Enable Praefect for Gitaly HA
- Scale webservice to 4+ replicas
- Multiple Sidekiq deployments by queue
- Consider dedicated Redis instances
- Increase Gitaly storage to 500Gi+

## Resource Requirements

**Minimum**:
- CPU: ~3 cores
- RAM: ~6 GB
- Storage: 100 GB (Gitaly)

**Recommended**:
- CPU: ~5 cores
- RAM: ~10 GB
- Storage: 250 GB (Gitaly)

## Security Considerations

1. **Change default passwords** immediately after deployment
2. **Enable 2FA** for all admin users
3. **Configure rate limiting** (enabled by default)
4. **Regular security updates**: Monitor GitLab security advisories
5. **Backup encryption**: Enable backup encryption in MinIO
6. **Network policies**: Consider adding NetworkPolicies for pod isolation
7. **Audit logs**: Enable audit logging in Admin settings

## Maintenance

### Upgrade GitLab

1. Check [GitLab upgrade path](https://docs.gitlab.com/ee/update/#upgrade-paths)
2. Update chart version in `helmrelease.yaml`
3. Commit and push - FluxCD will handle the upgrade
4. Monitor the upgrade process

```bash
# Watch upgrade
kubectl logs -n selfhosted -l app=migrations -f

# Verify version after upgrade
kubectl exec -n selfhosted deploy/gitlab-webservice-default -- \
  gitlab-rake gitlab:env:info
```

### Backup Schedule

Automated daily backups to MinIO (gitlab-backups bucket):
- **Daily**: Full backup at 2 AM
- **Retention**: 7 days (configurable)
- **Location**: s3://gitlab-backups/

Manual backup:
```bash
kubectl exec -n selfhosted deploy/gitlab-toolbox -- \
  backup-utility --skip=registry
```

### Restore from Backup

```bash
# List available backups
kubectl exec -n selfhosted deploy/gitlab-toolbox -- \
  backup-utility --list

# Restore specific backup
kubectl exec -n selfhosted deploy/gitlab-toolbox -- \
  backup-utility --restore BACKUP_ID
```

## Monitoring and Observability

### Metrics

Prometheus ServiceMonitors are configured for:
- **Webservice**: `/metrics` endpoint
- **Sidekiq**: Job queue metrics
- **Gitaly**: Git operation metrics
- **Shell**: SSH connection metrics

Import Grafana dashboards:
- GitLab Overview
- GitLab Gitaly
- GitLab Sidekiq

### Logs

Centralized logging via Victoria Logs:
```bash
# Query logs in Grafana
{namespace="selfhosted", app="webservice"}
```

### Alerting

Key alerts to configure:
- Pod restarts > 3 in 10 minutes
- Database connection failures
- Redis connection failures
- High memory/CPU usage
- Backup failures
- Certificate expiration

## References

- [GitLab Helm Chart Documentation](https://docs.gitlab.com/charts/)
- [GitLab Architecture](https://docs.gitlab.com/ee/development/architecture.html)
- [External PostgreSQL Configuration](https://docs.gitlab.com/charts/advanced/external-db/)
- [External Redis Configuration](https://docs.gitlab.com/charts/advanced/external-redis/)
- [External Object Storage Configuration](https://docs.gitlab.com/charts/advanced/external-object-storage/)
- [GitLab Maintenance](https://docs.gitlab.com/ee/administration/)

## Support

For issues specific to this deployment, check:
1. FluxCD reconciliation status
2. Component readiness (PostgreSQL, Dragonfly, MinIO)
3. ExternalSecret synchronization
4. GitLab component logs

For GitLab-specific issues, consult:
- [GitLab Community Forum](https://forum.gitlab.com/)
- [GitLab Documentation](https://docs.gitlab.com/)
- [GitLab Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues)
