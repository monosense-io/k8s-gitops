# Hubble Observability Guide

**Date:** 2025-10-15
**Architecture:** Cilium + Hubble + Jaeger on 2-Cluster Talos Infrastructure

---

## 📋 Overview

**Hubble** is the observability layer for Cilium that provides deep visibility into network traffic and service dependencies. It enables:

- **L7 Network Observability**: Protocol-aware flow monitoring (HTTP, gRPC, DNS, Kafka, etc.)
- **Service Dependency Maps**: Real-time visualization of service communication
- **Golden Metrics**: Success rate, Request Per Second (RPS), and latency (p50, p95, p99)
- **Distributed Tracing**: Integration with Jaeger for end-to-end trace visualization
- **Security Monitoring**: Visualize network policy enforcement and dropped packets
- **Troubleshooting**: Real-time network flow debugging

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Cilium Agent                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              eBPF Programs (kernel level)             │  │
│  │  ├─ L3/L4 networking                                  │  │
│  │  ├─ L7 protocol parsing (HTTP, gRPC, DNS, Kafka)     │  │
│  │  └─ Flow capture                                      │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼──────────────────────────────┐  │
│  │           Hubble Server (per-node)                    │  │
│  │  ├─ Flow aggregation                                  │  │
│  │  ├─ Metrics generation                                │  │
│  │  └─ gRPC API                                          │  │
│  └────────────────────────┬──────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            │ gRPC
                            ▼
           ┌────────────────────────────────┐
           │      Hubble Relay              │
           │  (Cluster-wide aggregator)     │
           │  ├─ Aggregates flows from all  │
           │  │  nodes                       │
           │  ├─ Provides cluster-wide view │
           │  └─ gRPC API                   │
           └────────────┬──────────┬────────┘
                        │          │
        ┌───────────────┘          └──────────────┐
        │                                         │
        ▼                                         ▼
┌───────────────┐                   ┌──────────────────────┐
│  Hubble UI    │                   │  Hubble CLI          │
│  (Web)        │                   │  (Terminal)          │
│  ├─ Service   │                   │  ├─ Flow queries     │
│  │  Map       │                   │  ├─ Real-time watch  │
│  └─ Flows     │                   │  └─ Filtering        │
└───────────────┘                   └──────────────────────┘

        │                                         │
        └─────────────────┬───────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────┐
        │  External Observability         │
        │  ├─ Victoria Metrics (metrics)  │
        │  ├─ Jaeger (traces)             │
        │  └─ Grafana (dashboards)        │
        └─────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Cilium deployed with Hubble enabled (already done in Week 1-2)
- Hubble CLI installed locally

### Install Hubble CLI

```bash
# macOS
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-darwin-amd64.tar.gz{,.sha256sum}
shasum -a 256 -c hubble-darwin-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-darwin-amd64.tar.gz /usr/local/bin
rm hubble-darwin-amd64.tar.gz{,.sha256sum}

# Verify
hubble version
```

### Access Hubble

#### Option 1: Port Forward (Development)

```bash
# Port forward to Hubble Relay
cilium hubble port-forward --context infra

# In another terminal, query flows
hubble status
hubble observe
```

#### Option 2: Hubble UI (Visual)

```bash
# Launch Hubble UI (automatically port forwards)
cilium hubble ui --context infra

# Opens http://localhost:12000
```

---

## 📊 Observing Network Flows

### Basic Flow Observation

```bash
# View all flows in real-time
hubble observe --context infra

# Output format:
# <timestamp> <source-pod> -> <destination-pod>: <protocol> <details>
```

### Filter by Namespace

```bash
# Flows in specific namespace
hubble observe --namespace gitlab --context apps

# Flows FROM a namespace
hubble observe --from-namespace gitlab --context apps

# Flows TO a namespace
hubble observe --to-namespace databases --context apps
```

### Filter by Pod/Service

```bash
# Flows from specific pod
hubble observe --from-pod frontend-abc123 --context apps

# Flows to specific service
hubble observe --to-service postgres-rw --context apps

# Flows between specific pods
hubble observe \
  --from-pod frontend-abc123 \
  --to-pod backend-def456 \
  --context apps
```

### Filter by Protocol

