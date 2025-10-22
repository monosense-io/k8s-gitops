# 05 — STORY-DNS-COREDNS-BASE — CoreDNS via GitOps

Sequence: 05/41 | Prev: STORY-NET-CILIUM-GATEWAY.md | Next: STORY-SEC-CERT-MANAGER-ISSUERS.md
Sprint: 1 | Lane: Networking
Global Sequence: 5/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; docs/_freeze/2025-10-21/architecture.v4.md §9; kubernetes/infrastructure/networking/coredns; kubernetes/bases/coredns

## Story
Manage CoreDNS via Flux with per‑cluster replica and ClusterIP settings, enable metrics and health/ready endpoints, and adopt safe HA + security defaults. Include guidance for optional NodeLocal DNSCache and autoscaling.

## Why / Outcome
- Deterministic DNS deployment aligned to cluster settings; observability coverage.

## Scope
- Resources: `kubernetes/infrastructure/networking/coredns/kustomization.yaml` (uses `bases/coredns`).

## Acceptance Criteria
1) CoreDNS Deployment `coredns` Available with replicas `${COREDNS_REPLICAS}`; PodDisruptionBudget enabled (minAvailable ≥ 1); anti‑affinity or topology spread in effect across nodes.
2) Service `kube-dns` present in `kube-system` with static ClusterIP `${COREDNS_CLUSTER_IP}`; DNS lookups from pods succeed for service, pod, and external names.
3) Metrics on `:9153` are scraped (ServiceMonitor enabled) and common `coredns_*` time series are visible in VictoriaMetrics.
4) Health/Ready endpoints respond (`health` on :8080, `ready` on :8181) for each CoreDNS pod.
5) Security: pods run as non‑root with read‑only root FS and no added capabilities; NetworkPolicy/Cilium policy allows DNS to CoreDNS from workloads while blocking unintended sources.
6) Version alignment: chart/tag matches architecture target (currently 1.38.0); any drift is documented with an upgrade plan.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS.

## Tasks / Subtasks

### 🔧 Phase 1: Foundation & Configuration (Critical - Complete First)

- [ ] **1.1 Version Upgrade**: Update `kubernetes/bases/coredns/helmrelease.yaml` OCIRepository `ref.tag` from `1.35.0` to `1.38.0` to match architecture target.
  - File: `kubernetes/bases/coredns/helmrelease.yaml:11`
  - Current: `tag: 1.35.0`
  - Target: `tag: 1.38.0`
  - Verify chart compatibility with Kubernetes 1.31.x

- [ ] **1.2 HA Topology Spread**: Add `topologySpreadConstraints` to HelmRelease values for node distribution.
  - File: `kubernetes/bases/coredns/helmrelease.yaml`
  - Add to `spec.values`:
    ```yaml
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            k8s-app: kube-dns
    ```
  - Ensures 2 replicas spread across different nodes with soft constraint

- [ ] **1.3 Resource Limits**: Add resource requests and limits for predictable QoS.
  - File: `kubernetes/bases/coredns/helmrelease.yaml`
  - Add to `spec.values`:
    ```yaml
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    ```
  - Provides Burstable QoS class suitable for DNS workload

- [ ] **1.4 Security Context**: Verify chart provides secure defaults; add explicit overrides if needed.
  - File: `kubernetes/bases/coredns/helmrelease.yaml`
  - Verify rendered manifest includes:
    - `securityContext.runAsNonRoot: true`
    - `securityContext.readOnlyRootFilesystem: true`
    - `securityContext.allowPrivilegeEscalation: false`
    - `securityContext.capabilities.drop: [ALL]`
  - If not present in chart defaults, add explicit `securityContext` to `spec.values`

- [ ] **1.5 Health Probes**: Verify liveness and readiness probe configuration in chart defaults.
  - Expected configuration:
    - `livenessProbe`: HTTP GET `:8080/health`, initialDelaySeconds: 60, periodSeconds: 10
    - `readinessProbe`: HTTP GET `:8181/ready`, initialDelaySeconds: 5, periodSeconds: 10
  - Document probe endpoints for operational reference

### 🚀 Phase 2: Deployment & Multi-Cluster Verification

- [ ] **2.1 Pre-Deploy Validation**: Run Flux build to catch configuration errors before deployment.
  ```bash
  flux build kustomization cluster-infra-coredns --path kubernetes/infrastructure/networking/coredns
  flux build kustomization cluster-apps-coredns --path kubernetes/infrastructure/networking/coredns
  ```
  - Verify no template errors, valid YAML output

