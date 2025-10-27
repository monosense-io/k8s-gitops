# 28 — STORY-SEC-SPIRE-CILIUM-AUTH — Create SPIRE & Cilium mTLS Authentication Manifests

Sequence: 28/50 | Prev: STORY-IDP-KEYCLOAK-OPERATOR.md | Next: STORY-STO-APPS-OPENEBS-BASE.md
Sprint: 6 | Lane: Security
Global Sequence: 28/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md §20, §21; kubernetes/infrastructure/security/spire/; kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml; kubernetes/components/networkpolicy/auth/

## Story

As a platform engineer, I want to **create manifests for SPIRE workload identity and Cilium mTLS authentication** so that both clusters (infra, apps) have a zero-trust foundation using SPIFFE identities with Cilium-native mTLS enforcement via identity-based policies.

## Why / Outcome

- **Zero-trust baseline**: Workload identity using SPIFFE/SPIRE with mTLS enforced by Cilium
- **Identity-centric policies**: Security decisions based on service accounts, not IP addresses
- **Cross-cluster trust**: Shared trust domain enables ClusterMesh identity federation
- **Declarative management**: All SPIRE and Cilium authentication settings managed via GitOps

## Scope

### This Story (Manifest Creation)

**CREATE** the following manifests (local-only work):

1. **SPIRE Infrastructure** (`kubernetes/infrastructure/security/spire/`):
   - Namespace with PSA restricted
   - SPIRE Server StatefulSet with persistent storage
   - SPIRE Agent DaemonSet for node-level workload attestation
   - RBAC (ServiceAccounts, ClusterRoles, ClusterRoleBindings)
   - ConfigMaps for server and agent configuration
   - Service for server API
   - PodMonitor for metrics
   - PrometheusRule for alerting

2. **Cilium Authentication Update** (`kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`):
   - Enable `authentication.mutual.spire` configuration
   - Safe rollout with feature flag (`${CILIUM_AUTHN_ENABLED}`)
   - SPIRE socket path configuration
   - Health check configuration

3. **Example Auth Policies** (`kubernetes/components/networkpolicy/auth/`):
   - CiliumAuthPolicy requiring SPIFFE mTLS
   - Combined CNP + CAP examples
   - Multi-namespace policy patterns
   - README with usage examples

4. **Flux Kustomizations**:
   - Infrastructure Kustomization for SPIRE stack
   - Health checks for server and agent
   - Dependency ordering

5. **Documentation**:
   - Comprehensive README for SPIRE deployment
   - Trust domain configuration guide
   - SVID registration patterns
   - Troubleshooting procedures

**DO NOT**:
- Deploy to any cluster
- Run validation commands requiring cluster access
- Test authentication flows
- Verify Hubble identity labels

### Deferred to Story 45 (Deployment & Validation)

Story 45 will handle:
- Applying manifests to infra and apps clusters via Flux
- Verifying SPIRE server and agent readiness
- Testing CiliumAuthPolicy enforcement
- Validating Hubble identity flows
- Smoke testing authentication with/without SVID
- End-to-end validation of cross-cluster trust

## Acceptance Criteria

### Manifest Creation (This Story)

**AC1**: SPIRE infrastructure manifests created under `kubernetes/infrastructure/security/spire/`:
- `namespace.yaml` with PSA restricted enforcement
- `server.yaml` StatefulSet with 1 replica, PVC for data persistence
- `agent.yaml` DaemonSet for all nodes
- `rbac.yaml` with ClusterRole for k8s workload attestation
- `server-configmap.yaml` and `agent-configmap.yaml`
- `server-service.yaml` for gRPC API
- `kustomization.yaml`

**AC2**: SPIRE server configured with:
- Trust domain: `spiffe://${SECRET_DOMAIN}`
- Storage: 1Gi PVC on `${BLOCK_SC}`
- K8s workload attestor enabled
- K8s PSAT node attestor for agents
- JWT-SVID plugin enabled
- Health check endpoints

**AC3**: SPIRE agent configured with:
- Unix domain socket at `/run/spire/sockets/agent.sock`
- K8s workload attestor with pod UID, namespace, service account
- Node attestation via PSAT tokens
- Resource requests: 100m CPU, 128Mi memory
- Tolerations for control plane nodes

**AC4**: Cilium HelmRelease updated in `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`:
- `authentication.enabled: ${CILIUM_AUTHN_ENABLED}` (default: true)
- `authentication.mutual.spire.enabled: true`
- `authentication.mutual.spire.install.enabled: false` (use external SPIRE)
- `authentication.mutual.spire.serverAddress: unix:///run/spire/sockets/agent.sock`
- `authentication.mutual.spire.trustDomain: ${SECRET_DOMAIN}`

**AC5**: Example CiliumAuthPolicy manifests created in `kubernetes/components/networkpolicy/auth/`:
- `require-spiffe-mtls/` component with CAP requiring authenticated workloads
- Combined CNP + CAP example for defense in depth
- Multi-namespace policy template
- Service account selector patterns
- README with usage examples and troubleshooting