```bash
# HTTP traffic only
hubble observe --protocol http --context apps

# DNS queries
hubble observe --protocol dns --context apps

# TCP connections
hubble observe --protocol tcp --context apps

# gRPC calls
hubble observe --protocol grpc --context apps
```

### Filter by Verdict

```bash
# Successful flows (forwarded)
hubble observe --verdict FORWARDED --context apps

# Dropped packets (policy violations)
hubble observe --verdict DROPPED --context apps

# Both
hubble observe --verdict DROPPED,FORWARDED --context apps
```

### Filter by Direction

```bash
# Ingress traffic only
hubble observe --type trace:to-endpoint --context apps

# Egress traffic only
hubble observe --type trace:from-endpoint --context apps
```

---

## 🎯 Common Use Cases

### Use Case 1: Debug Connection Issues

```bash
# Problem: Frontend can't reach backend

# Step 1: Check if traffic is reaching backend
hubble observe \
  --from-pod frontend-abc123 \
  --to-pod backend-def456 \
  --context apps

# Step 2: Look for dropped packets
hubble observe \
  --from-pod frontend-abc123 \
  --to-pod backend-def456 \
  --verdict DROPPED \
  --context apps

# Step 3: Check specific port
hubble observe \
  --from-pod frontend-abc123 \
  --to-pod backend-def456 \
  --port 8080 \
  --context apps

# If no flows shown: DNS issue or network policy blocking
# If DROPPED verdict: Network policy violation
# If FORWARDED but no response: Backend application issue
```

### Use Case 2: Verify Cross-Cluster Communication

```bash
# View traffic from apps cluster to infra cluster services
hubble observe \
  --context apps \
  --from-namespace gitlab \
  --to-namespace databases

# Should show flows like:
# gitlab/webservice-xxx -> databases/postgres-rw-yyy: TCP 5432

# Verify encryption
cilium encrypt status --context apps
# WireGuard tunnels should be established
```

### Use Case 3: Monitor API Call Success Rate

```bash
# View HTTP traffic with response codes
hubble observe \
  --protocol http \
  --namespace gitlab \
  --context apps

# Output shows:
# gitlab/webservice -> gitlab/gitaly: HTTP/1.1 GET http://gitaly.gitlab:8075/... -> 200

# Count 2xx vs 5xx responses
hubble observe --protocol http --namespace gitlab -o json | \
  jq -r '.l7.http.code' | sort | uniq -c
```

### Use Case 4: Identify Noisy Services

```bash
# Services making the most connections
hubble observe --context apps --output jsonpb | \
  jq -r '.source.namespace + "/" + .source.pod_name' | \
  sort | uniq -c | sort -rn | head -20

# Top destination services
hubble observe --context apps --output jsonpb | \
  jq -r '.destination.namespace + "/" + .destination.pod_name' | \
  sort | uniq -c | sort -rn | head -20
```

### Use Case 5: DNS Query Monitoring

```bash
# All DNS queries in cluster
hubble observe --protocol dns --context apps

# DNS queries from specific namespace
hubble observe \
  --protocol dns \
  --from-namespace gitlab \
  --context apps

# Failed DNS queries (NXDOMAIN)
hubble observe --protocol dns --context apps | grep NXDOMAIN
```

---

## 📈 Metrics and Monitoring

### Prometheus Metrics Exported by Hubble

Hubble exports metrics in Prometheus format, automatically scraped by Victoria Metrics.

**Key metrics:**

```promql
# Total flows processed
hubble_flows_processed_total

# Dropped packets by reason
hubble_drop_total{reason="policy_denied"}

# HTTP request duration
hubble_http_request_duration_seconds

# HTTP requests by code
hubble_http_requests_total{code="200"}
hubble_http_requests_total{code="500"}

# DNS queries
hubble_dns_queries_total

# TCP connection states
hubble_tcp_flags_total
```

### Grafana Dashboards

Import Cilium/Hubble dashboards into Grafana:

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/victoria-metrics-stack-grafana 3000:80 --context infra

