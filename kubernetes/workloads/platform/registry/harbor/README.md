# Harbor Container Registry with External State

## Overview

Self-managed Harbor v2.14.0 container registry deployed on the infra cluster with external dependencies:

- **Database**: PostgreSQL via CNPG pooler (`harbor-pooler-rw.cnpg-system`)
- **Cache**: DragonflyDB Redis-compatible (`dragonfly.dragonfly-system`)
- **Object Storage**: External MinIO (http://10.25.11.3:9000)
- **Ingress**: Gateway API with Cilium + Let's Encrypt TLS
- **Scanning**: Trivy vulnerability scanner (embedded)
- **Secrets**: All credentials stored in 1Password (5 secrets required)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Infra Cluster                           │
│                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
│  │   Gateway    │────▶│    Harbor    │────▶│  CNPG Pooler │ │
│  │   (Cilium)   │     │  (v2.14.0)   │     │ (PostgreSQL) │ │
│  │              │     │              │     │              │ │
│  └──────────────┘     └──────┬───────┘     └──────────────┘ │
│                              │                              │
│                       ┌──────▼────────┐                     │
│                       │   Dragonfly   │                     │
│                       │   (Redis)     │                     │
│                       └───────────────┘                     │
│                                                             │
│  ┌──────────────┐     ┌───────────────┐                    │
│  │ JobService   │     │ Trivy Scanner │                    │
│  │ (10Gi PVC)   │     │ (5Gi PVC)     │                    │
│  │ Rook-Ceph    │     │ Rook-Ceph     │                    │
│  └──────────────┘     └───────────────┘                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
          ┌───────────────────────────────────────┐
          │  External MinIO (10.25.11.3:9000)     │
          │  - harbor (registry images/charts)    │
          └───────────────────────────────────────┘
```

## Components

### Harbor Services (harbor namespace)
- **Core**: 2 replicas (API server, authentication)
- **Portal**: 2 replicas (Web UI)
- **Registry**: 2 replicas (Image push/pull operations)
- **JobService**: 1 replica (replication, scanning, GC, 10Gi PVC)
- **Trivy**: 2 replicas (vulnerability scanner, 5Gi PVC)

### Disabled Components
- **ChartMuseum**: Disabled (use OCI artifacts instead)
- **Notary**: Disabled (content trust can be enabled later)

## External Dependencies

### 1. PostgreSQL (CNPG Pooler)

**Service**: `harbor-pooler-rw.cnpg-system.svc.cluster.local:5432`
**Database**: `harbor`
**User**: `harbor_app`
**Pool Mode**: Transaction
**Connections**: 200 max, 15 pool size

**Secret**: `kubernetes/infra/harbor/database` (1Password)
**Keys**: `host`, `port`, `database`, `username`, `password`, `sslmode`

**Test**:
```bash
kubectl -n harbor exec -ti deploy/harbor-core -- bash
psql "host=harbor-pooler-rw.cnpg-system.svc.cluster.local dbname=harbor user=harbor_app sslmode=disable" -c 'SELECT 1'
```

### 2. Redis (DragonflyDB)

**Service**: `dragonfly.dragonfly-system.svc.cluster.local:6379`
**Version**: v1.34.2 (Redis 7.x API compatible)

**Secret**: `kubernetes/infra/harbor/redis` (1Password)
**Keys**: `addr`, `password`

**Important**: Harbor does **NOT** support Redis TLS connections. DragonflyDB is secured via NetworkPolicies.

**Test**:
```bash
kubectl -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping
```

### 3. S3 Object Storage (MinIO)

**Endpoint**: `http://10.25.11.3:9000`
**Region**: `us-east-1`

**Bucket Required**:
- `harbor` - Container images and Helm charts

**Secret**: `kubernetes/infra/harbor/s3` (1Password)
**Keys**: `regionendpoint`, `bucket`, `accesskey`, `secretkey`, `region`

**Critical Configuration**:
```yaml
persistence:
  imageChartStorage:
    disableredirect: true  # REQUIRED for MinIO
registry:
  relativeurls: true       # REQUIRED for Gateway-fronted Harbor
```

**Why These Are Critical**:
- MinIO doesn't support S3 redirect responses (HTTP 307)
- Harbor behind Gateway API needs relative URLs to avoid HTTPS→HTTP downgrade

**Test**:
```bash
# Install AWS CLI if needed
aws configure set aws_access_key_id <key>
aws configure set aws_secret_access_key <secret>

# List buckets
aws --endpoint-url http://10.25.11.3:9000 s3 ls

# Test harbor bucket
aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://harbor
```

### 4. Admin Credentials

**Secret**: `kubernetes/infra/harbor/admin` (1Password)
**Keys**: `password`

**Default Username**: `admin`
**Password**: Stored in 1Password secret

### 5. Core Secret Keys

**Secret**: `kubernetes/infra/harbor/core` (1Password)
**Keys**:
- `secret_key` - 32-character random string for Harbor core encryption
- `xsrf_key` - 32-character random string for XSRF protection
- `registry_password` - Password for registry internal authentication

**Generate Keys** (before Story 45 deployment):
```bash
# Generate secret_key
openssl rand -hex 16

# Generate xsrf_key
openssl rand -hex 16

# Generate registry_password
openssl rand -base64 32
```

## Troubleshooting

### Check Harbor Status

```bash
# All pods
kubectl -n harbor get pods

# Core logs
kubectl -n harbor logs -l component=core --tail=100

# Registry logs
kubectl -n harbor logs -l component=registry --tail=100

# JobService logs
kubectl -n harbor logs -l component=jobservice --tail=100

# Trivy logs
kubectl -n harbor logs -l component=trivy --tail=100
```

### Database Connectivity

```bash
# From core pod
kubectl -n harbor exec -ti deploy/harbor-core -- sh

# Test database connection
psql "host=harbor-pooler-rw.cnpg-system.svc.cluster.local dbname=harbor user=harbor_app sslmode=disable" -c '\dt'

# Check pooler
kubectl -n cnpg-system get pooler harbor-pooler
kubectl -n cnpg-system logs -l cnpg.io/poolerName=harbor-pooler
```

### Redis Connectivity

```bash
# Test Redis
kubectl -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping

# Check Redis keys
kubectl -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 KEYS "*"
```

### S3 Object Storage

```bash
# List images in S3
aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://harbor/docker/registry/v2/repositories/

# Check bucket permissions
aws --endpoint-url http://10.25.11.3:9000 s3api get-bucket-acl --bucket harbor

# Test upload
echo "test" | aws --endpoint-url http://10.25.11.3:9000 s3 cp - s3://harbor/test.txt
```

### Docker Login Issues

**"unauthorized: authentication required"**:
- Check admin password in 1Password: `kubernetes/infra/harbor/admin`
- Verify Harbor Core is running: `kubectl -n harbor get pods -l component=core`
- Check Harbor logs: `kubectl -n harbor logs -l component=core | grep -i auth`

**"x509: certificate signed by unknown authority"**:
- Harbor is behind Gateway API with Let's Encrypt TLS
- Ensure DNS resolves: `dig harbor.infra.monosense.io`
- Check certificate: `curl -vI https://harbor.infra.monosense.io`

**Docker login command**:
```bash
# Login to Harbor
docker login harbor.infra.monosense.io
# Username: admin
# Password: <from 1Password>

# Test push/pull
docker tag myimage:latest harbor.infra.monosense.io/library/myimage:latest
docker push harbor.infra.monosense.io/library/myimage:latest
docker pull harbor.infra.monosense.io/library/myimage:latest
```

### Image Push Failures

**"blob upload unknown"**:
- Check S3 connectivity from registry pods
- Verify MinIO bucket exists and is accessible
- Check S3 credentials in ExternalSecret

**"500 Internal Server Error"**:
- Check registry logs: `kubectl -n harbor logs -l component=registry`
- Verify S3 configuration in HelmRelease (disableredirect, relativeurls)
- Check MinIO logs if available

### Trivy Scan Failures

**"database error: failed to download vulnerability DB"**:
- Check egress NetworkPolicy allows HTTPS (port 443)
- Verify Trivy can reach GitHub: `kubectl -n harbor exec -ti deploy/harbor-trivy -- curl -I https://github.com`
- Check Trivy logs: `kubectl -n harbor logs -l component=trivy | grep -i error`

**"timeout scanning image"**:
- Increase Trivy timeout in HelmRelease: `trivy.timeout: 10m0s`
- Increase Trivy memory limits: `trivy.resources.limits.memory: 2Gi`
- Scale Trivy replicas: `trivy.replicas: 3`

### Gateway/Ingress Issues

**"Harbor web UI not accessible"**:
- Check HTTPRoute: `kubectl -n harbor get httproute harbor-web`
- Verify Gateway status: `kubectl -n kube-system get gateway cilium-gateway-external`
- Check Gateway logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=cilium`

**"TLS handshake failed"**:
- Check certificate: `kubectl -n kube-system get certificate wildcard-tls`
- Verify cert-manager issuer: `kubectl get clusterissuer letsencrypt-prod`

## Monitoring

### Metrics Endpoints

```bash
# Harbor Core metrics
kubectl -n harbor port-forward svc/harbor-core 8001:8001
curl http://localhost:8001/metrics

# Registry metrics
kubectl -n harbor port-forward svc/harbor-registry 8001:8001
curl http://localhost:8001/metrics

# JobService metrics
kubectl -n harbor port-forward svc/harbor-jobservice 8001:8001
curl http://localhost:8001/metrics
```

### Alerts (VictoriaMetrics)

8 alerts configured in `monitoring/vmrule.yaml`:

1. **HarborCoreUnavailable** (critical) - No core replicas
2. **HarborRegistryUnavailable** (critical) - No registry replicas
3. **HarborDatabaseConnectivityIssue** (critical) - DB errors >10
4. **HarborRedisConnectivityIssue** (critical) - Redis errors >10
5. **HarborStorageErrors** (warning) - S3 errors >50
6. **HarborTrivyScanFailures** (warning) - Scan failures >20
7. **HarborHighLatency** (warning) - P95 latency >5s
8. **HarborCertificateExpiringSoon** (warning) - Cert <30 days

## Maintenance

### Backup

Harbor backups handled by:
- **Database**: CNPG continuous backup to MinIO
- **Object storage**: MinIO backups (images, charts)
- **Configuration**: GitOps (all manifests in git)

**Note**: Harbor doesn't require manual backup utilities like GitLab. All state is in PostgreSQL + S3.

### Garbage Collection

**Manual GC** (delete unused blobs):
```bash
# Dry-run
kubectl -n harbor exec -ti deploy/harbor-jobservice -- \
  /harbor/harbor_jobservice -c /etc/jobservice/config.yml gcr -n

# Execute GC
kubectl -n harbor exec -ti deploy/harbor-jobservice -- \
  /harbor/harbor_jobservice -c /etc/jobservice/config.yml gcr
```

**Scheduled GC** (via Harbor UI):
1. Login to Harbor: https://harbor.infra.monosense.io
2. Navigate to Configuration → System Settings
3. Configure Garbage Collection schedule (e.g., weekly)

### Vulnerability Database Updates

Trivy automatically updates vulnerability database when `trivy.offlineScan: false`.

**Manual update**:
```bash
kubectl -n harbor exec -ti deploy/harbor-trivy -- trivy image --download-db-only
```

### Upgrade

Harbor follows semantic versioning. Upgrade path:
1. Update `chart.version` in `helmrelease.yaml`
2. Review Harbor release notes: https://github.com/goharbor/harbor/releases
3. Commit and push (Flux applies automatically)
4. Monitor: `flux get helmrelease -n harbor`

**⚠️ Always review**: https://goharbor.io/docs/latest/administration/upgrade/

**Important**: Harbor only supports upgrading from n-2 minor versions (e.g., 2.10 → 2.12 OK, 2.9 → 2.12 NOT OK).

## Configuration

### Cluster Settings

All configuration variables in `kubernetes/clusters/infra/cluster-settings.yaml`:

```yaml
HARBOR_HOST: "harbor.infra.monosense.io"
HARBOR_S3_ENDPOINT: "http://10.25.11.3:9000"
HARBOR_S3_BUCKET: "harbor"
HARBOR_SECRET_KEY: "<random-32-chars>"
HARBOR_XSRF_KEY: "<random-32-chars>"
```

### Resource Requests/Limits

Total resources (10-50 users):
- **CPU**: ~2 cores requested, ~4.5 cores limit
- **Memory**: ~2.5Gi requested, ~5Gi limit
- **Storage**: 15Gi (10Gi JobService + 5Gi Trivy on Rook-Ceph)

### Scaling

**Horizontal Scaling** (increase replicas):
```yaml
# In cluster-settings.yaml
HARBOR_CORE_REPLICAS: "3"
HARBOR_REGISTRY_REPLICAS: "3"
HARBOR_TRIVY_REPLICAS: "3"
```

**Vertical Scaling** (increase resources):
```yaml
# In helmrelease.yaml
core:
  resources:
    requests: { cpu: 1, memory: 1Gi }
    limits: { cpu: 2, memory: 2Gi }
```

## Security

### RBAC

Harbor uses project-based RBAC:
- **Project Admin**: Full control over project
- **Maintainer**: Push/pull images, delete artifacts
- **Developer**: Push/pull images
- **Guest**: Pull images only
- **Limited Guest**: Pull + view vulnerability scans

**Best Practice**: Use robot accounts for CI/CD with minimal scope.

### Vulnerability Scanning

**Automatic Scanning**:
1. Enable scan-on-push: Project → Configuration → Automatically scan images on push
2. Set scan policy: Project → Policy → Add scan policy
3. Configure severity threshold: Block pulls if critical vulnerabilities found

**Manual Scan**:
1. Navigate to Repository → Artifacts
2. Click "Scan" button
3. View scan results and CVE details

### Image Signing (Notary)

**Currently Disabled**. To enable content trust:

1. Enable Notary in HelmRelease:
```yaml
notary:
  enabled: true
```

2. Generate signing keys on client:
```bash
docker trust key generate <key-name>
docker trust signer add --key <key-name>.pub <signer-name> harbor.infra.monosense.io/library/myimage
```

3. Sign and push:
```bash
export DOCKER_CONTENT_TRUST=1
docker push harbor.infra.monosense.io/library/myimage:latest
```

## Common Operations

### Create Project

```bash
# Via Harbor UI
1. Login to https://harbor.infra.monosense.io
2. Click "+ NEW PROJECT"
3. Set project name (e.g., "my-app")
4. Choose public or private
5. Enable vulnerability scanning

# Via Harbor API
curl -X POST "https://harbor.infra.monosense.io/api/v2.0/projects" \
  -u "admin:<password>" \
  -H "Content-Type: application/json" \
  -d '{"project_name":"my-app","public":false}'
```

### Create Robot Account

```bash
# Via Harbor UI
1. Navigate to Project → Robot Accounts
2. Click "+ NEW ROBOT ACCOUNT"
3. Set name and expiration
4. Select permissions (push/pull)
5. Save token for CI/CD

# Use robot account
docker login harbor.infra.monosense.io -u robot$<name> -p <token>
```

### Replicate to Another Registry

```bash
# Via Harbor UI
1. Navigate to Administration → Registries
2. Click "+ NEW ENDPOINT"
3. Configure target registry (Docker Hub, Quay, another Harbor)
4. Create replication rule: Administration → Replications
5. Set trigger (manual, scheduled, event-based)
```

### Proxy Cache (Pull-Through Cache)

```bash
# Via Harbor UI
1. Create new project with proxy cache mode
2. Set target registry (e.g., docker.io, gcr.io, quay.io)
3. Pull images through Harbor proxy:

# Instead of:
docker pull docker.io/library/nginx:latest

# Use:
docker pull harbor.infra.monosense.io/dockerhub-proxy/library/nginx:latest
```

## Integration Examples

### GitLab CI/CD

```yaml
# .gitlab-ci.yml
variables:
  HARBOR_REGISTRY: "harbor.infra.monosense.io"
  HARBOR_PROJECT: "my-app"
  IMAGE_TAG: "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${CI_PROJECT_NAME}:${CI_COMMIT_SHORT_SHA}"

build:
  stage: build
  image: gcr.io/kaniko-project/executor:v1.24.0-debug
  script:
    - echo "{\"auths\":{\"${HARBOR_REGISTRY}\":{\"auth\":\"$(printf "%s:%s" "${HARBOR_USER}" "${HARBOR_PASSWORD}" | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context "${CI_PROJECT_DIR}"
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
      --destination "${IMAGE_TAG}"
      --cache=true
```

### GitHub Actions (ARC)

```yaml
# .github/workflows/build.yml
name: Build and Push
on: [push]

jobs:
  build:
    runs-on: pilar-runner
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build -t harbor.infra.monosense.io/my-app/${{ github.repository }}:${{ github.sha }} .

      - name: Login to Harbor
        run: |
          echo "${{ secrets.HARBOR_PASSWORD }}" | docker login harbor.infra.monosense.io -u "${{ secrets.HARBOR_USER }}" --password-stdin

      - name: Push image
        run: |
          docker push harbor.infra.monosense.io/my-app/${{ github.repository }}:${{ github.sha }}
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: myapp
          image: harbor.infra.monosense.io/my-app/myapp:v1.0.0

---
# Create imagePullSecret
apiVersion: v1
kind: Secret
metadata:
  name: harbor-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [External PostgreSQL](https://goharbor.io/docs/latest/install-config/configure-external-database/)
- [External Redis](https://goharbor.io/docs/latest/install-config/configure-external-redis/)
- [S3 Storage](https://goharbor.io/docs/latest/install-config/configure-s3/)
- [Trivy Scanner](https://goharbor.io/docs/latest/administration/vulnerability-scanning/)

## Story

**Story ID**: STORY-CICD-HARBOR-APPS (34/50)
**Version**: Harbor v2.14.0 (Helm Chart 1.18.0)
**Security**: PSA baseline, NetworkPolicies, Trivy scanning