- [ ] **2.2 Reconcile Infra Cluster**: Deploy CoreDNS to infra cluster via Flux.
  ```bash
  flux reconcile kustomization cluster-infra-coredns --with-source
  flux reconcile helmrelease -n kube-system coredns
  ```
  - Monitor: `kubectl --context infra -n kube-system get helmrelease coredns -w`
  - Wait for Ready status

- [ ] **2.3 Verify Infra Deployment**: Validate CoreDNS deployment on infra cluster.
  ```bash
  kubectl --context infra -n kube-system get deploy coredns
  kubectl --context infra -n kube-system get pods -l k8s-app=kube-dns -o wide
  kubectl --context infra -n kube-system get pdb coredns-pdb
  ```
  - Verify: 2/2 replicas available, pods on different nodes, PDB minAvailable: 1

- [ ] **2.4 Verify Infra Cluster Settings Substitution**: Confirm cluster-specific values applied.
  ```bash
  kubectl --context infra -n kube-system get svc kube-dns -o yaml | grep clusterIP
  kubectl --context infra -n kube-system get deploy coredns -o yaml | grep -A 1 replicas
  ```
  - Expected clusterIP: `10.245.0.10` (from `kubernetes/clusters/infra/cluster-settings.yaml:30`)
  - Expected replicas: `2` (from `kubernetes/clusters/infra/cluster-settings.yaml:31`)

- [ ] **2.5 Reconcile Apps Cluster**: Deploy CoreDNS to apps cluster via Flux.
  ```bash
  flux reconcile kustomization cluster-apps-coredns --with-source
  flux reconcile helmrelease -n kube-system coredns
  ```
  - Monitor: `kubectl --context apps -n kube-system get helmrelease coredns -w`

- [ ] **2.6 Verify Apps Deployment**: Validate CoreDNS deployment on apps cluster.
  ```bash
  kubectl --context apps -n kube-system get deploy coredns
  kubectl --context apps -n kube-system get pods -l k8s-app=kube-dns -o wide
  kubectl --context apps -n kube-system get pdb coredns-pdb
  ```
  - Verify: 2/2 replicas available, pods on different nodes

- [ ] **2.7 Verify Apps Cluster Settings Substitution**: Confirm cluster-specific values applied.
  ```bash
  kubectl --context apps -n kube-system get svc kube-dns -o yaml | grep clusterIP
  ```
  - Expected clusterIP: `10.247.0.10` (from `kubernetes/clusters/apps/cluster-settings.yaml:30`)

### 🧪 Phase 3: Integration & Functional Testing

- [ ] **3.1 DNS Resolution Test - Internal Services (Infra)**: Verify service DNS resolution.
  ```bash
  kubectl --context infra run -it --rm dns-test --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
  ```
  - Expected: Resolves to Kubernetes API service IP (10.245.0.1)

- [ ] **3.2 DNS Resolution Test - External Domains (Infra)**: Verify upstream DNS forwarding.
  ```bash
  kubectl --context infra run -it --rm dns-test --image=busybox --restart=Never -- nslookup example.com
  ```
  - Expected: Resolves to public IP via Cloudflare upstream

- [ ] **3.3 DNS Resolution Test - Pod DNS (Infra)**: Verify pod hostname resolution.
  ```bash
  kubectl --context infra run -it --rm dns-test --image=busybox --restart=Never -- nslookup <pod-ip>.default.pod.cluster.local
  ```
  - Expected: Resolves to pod IP

- [ ] **3.4 DNS Resolution Test - Apps Cluster**: Repeat DNS tests on apps cluster.
  ```bash
  kubectl --context apps run -it --rm dns-test --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
  kubectl --context apps run -it --rm dns-test --image=busybox --restart=Never -- nslookup example.com
  ```
  - Verify both internal and external resolution work

- [ ] **3.5 Network Policy Validation**: Verify CiliumNetworkPolicy allows DNS traffic.
  ```bash
  kubectl --context infra get ciliumnetworkpolicy -A | grep allow-dns
  kubectl --context infra -n kube-system get cnp allow-dns -o yaml
  ```
  - Verify policy exists in component: `kubernetes/components/networkpolicy/allow-dns/ciliumnetworkpolicy.yaml`
  - Confirm policy allows traffic to k8s-app: kube-dns and k8s-app: coredns labels