# Import dashboards from:
# https://github.com/cilium/cilium/tree/main/examples/kubernetes/addons/prometheus/files
```

**Recommended dashboards:**
1. **Cilium Overview**: Cluster-wide health and metrics
2. **Hubble L7 HTTP**: HTTP traffic patterns and errors
3. **Hubble DNS**: DNS query patterns and failures
4. **Cilium Network Policy**: Policy enforcement and drops

---

## 🔍 Distributed Tracing with Jaeger

Hubble can export network flows as distributed traces to Jaeger.

### Architecture

```
Application → Cilium eBPF → Hubble → OTLP Exporter → Jaeger Collector → Jaeger Storage
```

### Configuration

#### Step 1: Deploy Jaeger (Week 3, Day 1)

```yaml
# kubernetes/infrastructure/observability/jaeger/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: jaeger
  namespace: observability
spec:
  chart:
    spec:
      chart: jaeger
      version: 3.3.x
      sourceRef:
        kind: HelmRepository
        name: jaegertracing
  values:
    allInOne:
      enabled: true
      extraEnv:
      - name: COLLECTOR_OTLP_ENABLED
        value: "true"
    collector:
      service:
        otlp:
          grpc:
            port: 4317  # OTLP gRPC port
```

#### Step 2: Create Hubble Export ConfigMap

```yaml
# kubernetes/infrastructure/cilium/hubble-export-config.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: hubble-export-config
  namespace: kube-system
data:
  config.yaml: |
    exportFilters:
    - name: all-flows
      filters:
      - {}  # Export all flows
    exports:
    - name: jaeger-otel
      dynamic:
        type: otel
        config:
          address: jaeger-collector.observability.svc.cluster.local:4317
          headers: {}
          retryInterval: 30s
          exportInterval: 30s
```

```bash
kubectl apply -f kubernetes/infrastructure/cilium/hubble-export-config.yaml --context infra
```

#### Step 3: Update Cilium HelmRelease

```yaml
# Add to kubernetes/infrastructure/cilium/helmrelease-infra.yaml
spec:
  values:
    hubble:
      export:
        dynamic:
          enabled: true
          config:
            configMapName: hubble-export-config
```

```bash
# Trigger Flux reconciliation
flux reconcile helmrelease cilium -n flux-system --context infra

# Restart Cilium to apply changes
kubectl rollout restart daemonset/cilium -n kube-system --context infra
```

#### Step 4: Verify Tracing

```bash
# Generate some traffic
kubectl run test --image=nicolaka/netshoot --restart=Never --context infra -- sleep 3600
kubectl exec -it test --context infra -- curl https://kubernetes.default.svc.cluster.local

# Port forward to Jaeger UI
kubectl port-forward svc/jaeger-query 16686:16686 -n observability --context infra

# Open http://localhost:16686
# Select service: <namespace>/<service-name>
# Click "Find Traces"
```

### Reading Jaeger Traces from Hubble

Hubble-generated traces show:
- **Service**: Source service (e.g., `gitlab/webservice`)
- **Operation**: Network operation (e.g., `HTTP GET /api/v4/projects`)
- **Tags**:
  - `source.namespace`, `source.pod`, `source.workload`
  - `destination.namespace`, `destination.pod`, `destination.workload`
  - `http.method`, `http.url`, `http.status_code`
  - `verdict` (FORWARDED, DROPPED)
- **Duration**: Network latency

**Example trace:**
```
Service: gitlab/webservice
  Span: HTTP GET /api/v4/projects
    Duration: 45ms
    Tags:
      source.namespace: gitlab
      source.pod: webservice-abc123
      destination.namespace: databases
      destination.pod: postgres-rw-xyz789
      http.method: GET
      http.status_code: 200
      verdict: FORWARDED
```

---

## 🌐 Hubble UI

The Hubble UI provides a visual interface for exploring network flows.

### Accessing Hubble UI

```bash
# Launch (automatically port forwards)
cilium hubble ui --context infra

# Opens http://localhost:12000
```

### Features

1. **Service Map**
   - Visual representation of service dependencies
   - Shows which services communicate with each other
   - Real-time updates as traffic flows
   - Color-coded by verdict (green = forwarded, red = dropped)

2. **Flow Table**
   - Detailed list of network flows
   - Filterable by namespace, pod, protocol, verdict
   - Shows source → destination, protocol, verdict

3. **Namespace View**
   - Select specific namespace to focus on
   - See all ingress/egress traffic for that namespace

4. **Policy Visualization**
   - See which flows are allowed/denied by policies
   - Identify policy gaps or misconfigurations

### Tips

- **Use the namespace filter** to reduce noise and focus on specific applications
- **Watch for red (DROPPED) flows** to identify policy issues
- **Check the "Policy" tab** to see which policies are affecting traffic
- **Use the time slider** to view historical flows (limited by Hubble's ring buffer)

---

## 🛡️ Security Monitoring

### Monitor Network Policy Enforcement

```bash
# View all dropped packets (policy violations)
hubble observe --verdict DROPPED --context apps