**AC6**: Monitoring configured:
- PodMonitor scraping SPIRE server metrics (port 9988)
- PodMonitor scraping SPIRE agent metrics (port 9988)
- PrometheusRule with alerts for:
  - SPIRE server unavailable
  - SPIRE agent unhealthy on nodes
  - SVID rotation failures
  - Registration entry errors
  - Trust bundle expiration warnings

**AC7**: Flux Kustomization created for SPIRE stack:
- `kubernetes/infrastructure/security/spire/ks.yaml`
- Health checks for server StatefulSet and agent DaemonSet
- Dependency on Cilium (requires CNI)
- Timeout: 5 minutes

**AC8**: Security hardening applied:
- PSA restricted enforcement on spire namespace
- SPIRE containers run as non-root (UID 1000)
- ReadOnlyRootFilesystem for containers (with writable socket volumes)
- Capabilities dropped, no privilege escalation
- PodDisruptionBudget for server (minAvailable: 1 if HA)

**AC9**: Trust domain configuration documented:
- Default: `spiffe://${SECRET_DOMAIN}`
- SVID format: `spiffe://${SECRET_DOMAIN}/ns/<namespace>/sa/<service-account>`
- Registration patterns for common workloads
- Federation setup for cross-cluster trust (if using ClusterMesh)

**AC10**: All manifests pass local validation:
- `kubectl --dry-run=client` succeeds
- `flux build kustomization` succeeds
- `kubeconform` validation passes
- YAML linting passes

**AC11**: Documentation includes:
- SPIRE architecture overview
- Trust domain configuration
- Workload registration patterns
- CiliumAuthPolicy examples
- Troubleshooting guide (server/agent logs, health endpoints)
- Upgrade procedures
- Backup/restore considerations (trust bundle)

### Deferred to Story 45 (NOT validated in this Story)

- SPIRE server and agent pods running and Ready
- Cilium authentication enabled and healthy
- CiliumAuthPolicy enforcement working
- Hubble showing identity labels
- SVID rotation functioning
- Cross-cluster trust established

## Dependencies / Inputs

**Local Tools Required**:
- `kubectl` (for dry-run validation)
- `flux` CLI (for `flux build kustomization`)
- `yq` (for YAML processing)
- `kubeconform` (for schema validation)

**Story Dependencies**:
- **STORY-NET-CILIUM-CORE-GITOPS** (Story 8): Cilium under GitOps control
- **STORY-SEC-NP-BASELINE** (Story 26): Network policies baseline

**Configuration Inputs**:
- `${SECRET_DOMAIN}`: Base domain for SPIFFE trust domain
- `${BLOCK_SC}`: Storage class for SPIRE server PVC
- `${CILIUM_AUTHN_ENABLED}`: Feature flag for authentication (default: "true")
- `${SPIRE_SERVER_REPLICAS}`: Server replicas (1 for single-node, 3 for HA)

## Tasks / Subtasks

### T1: Prerequisites and Strategy
- Review SPIRE architecture and SPIFFE specification
- Review Cilium authentication documentation
- Determine trust domain strategy (single vs. per-cluster)
- Plan SVID registration patterns for platform workloads

### T2: SPIRE Namespace
- Create `kubernetes/infrastructure/security/spire/namespace.yaml`:
  - Namespace: `spire`
  - PSA labels: `pod-security.kubernetes.io/enforce=restricted`
  - Labels: `app.kubernetes.io/name=spire`, `app.kubernetes.io/component=security`

### T3: SPIRE Server RBAC
- Create `kubernetes/infrastructure/security/spire/server-rbac.yaml`:
  - ServiceAccount: `spire-server`
  - ClusterRole: `spire-server` with permissions:
    - nodes: get (for node attestation)
    - pods, nodes/status: get, list, watch (for workload attestation)
    - tokenreviews: create (for PSAT validation)
    - configmaps: get, list, patch (for trust bundle distribution)
  - ClusterRoleBinding: `spire-server`

### T4: SPIRE Server ConfigMap
- Create `kubernetes/infrastructure/security/spire/server-configmap.yaml`:
  - Trust domain: `${SECRET_DOMAIN}`
  - Data directory: `/run/spire/data`
  - Log level: info
  - Plugins:
    - DataStore: sql (sqlite3 for simplicity, PostgreSQL for HA)
    - KeyManager: memory (or disk for persistence)
    - NodeAttestor: k8s_psat
    - WorkloadAttestor: k8s
    - Notifier: k8sbundle (for ConfigMap distribution)
  - Health checks: 0.0.0.0:8080
  - Metrics: 0.0.0.0:9988

### T5: SPIRE Server StatefulSet
- Create `kubernetes/infrastructure/security/spire/server.yaml`:
  - StatefulSet: `spire-server`
  - Replicas: `${SPIRE_SERVER_REPLICAS}` (default: 1)
  - Image: `ghcr.io/spiffe/spire-server:1.9.6` (latest stable)
  - Container ports: 8081 (API), 8080 (health), 9988 (metrics)
  - Volume mounts:
    - `/run/spire/data` (PVC)
    - `/run/spire/config` (ConfigMap)
    - `/run/spire/sockets` (emptyDir for socket)
  - Security context: runAsNonRoot, runAsUser 1000, fsGroup 1000
  - Resource requests: 200m CPU, 256Mi memory
  - Resource limits: 500m CPU, 512Mi memory
  - Liveness probe: /live, initialDelay 15s
  - Readiness probe: /ready, initialDelay 5s
  - PodDisruptionBudget: minAvailable 1 (if replicas > 1)
  - VolumeClaimTemplate: 1Gi PVC on `${BLOCK_SC}`

