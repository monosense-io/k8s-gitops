# GitLab Self-Managed with External State

## Overview

Self-managed GitLab CE deployed on the apps cluster with external dependencies:

- **Database**: PostgreSQL via CNPG pooler (`gitlab-pooler-rw.cnpg-system`)
- **Cache**: DragonflyDB Redis-compatible (`dragonfly.dragonfly-system`)
- **Object Storage**: External MinIO (http://10.25.11.3:9000)
- **SSO**: Keycloak OIDC on infra cluster (sso.monosense.io)
- **Ingress**: Gateway API with Cilium + Let's Encrypt TLS
- **CI/CD**: GitLab Runner with Kaniko (rootless builds)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Apps Cluster                            │
│                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐│
│  │   Gateway    │────▶│    GitLab    │────▶│  CNPG Pooler ││
│  │   (Cilium)   │     │  (18.5.1)    │     │ (PostgreSQL) ││
│  │              │     │              │     │              ││
│  └──────────────┘     └──────┬───────┘     └──────────────┘│
│                              │                              │
│                       ┌──────▼────────┐                     │
│                       │   Dragonfly   │                     │
│                       │   (Redis)     │                     │
│                       └───────────────┘                     │
│                                                             │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │ GitLab Runner│────▶ Kaniko Jobs ─────▶│   Container  │  │
│  │ (Kubernetes) │     (rootless builds)  │   Registry   │  │
│  │              │                        │              │  │
│  └──────────────┘                        └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
          ┌───────────────────────────────────────┐
          │  External MinIO (10.25.11.3:9000)     │
          │  - gitlab-artifacts (CI/CD artifacts) │
          │  - gitlab-lfs (Git LFS objects)       │
          │  - gitlab-uploads (user uploads)      │
          │  - gitlab-packages (package registry) │
          │  - gitlab-registry (container images) │
          │  - gitlab-cache (runner cache)        │
          └───────────────────────────────────────┘
```

## Components

### GitLab (gitlab-system namespace)
- **Webservice**: 2 replicas (Rails application)
- **Sidekiq**: 1 replica (background jobs)
- **Gitaly**: 1 replica (Git repository storage, 50Gi PVC)
- **Registry**: 1 replica (container registry)
- **Shell**: 1 replica (Git SSH access)
- **Toolbox**: 1 replica (admin CLI)

### GitLab Runner (gitlab-runner namespace)
- **Manager**: 1 replica (Kubernetes executor)
- **Executor**: Kaniko (rootless container builds)
- **Concurrency**: 10 jobs
- **Tags**: `kubernetes`, `kaniko`, `apps-cluster`

## External Dependencies

### 1. PostgreSQL (CNPG Pooler)

**Service**: `gitlab-pooler-rw.cnpg-system.svc.cluster.local:5432`
**Database**: `gitlab`
**User**: `gitlab_app`
**Pool Mode**: Transaction
**Connections**: 300 max, 25 pool size

**Secret**: `kubernetes/apps/gitlab/db` (1Password)
**Keys**: `host`, `port`, `database`, `username`, `password`

**Test**:
```bash
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc \
  "psql 'host=gitlab-pooler-rw.cnpg-system.svc.cluster.local dbname=gitlab user=gitlab_app sslmode=require' -c 'SELECT 1'"
```

### 2. Redis (DragonflyDB)

**Service**: `dragonfly.dragonfly-system.svc.cluster.local:6379`
**Version**: v1.34.2 (Redis 7.x API compatible)

**Secret**: `kubernetes/apps/gitlab/redis` (1Password)
**Keys**: `host`, `port`, `password`

**Test**:
```bash
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc \
  "redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping"
```

### 3. S3 Object Storage (MinIO)

**Endpoint**: `http://10.25.11.3:9000`
**Region**: `us-east-1`

**Buckets Required**:
- `gitlab-artifacts` - CI/CD job artifacts
- `gitlab-lfs` - Git LFS objects
- `gitlab-uploads` - User uploads (issues, MRs)
- `gitlab-packages` - Package registry (npm, Maven, etc.)
- `gitlab-registry` - Container registry images
- `gitlab-cache` - Runner build cache

**Secret**: `kubernetes/apps/gitlab/s3` (1Password)
**Keys**: `endpoint`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`

**Test**:
```bash
# Install AWS CLI if needed
aws configure set aws_access_key_id <key>
aws configure set aws_secret_access_key <secret>

# List buckets
aws --endpoint-url http://10.25.11.3:9000 s3 ls
```

### 4. Keycloak OIDC (Infra Cluster)

**Issuer**: `https://sso.monosense.io/realms/master`
**Client ID**: `gitlab`
**Redirect URI**: `https://gitlab.apps.monosense.io/users/auth/openid_connect/callback`

**Secret**: `kubernetes/apps/gitlab/oidc` (1Password)
**Keys**: `client_id`, `client_secret`

**Required Keycloak Configuration**:
1. Create confidential client `gitlab` in `master` realm
2. Enable Standard Flow + Direct Access Grants
3. Set redirect URI: `https://gitlab.apps.monosense.io/users/auth/openid_connect/callback`
4. Set Web Origins: `https://gitlab.apps.monosense.io`
5. Token Signature Algorithm: RS256 (Realm Settings → Tokens)

**Test SSO**:
1. Navigate to https://gitlab.apps.monosense.io
2. Click "Sign in with Keycloak SSO"
3. Authenticate with Keycloak credentials
4. Verify user created in GitLab with correct name/email

## GitLab Runner with Kaniko

### Why Kaniko?

Kaniko builds container images **without privileged mode** - no root access to host required!

**Security Comparison**:
- ❌ **DIND**: Requires `privileged: true` = full root access to host system
- ✅ **Kaniko**: Runs as non-root user, no privileged mode needed

**Trade-offs**:
- ✅ Kaniko: Secure, production-ready, no privileged containers
- ✅ Kaniko: Works with all Dockerfiles
- ❌ Kaniko: No Docker daemon (can't run `docker` commands in build)
- ❌ Kaniko: Slightly slower for multi-stage builds

### Kaniko Pipeline Example

See `examples/kaniko-pipeline.yml` for a complete working example.

**Key Points**:
```yaml
build:
  image: gcr.io/kaniko-project/executor:v1.24.0-debug
  stage: build
  script:
    - /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}"
      --destination "${CI_REGISTRY_IMAGE}:latest"
      --cache=true
      --cache-repo="${CI_REGISTRY_IMAGE}/cache"
  tags:
    - kubernetes
    - kaniko
```

### DIND Fallback (Advanced)

For edge cases requiring Docker daemon access, DIND can be enabled:

1. **Change Runner Namespace PSA**: Edit `gitlab-runner/namespace.yaml`:
   ```yaml
   pod-security.kubernetes.io/enforce: privileged
   ```

2. **Enable DIND in Runner**: Edit `gitlab-runner/helmrelease.yaml`:
   ```yaml
   privileged = true
   ```

3. **Use DIND pipeline**: See `examples/dind-pipeline.yml`

**⚠️ Security Warning**: Only use DIND for trusted repositories and users!

## Troubleshooting

### Check GitLab Status

```bash
# All pods
kubectl -n gitlab-system get pods

# Webservice logs
kubectl -n gitlab-system logs -l app=webservice --tail=100

# Sidekiq logs
kubectl -n gitlab-system logs -l app=sidekiq --tail=100

# Migrations status
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "gitlab-rake db:migrate:status"
```

### Database Connectivity

```bash
# From toolbox
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash

# Test connection
gitlab-rake db:doctor

# Check pooler
kubectl -n cnpg-system get pooler gitlab-pooler
kubectl -n cnpg-system logs -l cnpg.io/poolerName=gitlab-pooler
```

### Redis Connectivity

```bash
# Test Redis
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc \
  "redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping"

# Check Sidekiq queues
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc \
  "gitlab-rake sidekiq:queue:clear"
```

### S3 Object Storage

```bash
# List artifacts
aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://gitlab-artifacts

# Check bucket permissions
aws --endpoint-url http://10.25.11.3:9000 s3api get-bucket-acl --bucket gitlab-artifacts

# Test upload
echo "test" | aws --endpoint-url http://10.25.11.3:9000 s3 cp - s3://gitlab-artifacts/test.txt
```

### OIDC/Keycloak Issues

**"Could not authenticate you from Keycloak"**:
- Check client secret matches in 1Password
- Verify redirect URI: `https://gitlab.apps.monosense.io/users/auth/openid_connect/callback`
- Check Keycloak realm signature algorithm (must be RS256)
- View GitLab logs: `kubectl -n gitlab-system logs -l app=webservice | grep -i oidc`

**"TLS verification failed"**:
- Keycloak must use publicly trusted certificate or GitLab needs CA bundle
- Check: `curl -v https://sso.monosense.io/.well-known/openid-configuration`

### Runner Not Registering

```bash
# Check runner logs
kubectl -n gitlab-runner logs -l app=gitlab-runner

# Verify registration token
kubectl -n gitlab-runner get secret gitlab-runner-registration -o jsonpath='{.data.runner-registration-token}' | base64 -d

# Check GitLab connectivity from runner
kubectl -n gitlab-runner exec -ti deploy/gitlab-runner -- curl -k https://gitlab.apps.monosense.io
```

### Pipeline Failures

**"No runners available"**:
- Check runner is online: GitLab UI → Admin → CI/CD → Runners
- Verify runner has correct tags: `kubernetes`, `kaniko`, `apps-cluster`
- Check runner logs for connection errors

**Kaniko "permission denied"**:
- Verify runner is NOT using `privileged: true`
- Check `runAsNonRoot: true` in pod security context
- Ensure Kaniko executor image is `gcr.io/kaniko-project/executor:latest`

## Monitoring

### Metrics Endpoints

```bash
# GitLab metrics
kubectl -n gitlab-system port-forward svc/gitlab-webservice-default 8181:8181
curl http://localhost:8181/-/metrics

# Runner metrics
kubectl -n gitlab-runner port-forward svc/gitlab-runner 9252:9252
curl http://localhost:9252/metrics
```

### Alerts (VictoriaMetrics)

8 alerts configured in `monitoring/vmrule.yaml`:

1. **GitLabWebUnavailable** (critical) - No webservice replicas
2. **GitLabSidekiqQueueBacklog** (warning) - >1000 jobs queued
3. **GitLabDatabaseConnectivityIssue** (critical) - DB errors
4. **GitLabRedisConnectivityIssue** (critical) - Redis errors
5. **GitLabS3Errors** (warning) - S3 operation failures
6. **GitLabCertificateExpiringSoon** (warning) - Cert <30 days
7. **GitLabHighErrorRate** (warning) - >5% HTTP 5xx
8. **GitLabLowSuccessRate** (warning) - <90% HTTP 2xx

## Maintenance

### Backup

GitLab backups handled by:
- **Git repos**: Gitaly PVC (50Gi on Rook-Ceph)
- **Database**: CNPG continuous backup to MinIO
- **Object storage**: MinIO backups (artifacts, LFS, uploads, etc.)

**Manual backup**:
```bash
kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc \
  "backup-utility --skip=artifacts,lfs,uploads,packages,registry"
```

### Restore

See [GitLab Restore Documentation](https://docs.gitlab.com/ee/raketasks/restore_gitlab.html)

### Upgrade

GitLab follows semantic versioning. Upgrade path:
1. Update `gitlabVersion` in `helmrelease.yaml`
2. Update chart version (9.5.1 → next)
3. Commit and push (Flux applies automatically)
4. Monitor: `flux get helmrelease -n gitlab-system`

**⚠️ Always review**: https://docs.gitlab.com/ee/update/

## Configuration

### Cluster Settings

All configuration variables in `kubernetes/clusters/apps/cluster-settings.yaml`:

```yaml
GITLAB_HOST: "gitlab.apps.monosense.io"
GITLAB_REGISTRY_HOST: "registry.gitlab.apps.monosense.io"
GITLAB_S3_ENDPOINT: "http://10.25.11.3:9000"
KEYCLOAK_HOST: "sso.monosense.io"
```

### Resource Requests/Limits

Total resources:
- **CPU**: ~2.3 cores requested, ~8 cores limit
- **Memory**: ~5.5Gi requested, ~12Gi limit
- **Storage**: 50Gi (Gitaly on Rook-Ceph)

## References

- [GitLab Helm Chart](https://docs.gitlab.com/charts/)
- [External PostgreSQL](https://docs.gitlab.com/charts/advanced/external-db/)
- [External Redis](https://docs.gitlab.com/charts/advanced/external-redis/)
- [External Object Storage](https://docs.gitlab.com/charts/advanced/external-object-storage/)
- [Keycloak OIDC](https://docs.gitlab.com/ee/administration/auth/oidc.html)
- [GitLab Runner](https://docs.gitlab.com/runner/install/kubernetes.html)
- [Kaniko](https://github.com/GoogleContainerTools/kaniko)

## Story

**Story ID**: STORY-CICD-GITLAB-APPS (33/50)
**Version**: GitLab 18.5.1 (Helm Chart 9.5.1)
**Security**: Kaniko rootless builds (baseline PSA, no privileged containers)