# Dropped packets in specific namespace
hubble observe \
  --verdict DROPPED \
  --namespace gitlab \
  --context apps

# Show policy that dropped the packet
hubble observe --verdict DROPPED -o jsonpb | jq '.policy_match_type'
```

### Detect Suspicious Activity

```bash
# External connections (egress to non-cluster IPs)
hubble observe --type trace:to-network --context apps

# Connections to cluster DNS from unexpected sources
hubble observe --to-fqdn "kube-dns.kube-system.svc.cluster.local" --context apps

# Failed authentication attempts (if using mTLS policies)
hubble observe --verdict DROPPED --protocol grpc --context apps
```

### Audit Network Access

```bash
# Who is accessing the database?
hubble observe \
  --to-service postgres-rw \
  --namespace databases \
  --context infra

# Which services are making external API calls?
hubble observe --type trace:to-network --context apps

# Cross-cluster traffic audit
hubble observe \
  --from-namespace gitlab \
  --to-namespace databases \
  --context apps
```

---

## 🔧 Advanced Queries

### JSON Output for Scripting

```bash
# Output as JSON for processing
hubble observe --output json --context apps

# Output as JSON Protocol Buffers (more detailed)
hubble observe --output jsonpb --context apps
```

### Custom Filtering with jq

```bash
# Extract HTTP URLs from flows
hubble observe --protocol http -o jsonpb | \
  jq -r '.l7.http.url'

# Get unique destination IPs
hubble observe -o jsonpb | \
  jq -r '.destination.identity' | sort | uniq

# Count flows by protocol
hubble observe -o jsonpb | \
  jq -r '.l4.protocol' | sort | uniq -c | sort -rn
```

### Follow Specific Traffic

```bash
# Follow specific pod (like tail -f)
hubble observe --follow \
  --from-pod frontend-abc123 \
  --context apps

# Follow with filters
hubble observe --follow \
  --protocol http \
  --namespace gitlab \
  --context apps
```

### Time Range Queries

```bash
# Flows from last 5 minutes
hubble observe --last 5m --context apps

# Flows since specific time
hubble observe --since 2025-10-15T10:00:00Z --context apps
```

---

## 📊 Golden Metrics

Hubble provides "golden metrics" for service health:

1. **Success Rate**: % of successful requests (2xx HTTP codes, no drops)
2. **Request Rate**: Requests per second (RPS)
3. **Latency**: P50, P95, P99 response times

### View Golden Metrics

```bash
# Via Prometheus metrics (in Grafana)
# Success rate:
sum(rate(hubble_http_requests_total{code=~"2.."}[5m]))
  /
sum(rate(hubble_http_requests_total[5m]))

# Request rate:
sum(rate(hubble_http_requests_total[5m])) by (namespace, pod)

# Latency:
histogram_quantile(0.99,
  rate(hubble_http_request_duration_seconds_bucket[5m])
)
```

### CLI Golden Metrics

```bash
# Monitor success rate in real-time
watch -n 1 'hubble observe --protocol http --last 1m | \
  grep -c "200" | \
  awk "{print \"Success rate: \" \$1 \" requests/min\"}"'
```

---

## 🐛 Troubleshooting

### Hubble Not Showing Flows

**Symptoms:**
- `hubble observe` shows no output
- Hubble UI shows empty service map

**Checks:**

```bash
# 1. Verify Hubble is enabled in Cilium
kubectl get cm cilium-config -n kube-system -o yaml | grep hubble

# 2. Check Hubble Relay status
kubectl get pods -n kube-system -l k8s-app=hubble-relay

# 3. Check Hubble status
hubble status --context infra

# 4. Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=50 | grep -i hubble

# 5. Restart Hubble Relay
kubectl rollout restart deployment/hubble-relay -n kube-system --context infra
```

### Hubble UI Not Loading

```bash
# Check if port-forward is working
cilium hubble port-forward --context infra