### T6: SPIRE Server Service
- Create `kubernetes/infrastructure/security/spire/server-service.yaml`:
  - Service: `spire-server`
  - Type: ClusterIP
  - Ports: 8081/TCP (gRPC API)
  - Selector: `app=spire-server`

### T7: SPIRE Agent RBAC
- Create `kubernetes/infrastructure/security/spire/agent-rbac.yaml`:
  - ServiceAccount: `spire-agent`
  - ClusterRole: `spire-agent` with permissions:
    - pods, nodes/proxy: get, list (for workload attestation)
    - No write permissions required
  - ClusterRoleBinding: `spire-agent`

### T8: SPIRE Agent ConfigMap
- Create `kubernetes/infrastructure/security/spire/agent-configmap.yaml`:
  - Trust domain: `${SECRET_DOMAIN}`
  - Server address: `spire-server.spire.svc.cluster.local:8081`
  - Socket path: `/run/spire/sockets/agent.sock`
  - Data directory: `/run/spire/data`
  - Log level: info
  - Plugins:
    - KeyManager: memory
    - NodeAttestor: k8s_psat (token path: `/var/run/secrets/tokens/spire-agent`)
    - WorkloadAttestor: k8s (kubelet read-only port disabled, use secure port)
  - Health checks: 0.0.0.0:8080
  - Metrics: 0.0.0.0:9988

### T9: SPIRE Agent DaemonSet
- Create `kubernetes/infrastructure/security/spire/agent.yaml`:
  - DaemonSet: `spire-agent`
  - Image: `ghcr.io/spiffe/spire-agent:1.9.6`
  - Container ports: 8080 (health), 9988 (metrics)
  - Volume mounts:
    - `/run/spire/sockets` (hostPath for Cilium access)
    - `/run/spire/config` (ConfigMap)
    - `/run/spire/data` (emptyDir)
    - `/var/run/secrets/tokens` (projected ServiceAccount token)
  - HostPath volumes:
    - `/run/spire/sockets` (DirectoryOrCreate) for Unix socket
  - Security context: runAsNonRoot, runAsUser 1000, readOnlyRootFilesystem true
  - Resource requests: 100m CPU, 128Mi memory
  - Resource limits: 200m CPU, 256Mi memory
  - Liveness probe: /live, initialDelay 15s
  - Readiness probe: /ready, initialDelay 5s
  - Tolerations: control plane taints
  - HostNetwork: false (use cluster networking)

### T10: SPIRE Monitoring
- Create `kubernetes/infrastructure/security/spire/podmonitor.yaml`:
  - PodMonitor: `spire-server` (port 9988, path /metrics)
  - PodMonitor: `spire-agent` (port 9988, path /metrics)
  - Namespace selector: spire
  - Labels for VictoriaMetrics discovery

### T11: SPIRE Alerting
- Create `kubernetes/infrastructure/security/spire/prometheusrule.yaml`:
  - VMRule: `spire-alerts`
  - Alert groups:
    - **SPIREServerDown**: No SPIRE server pods ready for 5 minutes
    - **SPIREAgentUnhealthy**: SPIRE agent not ready on node for 5 minutes
    - **SPIRERotationFailure**: SVID rotation failures detected
    - **SPIRERegistrationErrors**: Registration entry errors increasing
    - **SPIRETrustBundleExpiringSoon**: Trust bundle expires in <30 days
    - **SPIREHighMemoryUsage**: Memory usage >80% of limit
    - **SPIREAPILatencyHigh**: Server API latency p95 >500ms

### T12: SPIRE Kustomization
- Create `kubernetes/infrastructure/security/spire/kustomization.yaml`:
  - Resources: namespace, server-rbac, agent-rbac, server-configmap, agent-configmap, server, agent, server-service, podmonitor, prometheusrule
  - Namespace: spire
  - CommonLabels: `app.kubernetes.io/part-of=spire`

### T13: Cilium HelmRelease Authentication Update
- Edit `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`:
  - Add to spec.values:
    ```yaml
    authentication:
      enabled: ${CILIUM_AUTHN_ENABLED}  # Feature flag
      mutual:
        spire:
          enabled: true
          install:
            enabled: false  # Use external SPIRE
          serverAddress: unix:///run/spire/sockets/agent.sock
          trustDomain: ${SECRET_DOMAIN}
          adminSocketPath: /run/spire/sockets/admin.sock
    ```
  - Add volume mount to Cilium agent DaemonSet (via values):
    ```yaml
    extraVolumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
    extraVolumeMounts:
      - name: spire-agent-socket
        mountPath: /run/spire/sockets
        readOnly: true
    ```

### T14: Example CiliumAuthPolicy - Require SPIFFE mTLS
- Create `kubernetes/components/networkpolicy/auth/require-spiffe-mtls/ciliumauthpolicy.yaml`:
  - CiliumAuthPolicy: `require-spiffe-mtls`
  - Require authenticated identity for all ingress to namespace
  - Match on SPIFFE ID patterns
  - Deny unauthenticated traffic

