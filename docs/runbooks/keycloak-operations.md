# Keycloak Identity Provider

Production-ready Keycloak deployment using the **official Keycloak Kubernetes Operator**.

## Architecture

- **Operator**: Official Keycloak Operator v26.4.5
- **Instances**: 2 replicas with pod anti-affinity (HA)
- **Database**: External PostgreSQL via keycloak-pooler (session mode, CNPG-managed)
- **Exposure**: Gateway API HTTPRoute with TLS (cert-manager)
- **Monitoring**: VictoriaMetrics ServiceMonitor + PrometheusRules
- **Caching**: Infinispan distributed cache with DNS_PING for Kubernetes
- **Security**: NetworkPolicy, PSA restricted, TLS everywhere

## Configuration

### Hostname

SSO hostname: `sso.monosense.io`

### Database

- **Host**: `keycloak-pooler-rw.cnpg-system.svc.cluster.local:5432`
- **Database**: `keycloak`
- **Pooling Mode**: Session (required for Keycloak/Hibernate)
- **Credentials**: From ExternalSecret `keycloak-db-credentials`

### Resources

**Per Pod**:
- CPU: 500m request, 2000m limit
- Memory: 1Gi request, 2Gi limit

**Total (2 replicas)**:
- CPU: ~1 vCPU request, ~4 vCPU limit
- Memory: ~2Gi request, ~4Gi limit

## Accessing Keycloak

### Admin Console

URL: `https://sso.monosense.io/admin`

Credentials: From ExternalSecret `keycloak-admin`
- Username: `KEYCLOAK_ADMIN`
- Password: `KEYCLOAK_ADMIN_PASSWORD`

### Platform Realm

Platform realm: `https://sso.monosense.io/realms/platform`

## Upgrade Procedures

### Operator Upgrade

