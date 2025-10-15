# Multi-Cluster Kubernetes Architecture Overview

**Status:** Architecture Finalized ✅ | Implementation: Ready to Begin
**Date:** 2025-10-15
**Architecture:** 2 Talos Clusters (Infra + Apps) with Linkerd Service Mesh + Cilium CNI

---

## 📋 Quick Links

| Document | Purpose | Status |
|----------|---------|--------|
| [Best Technical Solution 2025](./best-technical-solution-2025.md) | Why Linkerd wins on technical merit | ✅ Complete |
| [Cluster Mesh Comparison](./cluster-mesh-comparison-2025.md) | Comprehensive solution analysis | ✅ Complete |
| [Linkerd Implementation Plan](./linkerd-implementation-plan.md) | 6-week detailed rollout | 🔄 In Progress |
| [Talos Multi-Cluster Bootstrap](./talos-multi-cluster-bootstrap.md) | Step-by-step conversion guide | ✅ Ready |
| [Architecture Decision Record](./architecture-decision-record.md) | All architectural decisions | 🔄 Updating |
| [Helper Scripts](../scripts/README.md) | Automation scripts | ✅ Ready |

---

## 🎯 Architecture Overview

### Current State
- **Single 6-node cluster** (`k8s`)
- All nodes: `10.25.11.11-16` in controlplane mode
- PodCIDR: `10.244.0.0/16`
- ServiceCIDR: `10.245.0.0/16`

### Target State
```
┌─────────────────────────────────────────────────────────────┐
│                    10.25.11.0/24 Network                     │
├─────────────────────────────┬───────────────────────────────┤
│      Infra Cluster          │       Apps Cluster            │
│   infra.k8s.monosense.io    │   apps.k8s.monosense.io       │
├─────────────────────────────┼───────────────────────────────┤
│ Nodes: 10.25.11.11-13       │ Nodes: 10.25.11.14-16         │
│   - infra-01 (11)           │   - apps-01 (14)              │
│   - infra-02 (12)           │   - apps-02 (15)              │
│   - infra-03 (13)           │   - apps-03 (16)              │
├─────────────────────────────┼───────────────────────────────┤
│ PodCIDR: 10.244.0.0/16      │ PodCIDR: 10.246.0.0/16        │
│ ServiceCIDR: 10.245.0.0/16  │ ServiceCIDR: 10.247.0.0/16    │
├─────────────────────────────┼───────────────────────────────┤
│ LoadBalancer: .100-.149     │ LoadBalancer: .150-.199       │
│                             │                               │
│ ┌─────────────────────────┐ │ ┌─────────────────────────┐   │
│ │  Cilium CNI (Layer 1)   │ │ │  Cilium CNI (Layer 1)   │   │
│ │  eBPF networking        │ │ │  eBPF networking        │   │
│ └─────────────────────────┘ │ └─────────────────────────┘   │
│ ┌─────────────────────────┐ │ ┌─────────────────────────┐   │
│ │  Linkerd Mesh (Layer 2) │ │ │  Linkerd Mesh (Layer 2) │   │
│ │  L7 observability/mTLS  │ │ │  L7 observability/mTLS  │   │
│ └─────────────────────────┘ │ └─────────────────────────┘   │
└─────────────────────────────┴───────────────────────────────┘
                              ▲
              Linkerd Multi-Cluster Service Mirroring
                  (mTLS-encrypted cross-cluster)
```

### Architecture Layers

**Layer 1 - Networking (Cilium CNI):**
- eBPF-based pod networking and routing
- NetworkPolicies for L3/L4 security
- BGP integration with Juniper SRX320
- Gateway API for ingress

**Layer 2 - Service Mesh (Linkerd):**
- Automatic mTLS between all services
- L7 observability and distributed tracing
- Service mirroring for cross-cluster access
- Minimal resource overhead (Rust micro-proxies)