### T15: Example Combined CNP + CAP
- Create `kubernetes/components/networkpolicy/auth/require-spiffe-mtls/ciliumnetworkpolicy.yaml`:
  - CiliumNetworkPolicy: `allow-authenticated-internal`
  - Allow traffic from cluster CIDR with authentication requirement
  - Defense in depth: network layer + identity layer

### T16: Auth Policy Component Kustomization
- Create `kubernetes/components/networkpolicy/auth/require-spiffe-mtls/kustomization.yaml`:
  - Resources: ciliumauthpolicy, ciliumnetworkpolicy
  - Labels: `app.kubernetes.io/component=auth-policy`

### T17: Example Multi-Namespace Auth Policy
- Create `kubernetes/components/networkpolicy/auth/require-spiffe-cross-ns/ciliumauthpolicy.yaml`:
  - Allow specific service accounts from different namespaces
  - SPIFFE ID patterns: `spiffe://${SECRET_DOMAIN}/ns/source-ns/sa/source-sa`

### T18: Auth Policy Component README
- Create `kubernetes/components/networkpolicy/auth/README.md`:
  - Overview of CiliumAuthPolicy
  - Usage examples for each component
  - SPIFFE ID patterns and selectors
  - Troubleshooting authentication failures
  - Integration with NetworkPolicies
  - Migration strategy from IP-based to identity-based policies

### T19: SPIRE Flux Kustomization
- Create `kubernetes/infrastructure/security/spire/ks.yaml`:
  - Kustomization: `cluster-<cluster>-spire`
  - Source: GitRepository/flux-system
  - Path: `./kubernetes/infrastructure/security/spire`
  - Interval: 10m
  - Prune: true
  - Wait: true
  - Timeout: 5m
  - Health checks:
    - StatefulSet/spire-server (infra, apps)
    - DaemonSet/spire-agent (infra, apps)
  - DependsOn:
    - cluster-<cluster>-cilium-core (requires CNI)

### T20: Infrastructure Kustomization Update
- Update `kubernetes/infrastructure/security/kustomization.yaml`:
  - Add `./spire` to resources

### T21: SPIRE Deployment README
- Create `kubernetes/infrastructure/security/spire/README.md`:
  - **Architecture Overview**:
    - SPIRE server as identity provider
    - SPIRE agents on all nodes
    - Cilium as mTLS enforcement plane
    - Trust domain configuration
  - **Trust Domain**:
    - Format: `spiffe://${SECRET_DOMAIN}`
    - SVID pattern: `spiffe://${SECRET_DOMAIN}/ns/<namespace>/sa/<service-account>`
    - Federation considerations for ClusterMesh
  - **Workload Registration**:
    - Automatic registration via K8s workload attestor
    - Selector patterns: `k8s:ns:<namespace>`, `k8s:sa:<service-account>`, `k8s:pod-label:<key>:<value>`
    - Manual registration examples using spire-server CLI
  - **CiliumAuthPolicy Usage**:
    - Basic authentication requirement
    - Service account allowlists
    - Cross-namespace communication
    - Combined with NetworkPolicies
  - **Troubleshooting**:
    - Check SPIRE server logs: `kubectl logs -n spire sts/spire-server`
    - Check SPIRE agent logs: `kubectl logs -n spire ds/spire-agent`
    - Verify server health: `kubectl exec -n spire sts/spire-server -c spire-server -- /opt/spire/bin/spire-server healthcheck`
    - List registration entries: `kubectl exec -n spire sts/spire-server -c spire-server -- /opt/spire/bin/spire-server entry show`
    - Check Cilium authentication status: `cilium status --verbose | grep -i auth`
    - Inspect workload identity: `spire-agent api fetch x509`
  - **Upgrade Procedures**:
    - SPIRE server: rolling update with data persistence
    - SPIRE agent: DaemonSet rolling update
    - Cilium authentication: gradual rollout using feature flag
  - **Backup/Restore**:
    - Trust bundle backup (ConfigMap: spire-bundle)
    - Server data PVC backup
    - Registration entries export/import
  - **High Availability**:
    - Multi-replica server setup (requires PostgreSQL datastore)
    - Shared trust bundle via ConfigMap
    - Load balancing agent connections

### T22: Cluster Settings Update
- Update `kubernetes/clusters/infra/cluster-settings.yaml` and `kubernetes/clusters/apps/cluster-settings.yaml`:
  - Add SPIRE configuration:
    ```yaml
    CILIUM_AUTHN_ENABLED: "true"
    SPIRE_SERVER_REPLICAS: "1"  # "3" for HA
    ```
  - Trust domain already covered by `SECRET_DOMAIN`

### T23: Local Validation
- Run validation commands:
  - `kubectl --dry-run=client apply -f kubernetes/infrastructure/security/spire/`
  - `flux build kustomization cluster-infra-spire --path ./kubernetes/infrastructure/security/spire`
  - `kubeconform -summary -output pretty kubernetes/infrastructure/security/spire/*.yaml`
  - `yamllint kubernetes/infrastructure/security/spire/`
- Verify Cilium HelmRelease syntax
- Validate CiliumAuthPolicy examples