- [ ] **3.6 Bootstrap Dependency Chain Test**: Verify Spegel can start (depends on CoreDNS).
  ```bash
  kubectl --context infra -n kube-system get pods -l app.kubernetes.io/name=spegel
  kubectl --context infra -n kube-system logs -l app.kubernetes.io/name=spegel --tail=50
  ```
  - Expected: Spegel pods running, no DNS resolution errors in logs

- [ ] **3.7 cert-manager DNS Validation**: Verify cert-manager can resolve external DNS.
  ```bash
  kubectl --context infra -n cert-manager logs -l app=cert-manager --tail=50 | grep -i dns
  ```
  - Expected: No DNS resolution errors for ACME challenges

### 📊 Phase 4: Observability & Operational Validation

- [ ] **4.1 Metrics Endpoint Test**: Verify Prometheus metrics exposed on :9153.
  ```bash
  kubectl --context infra -n kube-system port-forward deploy/coredns 9153:9153
  curl http://localhost:9153/metrics | grep coredns_dns_requests_total
  ```
  - Expected: Metrics endpoint returns Prometheus-format metrics

- [ ] **4.2 ServiceMonitor Discovery**: Verify VictoriaMetrics scrapes CoreDNS metrics.
  ```bash
  kubectl --context infra -n kube-system get servicemonitor coredns -o yaml
  kubectl --context infra -n observability logs -l app.kubernetes.io/name=vmagent --tail=100 | grep coredns
  ```
  - Expected: ServiceMonitor exists, vmagent discovers and scrapes target

- [ ] **4.3 Metrics in VictoriaMetrics**: Query CoreDNS metrics from VM.
  ```bash
  kubectl --context infra -n observability port-forward svc/victoria-metrics-vmselect 8481:8481
  curl "http://localhost:8481/select/0/prometheus/api/v1/query?query=coredns_dns_requests_total"
  ```
  - Expected: Time series data returned for CoreDNS metrics

- [ ] **4.4 PrometheusRule Validation**: Verify alert rules loaded and functional.
  ```bash
  kubectl --context infra -n kube-system get prometheusrule coredns -o yaml
  ```
  - Verify rules exist: CoreDNSAbsent, CoreDNSDown, CoreDNSHighQueryRate, CoreDNSHighErrorRate, CoreDNSLatencyHigh
  - File: `kubernetes/infrastructure/networking/coredns/prometheusrule.yaml`

- [ ] **4.5 Health Endpoint Test**: Verify health check endpoint responds.
  ```bash
  kubectl --context infra -n kube-system port-forward deploy/coredns 8080:8080
  curl -v http://localhost:8080/health
  ```
  - Expected: HTTP 200 OK response

- [ ] **4.6 Ready Endpoint Test**: Verify readiness check endpoint responds.
  ```bash
  kubectl --context infra -n kube-system port-forward deploy/coredns 8181:8181
  curl -v http://localhost:8181/ready
  ```
  - Expected: HTTP 200 OK response

- [ ] **4.7 HA Resilience Test - Rolling Update**: Test CoreDNS availability during update.
  ```bash
  kubectl --context infra -n kube-system rollout restart deployment coredns
  kubectl --context infra -n kube-system rollout status deployment coredns
  ```
  - While rolling: continuously test DNS resolution from another terminal
  - Expected: Zero DNS lookup failures during rollout

- [ ] **4.8 HA Resilience Test - Node Drain**: Test CoreDNS during node maintenance.
  ```bash
  # Identify node with CoreDNS pod
  kubectl --context infra -n kube-system get pods -l k8s-app=kube-dns -o wide
  # Drain that node
  kubectl --context infra drain <node-name> --ignore-daemonsets --delete-emptydir-data
  ```
  - Monitor: PDB should prevent draining last available replica
  - Expected: DNS resolution continues with remaining replica

### 📚 Phase 5: Documentation & Follow-up

- [ ] **5.1 Document Corefile Configuration**: Review and document final Corefile config.
  ```bash
  kubectl --context infra -n kube-system get configmap coredns -o yaml
  ```
  - Document upstream DNS servers (should be Cloudflare 1.1.1.1, 1.0.0.1)
  - Document cache TTL settings
  - Document enabled plugins: kubernetes, forward, cache, prometheus, health, ready, log

- [ ] **5.2 Document Security Baseline**: Record security context configuration in dev notes.
  ```bash
  kubectl --context infra -n kube-system get pod -l k8s-app=kube-dns -o yaml | grep -A 10 securityContext
  ```
  - Attach rendered pod spec security context to story notes