**Cross-Cluster Communication:**
- Linkerd gateway with automatic service discovery
- Encrypted tunnels over mTLS (safe over public internet)
- Service mirroring: `postgres-rw-infra.svc.cluster.local` on apps cluster
- Automatic failover and locality-aware routing

---

## 🏗️ Infra Cluster Workloads

**Platform Services** (Always Running):
- **Storage:** Rook Ceph (3x1TB NVMe), OpenEBS LocalPV (512GB NVMe)
- **Databases:** CloudNativePG (Postgres 15) with MinIO object storage backups, Dragonfly (Redis-compatible cache)
- **Security:** Keycloak, cert-manager, external-secrets (1Password)
- **Observability:** Victoria Metrics Stack, Fluent-bit, Victoria Logs, Kromgo
- **Networking:** External-DNS (Cloudflare), Cloudflare Tunnel
- **GitOps:** FluxCD, Tofu-Controller
- **CI/CD:** GitHub Actions runners

**Resource Allocation:**
- CPU: 36 cores (22.5 platform + 13.5 buffer)
- RAM: 192GB (66GB platform + 44GB workloads + 82GB buffer)
- Storage: 3TB NVMe (Ceph) + 1.5TB NVMe (OpenEBS)

---

## 📦 Apps Cluster Workloads

**Application Services** (User-Facing):
- GitLab (with Runners)
- Harbor Registry
- Mattermost Team Chat
- Future application workloads

**Platform Integration:** GitLab consumes the infra-hosted CloudNativePG and Dragonfly services through Linkerd service mirroring with mTLS encryption, keeping state centralized while workloads remain isolated. Services are automatically mirrored as `<service>-infra.svc.cluster.local` on the apps cluster.

**Storage Strategy:**
- Local Rook-Ceph (3×1TB NVMe, replica 3) for stateful workloads
- OpenEBS LocalPV (512GB NVMe hostPath) for cache/ephemeral volumes

---

## 🚀 Getting Started

### Prerequisites Checklist
- [ ] Talos Linux 1.11.2 installed on all 6 nodes
- [ ] Node IPs: 10.25.11.11-16 configured
- [ ] DNS access (Cloudflare or internal)
- [ ] 1Password CLI configured
- [ ] Required tools: `talosctl`, `kubectl`, `linkerd`, `op`, `yq`, `minijinja-cli`

### Quick Start (30-minute version)

```bash
# 1. Run conversion script (5 min)
./scripts/convert-to-multicluster.sh

# 2. Generate secrets (2 min)
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml

# 3. Import to 1Password (3 min)
./scripts/extract-talos-secrets.sh /tmp/infra-secrets.yaml infra
# Copy and run the 'op item create' command
./scripts/extract-talos-secrets.sh /tmp/apps-secrets.yaml apps
# Copy and run the 'op item create' command

# 4. Update configs (10 min)
# - Update talos/machineconfig.yaml.j2 (see bootstrap guide Step 1)
# - Update .taskfiles/talos/Taskfile.yaml (see bootstrap guide Step 2)
# - Add DNS records: infra.k8s.monosense.io, apps.k8s.monosense.io

# 5. Deploy infra cluster (5 min)
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.12 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.13 CLUSTER=infra MACHINE_TYPE=controlplane
talosctl bootstrap --nodes 10.25.11.11

# 6. Deploy apps cluster (5 min)
task talos:apply-node NODE=10.25.11.14 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.15 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.16 CLUSTER=apps MACHINE_TYPE=controlplane
talosctl config context apps --nodes 10.25.11.14,10.25.11.15,10.25.11.16
talosctl bootstrap --nodes 10.25.11.14
```

**Full detailed guide:** [Talos Multi-Cluster Bootstrap](./talos-multi-cluster-bootstrap.md)

---

## 📅 Implementation Phases