### T24: Git Commit
- Stage all changes
- Commit: "feat(security): add SPIRE workload identity and Cilium mTLS authentication manifests (Story 28)"

## Runtime Validation (MOVED TO STORY 45)

**The following validation steps require a running cluster and are deferred to Story 45:**

### SPIRE Server and Agent Validation
```bash
# Check SPIRE server
kubectl --context=infra -n spire get sts spire-server
kubectl --context=infra -n spire get pod -l app=spire-server
kubectl --context=infra -n spire logs sts/spire-server -c spire-server --tail=50

# Check SPIRE agent
kubectl --context=infra -n spire get ds spire-agent
kubectl --context=infra -n spire get pod -l app=spire-agent
kubectl --context=infra -n spire logs ds/spire-agent -c spire-agent --tail=50

# Health checks
kubectl --context=infra -n spire exec sts/spire-server -c spire-server -- /opt/spire/bin/spire-server healthcheck

# List registration entries (should see auto-registered workloads)
kubectl --context=infra -n spire exec sts/spire-server -c spire-server -- /opt/spire/bin/spire-server entry show

# Check trust bundle distribution
kubectl --context=infra -n spire get configmap spire-bundle -o yaml
```

### Cilium Authentication Validation
```bash
# Check Cilium pods restarted with authentication
kubectl --context=infra -n kube-system get pod -l k8s-app=cilium
kubectl --context=infra -n kube-system logs ds/cilium --tail=50 | grep -i "auth\|spire"

# Verify Cilium config
kubectl --context=infra -n kube-system get cm cilium-config -o yaml | grep -A 10 "authentication"

# Check Cilium status
kubectl --context=infra -n kube-system exec ds/cilium -- cilium status --verbose | grep -i auth

# Verify SPIRE socket mount
kubectl --context=infra -n kube-system exec ds/cilium -- ls -la /run/spire/sockets/
```

### CiliumAuthPolicy Enforcement Testing
```bash
# Apply example auth policy to a test namespace
kubectl --context=infra apply -f kubernetes/components/networkpolicy/auth/require-spiffe-mtls/

# Create test pods with different service accounts
kubectl --context=infra -n test-ns run client-authenticated --image=curlimages/curl --serviceaccount=allowed-sa -- sleep 3600
kubectl --context=infra -n test-ns run client-unauthenticated --image=curlimages/curl --serviceaccount=default -- sleep 3600
kubectl --context=infra -n test-ns run server --image=nginx --serviceaccount=server-sa

# Test authenticated access (should succeed)
kubectl --context=infra -n test-ns exec client-authenticated -- curl -s http://server

# Test unauthenticated access (should fail)
kubectl --context=infra -n test-ns exec client-unauthenticated -- curl -s --max-time 5 http://server
# Expected: Connection timeout or denied

# Check Hubble flows for identity labels
cilium hubble observe --from-pod test-ns/client-authenticated --to-pod test-ns/server
# Look for: identity labels, authentication verdict
```

### SVID Validation
```bash
# Fetch X.509 SVID for a workload
kubectl --context=infra -n spire exec ds/spire-agent -c spire-agent -- /opt/spire/bin/spire-agent api fetch x509

# Verify SPIFFE ID format
# Should see: spiffe://<SECRET_DOMAIN>/ns/<namespace>/sa/<service-account>

# Check SVID rotation
# Monitor logs for rotation events (default: 1 hour TTL)
kubectl --context=infra -n spire logs ds/spire-agent -c spire-agent -f | grep -i "rotation\|renewed"
```

### Monitoring Validation
```bash
# Check PodMonitors discovered
kubectl --context=infra -n observability get podmonitor -l app.kubernetes.io/name=spire

# Query SPIRE metrics
curl -s http://spire-server.spire.svc.cluster.local:9988/metrics | grep spire_server

# Check alerts configured
kubectl --context=infra -n observability get vmrule spire-alerts -o yaml

# Verify metrics in VictoriaMetrics
# Query: up{job="spire-server"}
# Query: spire_server_agent_svid_issued_total
```

### Cross-Cluster Trust (if ClusterMesh enabled)
```bash
# Check trust bundle propagation to apps cluster
kubectl --context=apps -n spire get configmap spire-bundle

# Verify federation configuration
kubectl --context=infra -n spire exec sts/spire-server -c spire-server -- /opt/spire/bin/spire-server bundle show

# Test cross-cluster authenticated access
# (Requires ClusterMesh service exposure and CAP allowing remote identities)
```