1. Update operator version in cluster-settings.yaml:
   \`\`\`yaml
   KEYCLOAK_OPERATOR_VERSION: "26.x.x"
   \`\`\`

2. Commit and push to trigger Flux reconciliation

3. Monitor rollout:
   \`\`\`bash
   kubectl -n keycloak-operator-system get pods -w
   kubectl -n keycloak-operator-system logs -l app.kubernetes.io/name=keycloak-operator
   \`\`\`

### Keycloak Instance Upgrade

1. Update image tag in cluster-settings.yaml:
   \`\`\`yaml
   KEYCLOAK_IMAGE_TAG: "26.x.x"
   \`\`\`

2. Commit and push - Flux will update the Keycloak CR

3. Operator performs rolling upgrade automatically

4. Monitor rollout:
   \`\`\`bash
   kubectl -n keycloak-system get pods -w
   kubectl -n keycloak-system get keycloak keycloak
   \`\`\`

5. Verify health:
   \`\`\`bash
   curl -sfk https://sso.monosense.io/health | jq .
   \`\`\`

## Realm Management

### Import Realm

Realms are managed via `KeycloakRealmImport` CRs. The operator applies imports idempotently.

Example:
\`\`\`yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: KeycloakRealmImport
metadata:
  name: my-realm
  namespace: keycloak-system
spec:
  keycloakCRName: keycloak
  realm:
    id: my-realm
    realm: my-realm
    enabled: true
    # ... realm configuration
\`\`\`

### Export Realm

Export realm for backup:

\`\`\`bash
# Get Keycloak pod
POD=$(kubectl -n keycloak-system get pods -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

# Export realm
kubectl -n keycloak-system exec $POD -- \
  /opt/keycloak/bin/kc.sh export \
  --realm platform \
  --file /tmp/platform-realm.json \
  --users realm_file

# Copy export locally
kubectl -n keycloak-system cp $POD:/tmp/platform-realm.json ./platform-realm-$(date +%Y%m%d).json
\`\`\`

### Client Registration

Clients should be added via `KeycloakRealmImport` CR (declarative, GitOps):

1. Edit `realm-import.yaml`
2. Add new client to `clients` array
3. Commit and push
4. Flux applies changes automatically

## Backup & Restore

### Database Backup

Database is backed up via CNPG scheduled backups (see STORY-DB-CNPG-SHARED-CLUSTER).

### Realm Backup

1. Export all realms (see above)
2. Store exports in version control (exclude sensitive data)
3. Alternative: CNPG database backup includes all realm data

### Restore Procedure

1. Restore database from CNPG backup if needed
2. Re-apply realm imports from git via `KeycloakRealmImport` CRs
3. Verify realm configuration in admin console
4. Test SSO login flows

## Monitoring

### Metrics

Keycloak exports Prometheus metrics on port 9000 at `/metrics`.

Key metrics:
- `up{job="keycloak-system/keycloak"}` - Instance availability
- `keycloak_failed_login_attempts` - Failed login rate
- `http_server_requests_seconds_bucket` - Request latency
- `jvm_memory_used_bytes` - JVM memory usage
- `hikaricp_connections_active` - Database connection pool usage
- `jgroups_failed_messages_total` - Clustering communication issues

### Alerts

Configured alerts (see `prometheusrule.yaml`):
- **KeycloakDown** - Instance unreachable (5m)
- **KeycloakNotHighlyAvailable** - Replica count low (10m)
- **KeycloakHighErrorRate** - High login failure rate (10m)
- **KeycloakHighResponseTime** - P99 latency >5s (10m)
- **KeycloakJVMMemoryHigh** - Heap usage >80% (10m)
- **KeycloakJVMMemoryCritical** - Heap usage >90% (5m)
- **KeycloakJVMGCPressure** - High GC activity (10m)
- **KeycloakDatabaseConnectionsHigh** - Pool usage >80% (10m)
- **KeycloakDatabaseConnectionsCritical** - Pool usage >95% (5m)
- **KeycloakClusteringIssue** - JGroups communication failures (5m)

## Troubleshooting

### Keycloak Not Starting

Check operator logs:
\`\`\`bash
kubectl -n keycloak-operator-system logs -l app.kubernetes.io/name=keycloak-operator
\`\`\`

Check Keycloak CR status:
\`\`\`bash
kubectl -n keycloak-system get keycloak keycloak
kubectl -n keycloak-system describe keycloak keycloak
\`\`\`

Check pod events and logs:
\`\`\`bash
kubectl -n keycloak-system describe pod <pod-name>
kubectl -n keycloak-system logs <pod-name> -f
\`\`\`

### Database Connection Issues

Test pooler connectivity:
\`\`\`bash
kubectl -n keycloak-system run -it --rm psql --image=postgres:16 --restart=Never -- \
  psql -h keycloak-pooler-rw.cnpg-system.svc.cluster.local -U keycloak -d keycloak
\`\`\`

Check pooler status:
\`\`\`bash
kubectl -n cnpg-system get pooler keycloak-pooler
kubectl -n cnpg-system logs -l cnpg.io/poolerName=keycloak-pooler
\`\`\`

### TLS Certificate Issues

Check certificate status:
\`\`\`bash
kubectl -n keycloak-system get certificate sso-tls
kubectl -n keycloak-system describe certificate sso-tls
\`\`\`

Check certificate secret:
\`\`\`bash
kubectl -n keycloak-system get secret sso-tls
\`\`\`

Test TLS:
\`\`\`bash
curl -vk https://sso.monosense.io
\`\`\`

### HTTPRoute Not Working

Check HTTPRoute status:
\`\`\`bash
kubectl -n keycloak-system get httproute keycloak
kubectl -n keycloak-system describe httproute keycloak
\`\`\`

Check Gateway status:
\`\`\`bash
kubectl -n kube-system get gateway cilium-gateway-external
\`\`\`

### Clustering Issues

Check JGroups communication:
\`\`\`bash
# Check headless service resolves all pods
kubectl -n keycloak-system run -it --rm nslookup --image=busybox --restart=Never -- \
  nslookup keycloak-headless.keycloak-system.svc.cluster.local

# Check JGroups metrics
kubectl -n keycloak-system exec <pod-name> -- \
  curl -s http://localhost:9000/metrics | grep jgroups
\`\`\`

## Security Considerations

1. **Admin Credentials**: Rotate regularly via ExternalSecrets (1Password)
2. **Database Credentials**: Managed via CNPG, rotated via ExternalSecrets
3. **TLS Certificates**: Auto-renewed by cert-manager (90 days)
4. **Session Security**: Configure realm-level session timeouts
5. **Brute Force Protection**: Enabled by default in realm import
6. **NetworkPolicy**: Restricts traffic to database, DNS, and Gateway only
7. **PSA Restricted**: Pod Security Admission enforced

## Performance Tuning

### Scaling Up

Increase replicas:
\`\`\`yaml
# In cluster-settings.yaml
KEYCLOAK_REPLICAS: "3"
\`\`\`

### Resource Adjustments

Adjust based on actual usage:
\`\`\`yaml
# In cluster-settings.yaml
KEYCLOAK_CPU_REQUEST: "1000m"
KEYCLOAK_CPU_LIMIT: "4000m"
KEYCLOAK_MEMORY_REQUEST: "2Gi"
KEYCLOAK_MEMORY_LIMIT: "4Gi"
\`\`\`

### Cache Tuning

Edit `cache-configmap.yaml` to adjust cache sizes:
- Increase `max-count` for local caches if realm/user data is large
- Adjust `max-idle` expiration for cache eviction policies

## References

- [Keycloak Operator Documentation](https://www.keycloak.org/operator/basic-deployment)
- [Keycloak Server Configuration](https://www.keycloak.org/server/configuration)
- [Keycloak HA Guide](https://www.keycloak.org/high-availability/introduction)
- [Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
- [Story Document](../../../../../docs/stories/STORY-IDP-KEYCLOAK-OPERATOR.md)