### Phase 1: Foundation (Week 1-2)
- ✅ Architecture finalized (Linkerd + Cilium)
- 🔲 Bootstrap both Talos clusters
- 🔲 Deploy Cilium CNI on both clusters
- 🔲 Bootstrap FluxCD
- 🔲 Deploy core monitoring (Victoria Metrics)

### Phase 2: Service Mesh & Observability (Week 3)
- 🔲 Install Linkerd on both clusters
- 🔲 Configure multi-cluster service mirroring
- 🔲 Deploy Jaeger for distributed tracing
- 🔲 Deploy Linkerd Viz dashboard
- 🔲 Validate cross-cluster connectivity

### Phase 3: Storage & Backup (Week 4)
- 🔲 Deploy Rook Ceph on both clusters
- 🔲 Deploy OpenEBS on both clusters
- 🔲 Configure VolSync backup
- 🔲 Deploy Velero

### Phase 4: Platform Services (Week 5)
- 🔲 Deploy CloudNativePG (infra cluster)
- 🔲 Deploy Dragonfly cache (infra cluster)
- 🔲 Deploy MinIO (infra cluster)
- 🔲 Deploy Keycloak (infra cluster)
- 🔲 Export services via Linkerd mirroring

### Phase 5: Security & Networking (Week 6)
- 🔲 Configure Cloudflare Tunnel
- 🔲 Implement Cilium NetworkPolicies
- 🔲 Configure Linkerd authorization policies
- 🔲 Deploy cert-manager + certificates
- 🔲 Deploy GitHub Actions runners

### Phase 6: Applications & Validation (Week 7)
- 🔲 Mesh GitLab namespace (apps cluster)
- 🔲 Deploy GitLab (using mirrored DB services)
- 🔲 Mesh Harbor namespace
- 🔲 Deploy Harbor
- 🔲 Mesh Mattermost namespace
- 🔲 Deploy Mattermost
- 🔲 Validate distributed tracing end-to-end
- 🔲 DR testing
- 🔲 Performance testing
- 🔲 Go-live

**Total Timeline:** 7 weeks (reduced from 10 weeks due to Linkerd simplicity)

**Full detailed plan:** [Linkerd Implementation Plan](./linkerd-implementation-plan.md)

---

## 🔑 Key Architecture Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| ADR-001 | All databases on infra cluster | Centralized management, better resource utilization |
| ADR-002 | Cloudflare Tunnel for external access | Zero-trust, no exposed IPs |
| ADR-004 | Velero Day 1 implementation | Cluster-level backup critical from start |
| ADR-006 | 6-hour RPO for VolSync | Balance between protection and overhead |
| ADR-009 | Actions runners on infra cluster | Shared resource, always available |
| ADR-012 | Keycloak for authentication | SSO across all services |
| ADR-013 | External-DNS with Cloudflare | Automatic DNS management |

**Full ADR:** [Architecture Decision Record](./architecture-decision-record.md)

---

## 🛠️ Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| OS | Talos Linux | 1.11.2 | Immutable Kubernetes OS |
| Kubernetes | K8s | 1.34.1 | Container orchestration |
| CNI | Cilium | 1.18+ | eBPF networking, NetworkPolicies |
| Service Mesh | Linkerd | 2.18+ | L7 observability, mTLS, multi-cluster |
| GitOps | FluxCD | Latest | Continuous deployment |
| Storage | Rook Ceph | Latest | Block/Object/File storage |
| Storage | OpenEBS LocalPV | Latest | Local persistent volumes |
| Database | CloudNativePG | Latest | PostgreSQL operator |
| Cache | Dragonfly | Latest | Redis-compatible in-memory cache |
| Object Storage | MinIO | Latest | S3-compatible object storage |
| Secrets | External Secrets | Latest | 1Password integration |
| Metrics | Victoria Metrics | Latest | Metrics aggregation |
| Logs | Victoria Logs | Latest | Log aggregation |
| Tracing | Jaeger | Latest | Distributed tracing (OTLP) |
| Auth | Keycloak | Latest | SSO/Identity provider |
| CI/CD | GitHub Actions | N/A | Pipeline automation |
| Backup | VolSync | Latest | PVC replication |
| Backup | Velero | Latest | Cluster backup |