- [ ] **5.3 Document Network Policy Pattern**: Document how workload namespaces integrate allow-dns policy.
  - Reference: `kubernetes/components/networkpolicy/allow-dns/`
  - Pattern: Namespaces include `../../../components/networkpolicy/allow-dns` in kustomization

- [ ] **5.4 Create Follow-up Story - NodeLocal DNSCache**: Evaluate and document NodeLocal DNSCache.
  - Research: Compatibility with Cilium and Talos
  - Document: Latency improvements, autopath plugin interactions
  - Decision: Create STORY-DNS-NODELOCAL-CACHE if benefits outweigh complexity

- [ ] **5.5 Create Follow-up Story - Autoscaling**: Evaluate Cluster Proportional Autoscaler (CPA).
  - Research: CPA vs HPA for CoreDNS
  - Document: Scaling formula based on node count and pod count
  - Decision: Create STORY-DNS-COREDNS-AUTOSCALE if needed for large-scale deployments

## Validation Steps

### ✅ Acceptance Criteria Validation Matrix

| AC # | Criterion | Validation Command | Expected Result | Status |
|------|-----------|-------------------|-----------------|--------|
| AC1 | Deployment Available with 2 replicas | `kubectl --context=infra -n kube-system get deploy coredns` | 2/2 READY | ⬜ |
| AC1 | PDB enabled minAvailable: 1 | `kubectl --context=infra -n kube-system get pdb coredns-pdb -o yaml \| grep minAvailable` | minAvailable: 1 | ⬜ |
| AC1 | Pods on different nodes | `kubectl --context=infra -n kube-system get pods -l k8s-app=kube-dns -o wide` | Different NODE values | ⬜ |
| AC2 | Service name kube-dns | `kubectl --context=infra -n kube-system get svc kube-dns` | Service exists | ⬜ |
| AC2 | Static ClusterIP (infra) | `kubectl --context=infra -n kube-system get svc kube-dns -o yaml \| grep clusterIP` | 10.245.0.10 | ⬜ |
| AC2 | Static ClusterIP (apps) | `kubectl --context=apps -n kube-system get svc kube-dns -o yaml \| grep clusterIP` | 10.247.0.10 | ⬜ |
| AC2 | Internal service resolution | `kubectl --context=infra run dns-test --rm -it --image=busybox -- nslookup kubernetes.default` | Resolves to 10.245.0.1 | ⬜ |
| AC2 | External domain resolution | `kubectl --context=infra run dns-test --rm -it --image=busybox -- nslookup example.com` | Resolves to public IP | ⬜ |
| AC2 | Pod DNS resolution | `kubectl --context=infra run dns-test --rm -it --image=busybox -- nslookup <pod-ip>.default.pod.cluster.local` | Resolves to pod IP | ⬜ |
| AC3 | Metrics endpoint exposed | `kubectl --context=infra -n kube-system port-forward deploy/coredns 9153 & curl localhost:9153/metrics` | Prometheus metrics returned | ⬜ |
| AC3 | ServiceMonitor enabled | `kubectl --context=infra -n kube-system get servicemonitor coredns` | ServiceMonitor exists | ⬜ |
| AC3 | Metrics in VictoriaMetrics | Query `coredns_dns_requests_total` via VM UI/API | Time series data present | ⬜ |
| AC4 | Health endpoint responds | `kubectl --context=infra -n kube-system port-forward deploy/coredns 8080 & curl localhost:8080/health` | HTTP 200 OK | ⬜ |
| AC4 | Ready endpoint responds | `kubectl --context=infra -n kube-system port-forward deploy/coredns 8181 & curl localhost:8181/ready` | HTTP 200 OK | ⬜ |
| AC5 | Pod runs as non-root | `kubectl --context=infra -n kube-system get pod -l k8s-app=kube-dns -o yaml \| grep runAsNonRoot` | runAsNonRoot: true | ⬜ |
| AC5 | Read-only root filesystem | `kubectl --context=infra -n kube-system get pod -l k8s-app=kube-dns -o yaml \| grep readOnlyRootFilesystem` | readOnlyRootFilesystem: true | ⬜ |
| AC5 | Capabilities dropped | `kubectl --context=infra -n kube-system get pod -l k8s-app=kube-dns -o yaml \| grep -A 1 drop` | drop: [ALL] | ⬜ |
| AC5 | CiliumNetworkPolicy exists | `kubectl --context=infra get cnp -A \| grep allow-dns` | Policy present in namespaces | ⬜ |
| AC5 | DNS traffic allowed | Test DNS from workload namespace pod | Resolution succeeds | ⬜ |
| AC6 | Version 1.38.0 deployed | `kubectl --context=infra -n kube-system get pod -l k8s-app=kube-dns -o yaml \| grep 'image:.*coredns'` | coredns:1.38.0 | ⬜ |