### Rollback Testing
```bash
# Disable Cilium authentication
kubectl --context=infra -n flux-system edit helmrelease cilium
# Set: authentication.enabled: false

# Monitor rollout
flux reconcile helmrelease -n kube-system cilium --with-source
kubectl --context=infra -n kube-system rollout status ds/cilium

# Verify traffic flows without authentication (should revert to IP-based policies)
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] All acceptance criteria AC1-AC11 met
- [x] SPIRE server and agent manifests created under `kubernetes/infrastructure/security/spire/`
- [x] Cilium HelmRelease updated with authentication configuration
- [x] Example CiliumAuthPolicy components created under `kubernetes/components/networkpolicy/auth/`
- [x] Flux Kustomization created for SPIRE stack
- [x] Monitoring configured (PodMonitors, PrometheusRules)
- [x] All manifests pass local validation (dry-run, flux build, kubeconform)
- [x] Comprehensive README documentation created
- [x] Cluster settings updated with SPIRE configuration
- [x] Changes committed to git with descriptive message

### NOT Part of DoD (Moved to Story 45)

The following are **explicitly deferred** to Story 45:
- SPIRE server and agent deployed and running
- Cilium authentication enabled in live clusters
- CiliumAuthPolicy enforcement tested
- Hubble identity flows validated
- SVID rotation verified
- Cross-cluster trust established
- Monitoring alerts firing correctly
- End-to-end authentication smoke tests

## Design Notes

### SPIRE Architecture

**Components**:
1. **SPIRE Server**: Central identity provider
   - Issues X.509 SVIDs (SPIFFE Verifiable Identity Documents)
   - Manages registration entries (workload → identity mappings)
   - Distributes trust bundles
   - Single StatefulSet with persistent storage

2. **SPIRE Agent**: Node-level attestation
   - Runs on every node as DaemonSet
   - Attests to server using K8s PSAT tokens
   - Provides local workload API (Unix socket)
   - Caches SVIDs for workloads

3. **Cilium Integration**: mTLS enforcement
   - Cilium reads SPIRE agent socket for workload identities
   - CiliumAuthPolicy uses SPIFFE IDs for access control
   - Envoy proxy handles mTLS handshakes
   - Hubble shows identity labels in flows

### Trust Domain Strategy

**Single Trust Domain**:
- Use `spiffe://${SECRET_DOMAIN}` for both clusters
- Simplifies federation for ClusterMesh
- Shared trust bundle via ConfigMap

**SVID Format**:
```
spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>
```

Example:
```
spiffe://example.com/ns/synergyflow/sa/api
```

### Workload Attestation

**K8s Workload Attestor**:
- Automatically discovers pods on the node
- Extracts namespace, service account, pod UID
- No manual registration needed for basic cases

**Selectors**:
```yaml
# Match by namespace
k8s:ns:synergyflow

# Match by service account
k8s:sa:api

# Match by pod label
k8s:pod-label:app:nginx
```

**Registration Entry Example**:
```bash
spire-server entry create \
  -parentID spiffe://example.com/spire/agent/k8s_psat/apps/node-1 \
  -spiffeID spiffe://example.com/ns/synergyflow/sa/api \
  -selector k8s:ns:synergyflow \
  -selector k8s:sa:api
```

### CiliumAuthPolicy Patterns

**Pattern 1: Require Authentication for All Ingress**:
```yaml
apiVersion: cilium.io/v2
kind: CiliumAuthPolicy
metadata:
  name: require-authn
  namespace: synergyflow
spec:
  endpointSelector: {}
  ingress:
    - authentication:
        mode: required
```

**Pattern 2: Allowlist Specific Service Accounts**:
```yaml
apiVersion: cilium.io/v2
kind: CiliumAuthPolicy
metadata:
  name: allow-api-sa
  namespace: synergyflow
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: synergyflow
      authentication:
        mode: required
        spiffe:
          allowPatterns:
            - "spiffe://example.com/ns/synergyflow/sa/api"
```

**Pattern 3: Cross-Namespace with Identity**:
```yaml
apiVersion: cilium.io/v2
kind: CiliumAuthPolicy
metadata:
  name: allow-monitoring
  namespace: synergyflow
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: observability
      authentication:
        mode: required
        spiffe:
          allowPatterns:
            - "spiffe://example.com/ns/observability/sa/vmagent"
            - "spiffe://example.com/ns/observability/sa/prometheus"
```

**Pattern 4: Defense in Depth (CNP + CAP)**:
```yaml
# CiliumNetworkPolicy: network layer
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-internal
spec:
  endpointSelector: {}
  ingress:
    - fromCIDR:
        - 10.0.0.0/8  # Cluster CIDR
---
# CiliumAuthPolicy: identity layer
apiVersion: cilium.io/v2
kind: CiliumAuthPolicy
metadata:
  name: require-authn
spec:
  endpointSelector: {}
  ingress:
    - authentication:
        mode: required
```

### Security Hardening

**PSA Restricted**:
- Namespace enforces restricted Pod Security Standards
- All containers run as non-root
- ReadOnlyRootFilesystem where possible
- Capabilities dropped

**Socket Security**:
- SPIRE agent socket on hostPath: `/run/spire/sockets/agent.sock`
- Permissions: 0755 (directory), 0600 (socket)
- Only Cilium and SPIRE agent have access

**SVID Rotation**:
- Default TTL: 1 hour
- Automatic rotation at 50% TTL
- No manual intervention required

### Storage Strategy

**SPIRE Server**:
- SQLite datastore for single-node deployments
- PostgreSQL datastore for HA deployments (3 replicas)
- PVC: 1Gi (registration entries, trust bundle)
- Backup: PVC snapshots + trust bundle export

**SPIRE Agent**:
- emptyDir for cache
- No persistent storage required
- Re-attests to server on pod restart

### High Availability

**Single-Node (Default)**:
- 1 SPIRE server replica
- SQLite datastore
- PVC for data persistence
- Recovery: pod restart reads from PVC