### Architecture Update (October 15, 2025)

**Service Mesh Decision:**
- **Selected:** Linkerd + Cilium CNI (best technical solution)
- **Why:** Highest performance (+8% latency vs +166% Istio sidecar), lowest resource overhead (1/5th of Istio), excellent L7 observability with OTLP/Jaeger, production-proven multi-cluster (GA for 5 years)
- **Alternative considered:** Istio ambient (rejected due to alpha multi-cluster status)

**Repository Structure:**
- Flux multi-cluster layout: `kubernetes/infrastructure` → `kubernetes/workloads` → `kubernetes/clusters/<name>`
- Cilium configured with BGP control plane, Gateway API, `kubeProxyReplacement: false` for Linkerd compatibility
- Linkerd deployed on both clusters with automatic mTLS and service mirroring

**Observability Stack:**
- **Centralized on infra cluster:** Jaeger (traces), Victoria Metrics (metrics), Victoria Logs (logs), Grafana (dashboards)
- **Apps cluster:** Linkerd proxies send OTLP traces to Jaeger collector on infra
- **Cross-cluster:** Service mirroring provides transparent access to infra services

**Storage:**
- Rook-Ceph: 1TB NVMe drives, replica 3, `rook-ceph-block` StorageClass
- OpenEBS: 512GB NVMe hostPath, `openebs-local-nvme` StorageClass

**Multi-Cluster Integration:**
- GitLab (apps cluster) connects to CloudNativePG/Dragonfly/MinIO (infra cluster) via Linkerd service mirroring
- Services automatically available as `<service>-infra.svc.cluster.local` on apps cluster
- mTLS-encrypted cross-cluster communication via Linkerd gateway

---

## 📊 Resource Planning

### Infra Cluster (3 nodes)
```
Total Capacity:
  CPU: 36 cores (3 × 12 cores)
  RAM: 192 GB (3 × 64 GB)
  Storage: 4.5 TB NVMe (3 × 1.5 TB)

Infrastructure Services:
├─ Cilium CNI: ~400m CPU, ~1 GB RAM
├─ Linkerd (control plane): ~500m CPU, ~1.1 GB RAM
├─ Linkerd (data plane, ~50 pods): ~1 CPU, ~2 GB RAM
├─ Jaeger: ~300m CPU, ~768 MB RAM
├─ Victoria Metrics: ~1 CPU, ~4 GB RAM
├─ FluxCD: ~200m CPU, ~512 MB RAM
└─ Total Infrastructure: ~3.5 CPU, ~9.5 GB RAM

Platform Workloads:
├─ CloudNativePG: ~1 CPU, ~4 GB RAM
├─ Dragonfly: ~500m CPU, ~2 GB RAM
├─ MinIO: ~500m CPU, ~2 GB RAM
├─ Keycloak: ~1 CPU, ~2 GB RAM
├─ Rook Ceph: ~2 CPU, ~6 GB RAM
├─ Actions Runners: ~2 CPU, ~4 GB RAM
└─ Total Platform: ~7 CPU, ~20 GB RAM

Summary:
├─ Total Used: ~10.5 CPU, ~29.5 GB RAM (29% CPU, 15% RAM)
├─ Available: ~25.5 CPU, ~162.5 GB RAM
└─ Headroom: Excellent

Storage:
  Ceph: 3 TB usable (3×1TB, replica 3)
  OpenEBS: 1.5 TB (3×512GB)
```