# Manually port-forward
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 --context infra

# Check Hubble UI pod
kubectl get pods -n kube-system -l k8s-app=hubble-ui

# Check logs
kubectl logs -n kube-system -l k8s-app=hubble-ui
```

### Traces Not Appearing in Jaeger

**Checks:**

```bash
# 1. Verify Jaeger collector is running
kubectl get pods -n observability -l app.kubernetes.io/name=jaeger

# 2. Verify OTLP port is open
kubectl port-forward -n observability svc/jaeger-collector 4317:4317

# 3. Check Hubble export config
kubectl get cm hubble-export-config -n kube-system -o yaml

# 4. Check Cilium config
kubectl exec -n kube-system ds/cilium -- cilium config | grep -i export

# 5. Generate traffic and check Jaeger
kubectl run test --image=curlimages/curl --restart=Never -- sleep 3600
kubectl exec test -- curl https://kubernetes.default.svc.cluster.local
# Wait 30 seconds, then check Jaeger UI
```

### High Hubble Memory Usage

```bash
# Check Cilium agent memory
kubectl top pods -n kube-system -l k8s-app=cilium

# Reduce Hubble ring buffer size
# Edit HelmRelease:
hubble:
  metrics:
    enableOpenMetrics: false  # Disable if not needed
  relay:
    bufferSize: 1024  # Default is 4096

# Or disable specific metrics
hubble:
  metrics:
    enabled:
    - dns
    - drop
    - tcp
    # Remove http, flow, etc. if not needed
```

---

## 📚 Best Practices

### 1. Use Namespace Filters

Always filter by namespace to reduce noise:

```bash
# Good
hubble observe --namespace gitlab --context apps

# Avoid (too much noise)
hubble observe --context apps
```

### 2. Combine Filters

Use multiple filters for precise queries:

```bash
hubble observe \
  --namespace gitlab \
  --protocol http \
  --to-service postgres-rw \
  --context apps
```

### 3. Use Follow Mode for Real-Time Debugging

```bash
hubble observe --follow \
  --from-pod <problematic-pod> \
  --context apps
```

### 4. Export to Files for Analysis

```bash
# Capture flows for later analysis
hubble observe --last 1h -o jsonpb > flows-$(date +%Y%m%d-%H%M).json

# Analyze offline
cat flows-20251015-1430.json | jq -r '.l7.http.url' | sort | uniq -c
```

### 5. Set Up Grafana Dashboards

Don't rely solely on CLI. Set up Grafana dashboards for:
- Success rate over time
- Top services by traffic
- HTTP error rates
- DNS query patterns
- Policy drop events

### 6. Monitor Drops Regularly

```bash
# Daily check for policy violations
hubble observe --verdict DROPPED --last 24h | \
  grep -o 'destination.*' | sort | uniq -c | sort -rn
```

### 7. Document Baseline Behavior

```bash
# Establish normal traffic patterns
hubble observe --last 1h -o jsonpb > baseline-$(date +%Y%m%d).json

# Compare later during incidents
```

---

## 📖 References

- **Hubble Documentation**: https://docs.cilium.io/en/stable/observability/hubble/
- **Hubble CLI Reference**: https://docs.cilium.io/en/stable/observability/hubble/cli/
- **Hubble Metrics**: https://docs.cilium.io/en/stable/observability/metrics/
- **Jaeger Integration**: https://docs.cilium.io/en/stable/observability/hubble/hubble_exporter/
- **Cilium Slack #hubble**: https://cilium.io/slack

---

## 🎯 Quick Reference Card

```bash
# Essential Hubble Commands

# Status
hubble status

# All flows
hubble observe

# Specific namespace
hubble observe --namespace <namespace>

# HTTP only
hubble observe --protocol http

# Dropped packets
hubble observe --verdict DROPPED

# Cross-cluster
hubble observe --from-namespace <ns1> --to-namespace <ns2>

# Follow mode (real-time)
hubble observe --follow --from-pod <pod>

# Launch UI
cilium hubble ui

# Port forward
cilium hubble port-forward
```

---

**You now have comprehensive observability across your multi-cluster Kubernetes platform!** 🚀

*Last Updated: 2025-10-15*
*Version: 1.0*