### 🔄 Multi-Cluster Validation

Repeat core validation on BOTH clusters:

**Infra Cluster:**
```bash
export CTX=infra
kubectl --context=$CTX -n kube-system get deploy,pdb,svc,pods -l k8s-app=kube-dns
kubectl --context=$CTX run dns-test --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

**Apps Cluster:**
```bash
export CTX=apps
kubectl --context=$CTX -n kube-system get deploy,pdb,svc,pods -l k8s-app=kube-dns
kubectl --context=$CTX run dns-test --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

### 🧪 Integration Testing

**Bootstrap Dependency Chain:**
```bash
# Verify Cilium → CoreDNS → Spegel chain
kubectl --context=infra -n kube-system get pods -l k8s-app=cilium
kubectl --context=infra -n kube-system get pods -l k8s-app=kube-dns
kubectl --context=infra -n kube-system get pods -l app.kubernetes.io/name=spegel
# All should be Running with 0 restarts
```

**cert-manager ACME DNS Validation:**
```bash
# Verify cert-manager can resolve external DNS for ACME challenges
kubectl --context=infra -n cert-manager get challenges
kubectl --context=infra -n cert-manager logs -l app=cert-manager --tail=50 | grep -i "dns\|acme"
```

### 📊 Observability Validation

**Metrics Flow:**
```bash
# 1. Verify metrics exposed
kubectl --context=infra -n kube-system port-forward deploy/coredns 9153:9153 &
curl -s http://localhost:9153/metrics | grep -E "coredns_(dns_requests_total|dns_responses_total|cache_hits_total)"

# 2. Verify ServiceMonitor scraped
kubectl --context=infra -n kube-system get servicemonitor coredns -o yaml

# 3. Query from VictoriaMetrics
# Access Grafana or vmselect and query: rate(coredns_dns_requests_total[5m])
```

**Alert Rules:**
```bash
# Verify PrometheusRules loaded
kubectl --context=infra -n kube-system get prometheusrule coredns -o yaml

# Check alert definitions present:
# - CoreDNSAbsent, CoreDNSDown, CoreDNSHighQueryRate, CoreDNSHighErrorRate
# - CoreDNSLatencyHigh, CoreDNSForwardLatencyHigh, CoreDNSCacheOverflow
```

### 🛡️ Security Validation

**Pod Security Context:**
```bash
kubectl --context=infra -n kube-system get pod -l k8s-app=kube-dns -o yaml | yq '.items[0].spec.containers[0].securityContext'
# Expected output should include:
#   runAsNonRoot: true
#   readOnlyRootFilesystem: true
#   allowPrivilegeEscalation: false
#   capabilities:
#     drop:
#       - ALL
```

**Network Policy Enforcement:**
```bash
# Verify CiliumNetworkPolicy allows DNS
kubectl --context=infra get cnp -A | grep allow-dns
kubectl --context=infra -n kube-system get cnp allow-dns -o yaml

# Test from workload namespace
kubectl --context=infra -n default run net-test --rm -it --image=busybox -- nslookup kubernetes.default
# Should succeed
```

### 🔥 Resilience Testing

**Rolling Update Test:**
```bash
# Terminal 1: Continuous DNS testing
while true; do kubectl --context=infra run dns-test-$RANDOM --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default; sleep 2; done

# Terminal 2: Trigger rolling update
kubectl --context=infra -n kube-system rollout restart deployment coredns
kubectl --context=infra -n kube-system rollout status deployment coredns

# Expected: Zero DNS failures in Terminal 1 during rollout
```

**Node Drain Test:**
```bash
# Identify node with CoreDNS pod
NODE=$(kubectl --context=infra -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.nodeName}')

# Attempt drain
kubectl --context=infra drain $NODE --ignore-daemonsets --delete-emptydir-data

# Expected: PDB prevents draining if it would leave <1 available replica
# DNS resolution should continue via remaining replica(s)
```

## Definition of Done
- ACs met; outputs attached to Dev Notes.