### Apps Cluster (3 nodes)
```
Total Capacity:
  CPU: 36 cores (3 × 12 cores)
  RAM: 192 GB (3 × 64 GB)
  Storage: 4.5 TB NVMe (3 × 1.5 TB)

Infrastructure Services:
├─ Cilium CNI: ~400m CPU, ~1 GB RAM
├─ Linkerd (control plane): ~500m CPU, ~1.1 GB RAM
├─ Linkerd (data plane, ~100 pods): ~2 CPU, ~4 GB RAM
├─ FluxCD: ~200m CPU, ~512 MB RAM
└─ Total Infrastructure: ~3.1 CPU, ~6.6 GB RAM

Application Workloads (estimated):
├─ GitLab: ~4 CPU, ~16 GB RAM
├─ Harbor: ~2 CPU, ~8 GB RAM
├─ Mattermost: ~2 CPU, ~4 GB RAM
├─ Rook Ceph: ~2 CPU, ~6 GB RAM
└─ Total Applications: ~10 CPU, ~34 GB RAM

Summary:
├─ Total Used: ~13 CPU, ~40.6 GB RAM (36% CPU, 21% RAM)
├─ Available: ~23 CPU, ~151.4 GB RAM
└─ Headroom: Excellent for future growth

Storage:
  Ceph: 3 TB usable (3×1TB, replica 3)
  OpenEBS: 1.5 TB (3×512GB)
```

### Linkerd Resource Impact

**Compared to Istio Sidecar:**
```
Apps Cluster (100 meshed pods):
├─ Linkerd: ~2 CPU cores, ~4 GB RAM
├─ Istio Sidecar: ~6 CPU cores, ~8 GB RAM
└─ Savings: 4 CPU cores (11%), 4 GB RAM

This saves $200-300/month equivalent in cloud costs!
```

---

## 🔐 Security Architecture

**Zero-Trust Foundation:**
- **Service-to-Service mTLS:** Linkerd automatic mTLS for all meshed pods (enabled by default)
- **Cross-Cluster mTLS:** Linkerd gateway encrypts all cross-cluster traffic
- **Certificate Management:** Linkerd automatic cert rotation (24h lifetime)
- **Network Policies:** Cilium NetworkPolicy for L3/L4 isolation
- **Authorization Policies:** Linkerd L7 authorization policies per workload

**Identity & Access:**
- **Secret Management:** 1Password via External Secrets Operator
- **Authentication:** Keycloak SSO for all user-facing services
- **External Access:** Cloudflare Tunnel (zero-trust, no exposed IPs)
- **TLS Certificates:** cert-manager with Let's Encrypt
- **Pod Security:** Gradual enforcement (audit → warn → enforce)

**Data Protection:**
- **In-Transit:** Automatic mTLS via Linkerd (no configuration needed)
- **At-Rest:** Rook Ceph encryption, Age-encrypted backups
- **Cross-Cluster:** mTLS-encrypted gateway tunnels
- **Secret Rotation:** Automatic (Linkerd certs), Manual quarterly (1Password)

**Compliance:**
- **CNCF Graduated Project:** Linkerd (industry-standard security)
- **Zero CVEs:** Linkerd core proxy (Rust-based, minimal attack surface)
- **Audit Logs:** Linkerd Viz + Jaeger for request-level tracing

---

## 📈 Monitoring & Observability

**Three Pillars of Observability (Centralized on Infra Cluster):**

### 1. Metrics (Victoria Metrics + Linkerd)

**Linkerd Golden Metrics (Automatic):**
- ✅ **Success Rate:** Percentage of successful requests
- ✅ **Request Rate (RPS):** Requests per second
- ✅ **Latency (p50, p95, p99):** Response time distribution
- ✅ **Per-Service, Per-Route:** Granular visibility

**Infrastructure Metrics:**
- Victoria Metrics (centralized on infra)
- VMAgent on apps cluster (remote-write to infra)
- Prometheus scraping of Linkerd proxies
- Pre-configured Grafana dashboards (Linkerd + custom)

**CLI Access:**
```bash
# Real-time golden metrics
linkerd viz stat deploy -n gitlab

# Top resources by RPS
linkerd viz top deploy -n gitlab
```