**Multi-Node (HA)**:
- 3 SPIRE server replicas
- PostgreSQL shared datastore
- Shared trust bundle via ConfigMap
- Load balancing via Service

### Migration Strategy

**Phase 1: Deploy SPIRE (This Story)**:
- Install SPIRE server and agents
- Enable Cilium authentication (feature flag)
- No enforcement yet

**Phase 2: Gradual Enforcement (Story 45)**:
- Apply CAP to low-risk namespaces first
- Monitor Hubble for denied flows
- Adjust policies based on observed traffic

**Phase 3: Full Enforcement**:
- Apply CAP to all production namespaces
- Remove feature flag (always-on authentication)
- Disable IP-based fallback

### Troubleshooting

**SPIRE Server Not Ready**:
1. Check logs: `kubectl logs -n spire sts/spire-server`
2. Common issues:
   - PVC mount failed
   - Insufficient RBAC permissions
   - Trust bundle generation failed
3. Health check: `kubectl exec -n spire sts/spire-server -- /opt/spire/bin/spire-server healthcheck`

**SPIRE Agent Not Ready**:
1. Check logs: `kubectl logs -n spire ds/spire-agent`
2. Common issues:
   - Cannot connect to server
   - Node attestation failed (PSAT token invalid)
   - Socket permission denied
3. Verify server connectivity: `kubectl exec -n spire ds/spire-agent -- nc -zv spire-server.spire.svc.cluster.local 8081`

**Authentication Failing**:
1. Check Cilium logs: `kubectl logs -n kube-system ds/cilium | grep -i auth`
2. Common issues:
   - SPIRE socket not mounted
   - SVID expired or not issued
   - Trust domain mismatch
3. Inspect workload SVID: `kubectl exec -n spire ds/spire-agent -- /opt/spire/bin/spire-agent api fetch x509`

**CiliumAuthPolicy Not Enforcing**:
1. Check policy status: `kubectl get ciliumauthpolicy -A`
2. Common issues:
   - Cilium authentication disabled
   - Policy selector not matching pods
   - SPIFFE ID pattern incorrect
3. Debug with Hubble: `cilium hubble observe --verdict DROPPED --authentication-type all`

**SVID Not Rotating**:
1. Check agent logs for rotation events
2. Common issues:
   - Agent cannot reach server
   - Registration entry deleted
   - Trust bundle expired
3. Force re-attestation: restart agent pod

### Performance Considerations

**SPIRE Agent Resource Usage**:
- Baseline: 100m CPU, 128Mi memory
- Scales with pod count per node
- Monitor: `spire_agent_workload_api_*` metrics

**Cilium Overhead**:
- mTLS handshake adds latency (~5-10ms)
- CPU overhead: ~5-10% for proxy
- Monitor: Hubble flow latency metrics

**SVID Cache**:
- Agent caches SVIDs locally
- Reduces server load
- TTL: 1 hour (configurable)

### Backup and Disaster Recovery

**Trust Bundle Backup**:
```bash
# Export trust bundle
kubectl -n spire get configmap spire-bundle -o yaml > trust-bundle-backup.yaml

# Restore trust bundle
kubectl apply -f trust-bundle-backup.yaml
```

**Registration Entries Backup**:
```bash
# Export entries
kubectl exec -n spire sts/spire-server -- /opt/spire/bin/spire-server entry show -output json > entries-backup.json

# Re-create entries (scripted)
cat entries-backup.json | jq -r '.entries[] | "entry create -parentID \(.parent_id) -spiffeID \(.spiffe_id) -selector \(.selectors | map("\(.type):\(.value)") | join(" -selector "))"' | while read cmd; do
  kubectl exec -n spire sts/spire-server -- /opt/spire/bin/spire-server $cmd
done
```

**Server Data PVC Backup**:
- Use VolumeSnapshot for PVC
- Scheduled backups via external tools
- Test restore procedures

### Future Enhancements

**Federation for ClusterMesh**:
- Configure SPIRE federation between clusters
- Share trust bundles via ClusterMesh
- Enable cross-cluster authenticated services

**PostgreSQL Datastore for HA**:
- Replace SQLite with shared PostgreSQL
- 3 SPIRE server replicas
- Load balancing for agent connections

**Advanced Attestation**:
- Hardware-based attestation (TPM)
- Custom workload attestors
- Nested SPIRE hierarchies

**Policy Automation**:
- Auto-generate CAP from service mesh topology
- GitOps workflow for registration entries
- Policy drift detection

## Change Log

### v3.0 (2025-10-26) - Manifests-First Architecture Refinement

**Refined Story to Separate Manifest Creation from Deployment**:
1. **Updated header**: Changed title to "Create SPIRE & Cilium mTLS Authentication Manifests", status to "Draft (v3.0 Refinement)", date to 2025-10-26
2. **Rewrote story**: Focus on creating manifests for SPIRE workload identity and Cilium authentication for zero-trust security
3. **Split scope**:
   - This Story: Create SPIRE infrastructure, update Cilium config, create example auth policies, local validation
   - Story 45: Deploy to clusters, test authentication, validate Hubble flows, end-to-end testing