### 2. Logs (Fluent-bit + Victoria Logs)

- Centralized Victoria Logs (infra cluster)
- Fluent-bit agents on all pods
- Structured JSON logging
- Correlated with trace IDs from Linkerd

### 3. Distributed Tracing (Jaeger + Linkerd)

**Linkerd → OpenTelemetry → Jaeger Pipeline:**
- ✅ **Automatic context propagation** (W3C Trace Context)
- ✅ **Request-level tracing** across services and clusters
- ✅ **Cross-cluster visibility:** GitLab (apps) → Postgres (infra) traces
- ✅ **Service dependency map** in Jaeger UI
- ✅ **Performance bottleneck identification**

**Trace Flow:**
```
App Request → Linkerd Proxy → OTLP Collector → Jaeger (infra)
                ↓
         Automatic span creation
         Context propagation
         Cross-cluster correlation
```

### Real-Time Service Visibility (Linkerd Viz)

**Linkerd Viz Dashboard Features:**
- ✅ Live service topology graph
- ✅ Real-time success rates and latencies
- ✅ TLS status indicators (mTLS verification)
- ✅ Traffic split visualization
- ✅ Tap: Live request inspection (like HTTP Wireshark)

**Access:**
```bash
# Launch dashboard
linkerd viz dashboard

# Live traffic inspection
linkerd viz tap deploy/gitlab --to deploy/postgres-rw-infra
# See LIVE requests with headers, methods, status codes!
```

### Alerting (Alertmanager + Linkerd)

- AlertManager (infra cluster)
- Linkerd SLO-based alerts (success rate, latency)
- Critical alerts to GitHub issues
- Multi-channel support (Slack, PagerDuty, etc.)
- Silence operator for maintenance

### Health Checks

- **Gatus:** External endpoint monitoring
- **Linkerd Health:** Service mesh health checks
- **Multi-cluster validation:** Cross-cluster connectivity monitoring

---

## 🚨 Disaster Recovery

### Backup Strategy
- **VolSync:** PVC replication, 6-hour RPO
- **Velero:** Cluster resources, weekly full backup
- **Destinations:** MinIO on Synology NAS
- **Encryption:** Age encryption for all backups

### Recovery Scenarios
1. **Pod Failure:** Kubernetes self-healing (< 1 min)
2. **Node Failure:** Pod rescheduling (< 5 min)
3. **Cluster Failure:** Restore from backups (< 4 hours)
4. **Complete Disaster:** Rebuild from GitOps repo (< 8 hours)

### Testing Schedule
- **Tier 1 (Pod/PVC):** Weekly
- **Tier 2 (Node/Cluster):** Monthly
- **Tier 3 (Complete DR):** Quarterly

---

## 📚 Documentation Structure

```
docs/
├── MULTI-CLUSTER-OVERVIEW.md          # This file - high-level overview
├── talos-multi-cluster-bootstrap.md   # Step-by-step conversion guide
├── architecture-decision-record.md    # All 20 ADR decisions
├── technical-deep-dive.md             # Production configurations
├── implementation-timeline.md         # 10-week rollout plan
└── brainstorming-session-results.md   # Initial research & analysis

scripts/
├── README.md                          # Helper scripts documentation
├── convert-to-multicluster.sh         # Automate node reorganization
└── extract-talos-secrets.sh           # Extract secrets for 1Password
```

---

## 🎓 Learning Resources

### Linkerd (Service Mesh)
- [Official Documentation](https://linkerd.io/2.18/overview/)
- [Getting Started (10 min)](https://linkerd.io/2.18/getting-started/)
- [Multi-cluster Guide](https://linkerd.io/2.18/tasks/multicluster/)
- [Distributed Tracing](https://linkerd.io/2.18/tasks/distributed-tracing/)
- [Linkerd + Cilium Integration](https://buoyant.io/blog/kubernetes-network-policies-with-cilium-and-linkerd)
- [Practical Linkerd eBook](https://buoyant.io/books) (Free)
- [Linkerd Slack Community](https://slack.linkerd.io)

### Talos Linux
- [Official Docs](https://www.talos.dev/latest/)
- [Multi-Cluster Setup](https://www.talos.dev/latest/advanced/multi-cluster/)
- [CNI Configuration](https://www.talos.dev/latest/kubernetes-guides/network/)

### Cilium (CNI)
- [Installation Guide](https://docs.cilium.io/en/stable/installation/)
- [BGP Control Plane](https://docs.cilium.io/en/stable/network/bgp-control-plane/)
- [Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [NetworkPolicies](https://docs.cilium.io/en/stable/security/policy/)

### FluxCD (GitOps)
- [Multi-Cluster GitOps](https://fluxcd.io/flux/use-cases/multi-cluster/)
- [Helm Controller](https://fluxcd.io/flux/components/helm/)
- [Best Practices](https://fluxcd.io/flux/guides/repository-structure/)

### Observability
- [Jaeger Documentation](https://www.jaegertracing.io/docs/latest/)
- [OpenTelemetry](https://opentelemetry.io/docs/)
- [Victoria Metrics](https://docs.victoriametrics.com/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

---

## ✅ Pre-Flight Checklist

Before starting implementation:

**Documentation:**
- [ ] Read talos-multi-cluster-bootstrap.md completely
- [ ] Review architecture-decision-record.md
- [ ] Understand implementation-timeline.md phases
- [ ] Review helper scripts in scripts/README.md

**Infrastructure:**
- [ ] All 6 nodes powered on and accessible
- [ ] Network connectivity verified (10.25.11.11-16)
- [ ] DNS provider access (Cloudflare or internal)
- [ ] 1Password vault access
- [ ] Juniper SRX320 accessible for BGP configuration

**Tools Installed:**
- [ ] talosctl (v1.11.2+)
- [ ] kubectl (v1.34.1+)
- [ ] linkerd CLI (v2.18+) - `curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh`
- [ ] op (1Password CLI)
- [ ] yq (YAML processor)
- [ ] minijinja-cli (template processor)
- [ ] flux CLI
- [ ] helm
- [ ] helmfile

**Git Repository:**
- [ ] All changes committed
- [ ] Backup of current configs
- [ ] Branch created for multi-cluster work

---

## 🤝 Support & Troubleshooting

### Common Issues
- **Node not bootstrapping:** Check talosctl logs and etcd health
- **PodCIDR overlap:** Verify different CIDRs in both clusters
- **1Password injection failing:** Verify op CLI authentication

### Troubleshooting Guides
- See "Troubleshooting" section in talos-multi-cluster-bootstrap.md
- See "Testing Checklist" in implementation-timeline.md
- See "Disaster Recovery" section in technical-deep-dive.md

### Getting Help
- Review documentation in `docs/` directory
- Check scripts output and error messages
- Validate prerequisites before proceeding

---

## 📝 Notes

- This is a **greenfield** multi-cluster deployment plan
- Total estimated implementation time: **7 weeks** (reduced from 10 weeks)
- **Service mesh:** Linkerd (best technical solution: performance + observability + simplicity)
- **CNI:** Cilium (eBPF networking, NetworkPolicies, BGP)
- Conversion scripts automate ~70% of manual work
- All architectural decisions documented and ratified
- Ready to begin Phase 1: Foundation

---

## 🚀 Quick Start Commands

```bash
# Install Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# Verify prerequisites
linkerd version
kubectl version
talosctl version

# Test Linkerd on existing cluster (optional)
linkerd check --pre
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check

# View live dashboard
linkerd viz install | kubectl apply -f -
linkerd viz dashboard
```

---

*Multi-Cluster Overview - v2.0*
*Last Updated: 2025-10-15*
*Architecture: Linkerd Service Mesh + Cilium CNI*