4. **Created 11 acceptance criteria** for manifest creation (AC1-AC11):
   - AC1: SPIRE infrastructure manifests (namespace, server, agent, RBAC, ConfigMaps, Service)
   - AC2: SPIRE server config (trust domain, storage, attestors, health checks)
   - AC3: SPIRE agent config (socket, attestation, resources, tolerations)
   - AC4: Cilium HelmRelease authentication update (feature flag, SPIRE integration)
   - AC5: Example CiliumAuthPolicy manifests (require-spiffe-mtls, combined CNP+CAP)
   - AC6: Monitoring (PodMonitors, PrometheusRules with 7 alerts)
   - AC7: Flux Kustomization (health checks, dependencies, timeout)
   - AC8: Security hardening (PSA restricted, non-root, PDB)
   - AC9: Trust domain documentation (SVID format, registration patterns)
   - AC10: Local validation (dry-run, flux build, kubeconform)
   - AC11: Comprehensive documentation (architecture, usage, troubleshooting)
5. **Updated dependencies**: Local tools only (kubectl, flux CLI, yq, kubeconform), story dependencies (Cilium, baseline NetworkPolicies)
6. **Restructured tasks** to T1-T24:
   - T1: Prerequisites and strategy
   - T2: SPIRE namespace with PSA restricted
   - T3: SPIRE server RBAC (ClusterRole for workload attestation)
   - T4: SPIRE server ConfigMap (trust domain, plugins, health checks)
   - T5: SPIRE server StatefulSet (1 replica, PVC, security context, resources, probes, PDB)
   - T6: SPIRE server Service (ClusterIP, gRPC API)
   - T7: SPIRE agent RBAC (ClusterRole for pod discovery)
   - T8: SPIRE agent ConfigMap (server address, socket path, attestors)
   - T9: SPIRE agent DaemonSet (hostPath socket, security context, resources, tolerations)
   - T10: SPIRE monitoring (PodMonitors for server and agent)
   - T11: SPIRE alerting (VMRule with 7 alerts)
   - T12: SPIRE Kustomization
   - T13: Cilium HelmRelease authentication update (feature flag, SPIRE socket, trust domain)
   - T14-T15: Example CiliumAuthPolicy components
   - T16: Auth policy component Kustomization
   - T17: Multi-namespace auth policy example
   - T18: Auth policy README (usage, patterns, troubleshooting)
   - T19: SPIRE Flux Kustomization (health checks, dependencies)
   - T20: Infrastructure Kustomization update
   - T21: SPIRE deployment README (architecture, trust domain, registration, troubleshooting, upgrade, backup, HA)
   - T22: Cluster settings update (feature flag, replicas)
   - T23: Local validation (dry-run, flux build, kubeconform, yamllint)
   - T24: Git commit
7. **Added "Runtime Validation (MOVED TO STORY 45)" section** with comprehensive testing:
   - SPIRE server and agent validation (health checks, registration entries, trust bundle)
   - Cilium authentication validation (config, status, socket mount)
   - CiliumAuthPolicy enforcement testing (authenticated vs unauthenticated access)
   - SVID validation (fetch, format, rotation)
   - Monitoring validation (metrics, alerts)
   - Cross-cluster trust testing (federation)
   - Rollback testing (disable authentication)
8. **Updated DoD** with clear separation:
   - "Manifest Creation Complete (This Story)": All manifests created, validated locally, documented, committed
   - "NOT Part of DoD (Moved to Story 45)": Deployment, runtime testing, authentication enforcement, monitoring alerts
9. **Added comprehensive design notes**:
   - SPIRE architecture (server, agent, Cilium integration)
   - Trust domain strategy (single domain for both clusters)
   - Workload attestation (K8s attestor, selectors, registration examples)
   - CiliumAuthPolicy patterns (require authn, allowlist SAs, cross-namespace, defense in depth)
   - Security hardening (PSA, socket permissions, SVID rotation)
   - Storage strategy (SQLite vs PostgreSQL)
   - High availability (single-node vs multi-node)
   - Migration strategy (deploy, gradual enforcement, full enforcement)
   - Troubleshooting (server/agent/authentication/policy issues)
   - Performance considerations (resource usage, mTLS overhead, caching)
   - Backup and disaster recovery (trust bundle, registration entries, PVC)
   - Future enhancements (federation, PostgreSQL HA, advanced attestation, policy automation)
10. **Preserved original context**: Sprint 6, Lane Security, dependencies on Cilium GitOps story

**Gaps Identified and Fixed**:
- Added Cilium authentication feature flag for safe rollout
- Added PodDisruptionBudget for SPIRE server HA
- Added comprehensive monitoring (PodMonitors, 7 alerts)
- Added example CiliumAuthPolicy components for reusability
- Added combined CNP + CAP for defense in depth
- Added detailed trust domain and SVID documentation
- Added migration strategy for gradual policy enforcement
- Added troubleshooting procedures for common issues
- Added backup/restore procedures for trust material

**Why v3.0**:
- Enforces clean separation: Story 28 = CREATE manifests (local), Story 45 = DEPLOY & VALIDATE (cluster)
- Enables parallel work: manifest creation can proceed without cluster access
- Improves testing: all manifests validated locally before any deployment
- Reduces risk: deployment issues don't block manifest refinement work
- Maintains GitOps principles: manifest creation is pure IaC work
