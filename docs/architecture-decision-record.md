# Architecture Decision Record (ADR)

**Project:** Multi-Cluster Kubernetes Platform
**Date:** 2025-10-14
**Status:** ✅ Approved
**Version:** 1.0

---

## Executive Summary

This document records all architectural decisions made during the brainstorming and planning phase for the greenfield multi-cluster Kubernetes deployment. All decisions have been reviewed and approved.

**Key Characteristics:**
- **Scale:** 2 clusters (infra + apps), 6 nodes total
- **Network:** Same subnet (10.25.11.0/24), flat L2, Cilium ClusterMesh
- **Storage:** Centralized Rook Ceph on infra, VolSync + Velero backups
- **Access:** Cloudflare Tunnel (zero-trust external access)
- **Observability:** Centralized Victoria Metrics on infra
- **Philosophy:** GitOps-first, security-conscious, pragmatic rollout

---

## Decision Summary Table

| ID | Category | Decision | Rationale | Impact |
|----|----------|----------|-----------|--------|
| **ADR-001** | Data | All databases on infra cluster | Centralized management, simplified DR | Apps depend on infra availability via ClusterMesh |
| **ADR-002** | Network | Cloudflare Tunnel for external access | Zero-trust security, no exposed IPs | No LoadBalancer ingress needed |
| **ADR-003** | CI/CD | External services initially (GitHub + ghcr.io) | Focus on core platform first | Lower operational overhead |
| **ADR-004** | Backup | Velero Day 1 implementation | Backup strategy from start | Added to Phase 2 deployment |
| **ADR-005** | Security | Network policies Phase 2 (Week 8+) | Learn traffic patterns first | Short security gap, better policies |
| **ADR-006** | Backup | 6-hour RPO for VolSync backups | Balance of data loss and overhead | 4 backups/day to MinIO |
| **ADR-007** | Security | Pod Security: Audit → Baseline → Restricted | Gradual enforcement | Platform components need exemptions |
| **ADR-008** | Operations | Manual Talos/K8s upgrades | Complete control, stability focus | Manual effort quarterly |
| **ADR-009** | CI/CD | GitHub Actions runners on infra cluster | Fast CI/CD, no external minutes | Infra cluster resource usage |
| **ADR-010** | Testing | No staging cluster, Flux dry-run testing | Cost-effective, sufficient validation | Higher production testing risk |
| **ADR-011** | Network | One Cloudflare tunnel per cluster | Clean separation, independent failure | 2 tunnel tokens to manage |
| **ADR-012** | Security | Keycloak for centralized auth | Mature, feature-rich OIDC/SAML | Higher resource usage (Java) |
| **ADR-013** | Network | External DNS with Cloudflare provider | Automatic DNS management | Cloudflare API token management |
| **ADR-014** | Security | Manual quarterly secret rotation | Controlled rotation, low risk environment | Manual process 4x/year |
| **ADR-015** | Storage | RBD only, CephFS on-demand | Most apps use RWO, add RWX later | Simpler initial deployment |
| **ADR-016** | Storage | Use MinIO on Synology (no Ceph RGW) | Already available, no duplication | External dependency for S3 |
| **ADR-017** | Platform | Current Talos extensions sufficient | Essential extensions already configured | No additional complexity |
| **ADR-018** | Operations | Rolling updates, no fixed maintenance window | HA design supports zero-downtime | Ad-hoc planning for disruptive ops |
| **ADR-019** | Operations | Tiered DR testing schedule | Balance thoroughness and time | Weekly/monthly/quarterly/annual tests |
| **ADR-020** | Operations | Resource quotas Phase 2 (after usage observation) | Learn patterns before enforcement | No namespace protection initially |

---

## Detailed Architecture Decisions

### ADR-001: Database Placement
**Decision:** All databases run on infra cluster (shared services model)

**Context:**
- Need to decide database placement for PostgreSQL and future databases
- Options: infra cluster, apps cluster, or hybrid

**Decision:**
- PostgreSQL and all future databases deployed on infra cluster
- Apps cluster accesses via Cilium ClusterMesh global services
- Connection string: `postgres.databases.svc.infra.local:5432`

**Consequences:**
- ✅ **Positive:**
  - Centralized database management and monitoring
  - Single backup/DR strategy (VolSync on infra only)
  - Apps cluster is stateless (can rebuild in 30min with no data loss)
  - Clear separation of concerns (infra = platform, apps = workloads)
- ❌ **Negative:**
  - Apps depend on infra cluster availability
  - Cross-cluster latency for DB queries (mitigated: same subnet, <1ms)
  - Apps cluster cannot function without infra cluster

**Mitigation:**
- Use PgBouncer for connection pooling (reduces latency impact)
- Monitor cross-cluster DB latency with Victoria Metrics
- Design for infra cluster high availability (3 nodes, Ceph replication)

**Alternatives Considered:**
- Each cluster has own databases: Rejected (complex backup, data sync issues)
- Hybrid approach: Rejected (most complex, decision fatigue per-app)

---

### ADR-002: External Access Strategy
**Decision:** Cloudflare Tunnel for all external access (zero-trust)

**Context:**
- Need secure external access to services (Grafana, applications)
- Options: LoadBalancer ingress with BGP, Cloudflare Tunnel, or hybrid

**Decision:**
- Deploy Cloudflared on each cluster
- All external services via Cloudflare Tunnel
- No public LoadBalancer ingress controllers
- Internal cluster services remain ClusterIP

**Consequences:**
- ✅ **Positive:**
  - Zero-trust security (no exposed IPs or ports)
  - Automatic TLS certificate management
  - DDoS protection via Cloudflare
  - No need for dynamic DNS
  - Saves LoadBalancer IPs (only need IPs for internal services)
- ❌ **Negative:**
  - Dependency on Cloudflare service availability
  - Added latency (~20-50ms) for external requests
  - Requires Cloudflare account and tunnel configuration

**Implementation:**
```yaml
Infra Cluster Tunnel:
  - grafana.monosense.io → grafana.monitoring.svc:3000
  - hubble.infra.monosense.io → hubble-ui.kube-system.svc:80
  - ceph.infra.monosense.io → rook-ceph-dashboard:8443

Apps Cluster Tunnel:
  - *.monosense.io → Application services
  - app1.monosense.io, app2.monosense.io, etc.
```

**Alternatives Considered:**
- LoadBalancer ingress: Rejected (exposes public IPs, more attack surface)
- Hybrid (both tunnels and ingress): Rejected (unnecessary complexity)

---

### ADR-003: CI/CD Infrastructure
**Decision:** Use external services (GitHub + ghcr.io) initially, self-host later

**Context:**
- Need container registry and CI/CD infrastructure
- Options: GitLab/Harbor on cluster, external VM, or cloud services

**Decision:**
- **Phase 1 (Months 1-3):** GitHub + GitHub Container Registry
- **Phase 2 (Month 4+):** Evaluate self-hosted GitLab/Harbor
- GitHub Actions runners deployed on infra cluster (ADR-009)

**Consequences:**
- ✅ **Positive:**
  - Zero operational overhead during platform build
  - Focus on core platform services first
  - Free tier sufficient (2000 Actions minutes/month)
  - Can always self-host later without migration pain
- ❌ **Negative:**
  - Dependency on GitHub availability
  - Container images stored externally
  - Limited to GitHub free tier quotas

**Future Self-Hosted Option:**
```yaml
Phase 2 Consideration (Month 4+):
  - GitLab CE: On dedicated VM (ThinkCentre M910q)
  - Harbor: On infra cluster (uses Rook Ceph storage)
  - Migrate repos/images when ready
```

**Alternatives Considered:**
- GitLab/Harbor day 1: Rejected (too much complexity upfront)
- Permanent external services: Acceptable long-term if it works well

---

### ADR-004: Backup Strategy Timing
**Decision:** Implement both VolSync AND Velero from Day 1 (Phase 2)

**Context:**
- Need comprehensive backup strategy
- Options: VolSync only, Velero only, or both from start

**Decision:**
- **VolSync:** PVC data replication (primary backup)
- **Velero:** Kubernetes resource backup (secondary backup)
- Both implemented in Phase 2 (Week 3-4) before production workloads

**Consequences:**
- ✅ **Positive:**
  - Comprehensive backup from before production data exists
  - Easier to configure (no existing data to backup)
  - Can test restore procedures immediately
  - Disaster recovery capability from day 1
- ❌ **Negative:**
  - Adds complexity to initial deployment
  - Both tools need configuration and testing upfront

**Backup Strategy:**
```yaml
VolSync (Primary - PVC Data):
  Schedule: Every 6 hours (4x/day)
  Retention: 6H/7D/4W/6M
  Destination: MinIO S3 on Synology
  Method: Restic with Rook Ceph CSI snapshots

Velero (Secondary - K8s Resources):
  Schedule: Weekly (Sundays 2 AM)
  Retention: 30 days
  Destination: MinIO S3 on Synology
  Method: CSI snapshots + object storage
```

**Alternatives Considered:**
- VolSync only: Rejected (no K8s resource backup)
- Velero later (Phase 2): Originally recommended but overruled by user request
- Velero only: Rejected (PVC backup performance issues with Restic)

---

### ADR-005: Network Policy Strategy
**Decision:** Implement network policies in Phase 2 (Week 8+) after observing traffic

**Context:**
- Need to balance security and operational complexity
- Options: Day 1 strict policies, permissive policies, or Phase 2

**Decision:**
- **Weeks 1-6:** No network policies (observe with Hubble)
- **Week 7:** Analyze Hubble flow logs, document patterns
- **Week 8:** Implement namespace-level default deny
- **Week 9:** Add explicit allow policies per-application

**Consequences:**
- ✅ **Positive:**
  - Learn actual traffic patterns before restricting
  - Avoid breaking services during initial deployment
  - Hubble provides visibility to generate accurate policies
  - Better policies based on real usage patterns
- ❌ **Negative:**
  - 6-8 week window without network segmentation
  - Higher risk during initial deployment period
  - Delayed security hardening

**Implementation Plan:**
```yaml
Week 7 - Analysis:
  - Export Hubble flows: `hubble observe --output json > flows.json`
  - Identify inter-namespace communication patterns
  - Document required connections per application

Week 8 - Default Deny:
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: default-deny-all
    namespace: <app-namespace>
  spec:
    endpointSelector: {}
    ingress:
      - fromEndpoints:
          - matchLabels:
              io.kubernetes.pod.namespace: <app-namespace>

Week 9 - Explicit Allow:
  - Per-application allow rules based on Week 7 analysis
  - Test each policy before enforcement
```

**Alternatives Considered:**
- Default deny day 1: Rejected (too complex for greenfield without known patterns)
- Default allow forever: Rejected (security risk)

---

### ADR-006: Backup RPO (Recovery Point Objective)
**Decision:** 6-hour RPO for critical data (VolSync backups every 6 hours)

**Context:**
- Need to balance data loss risk with backup overhead
- Options: 1 hour, 6 hours, or 24 hours

**Decision:**
- Critical data (PostgreSQL, stateful apps): Backup every 6 hours
- Less critical data: Daily backups
- Maximum data loss: 6 hours

**Consequences:**
- ✅ **Positive:**
  - Acceptable data loss window for home environment
  - 4 backups per day = reasonable storage/bandwidth usage
  - Retention strategy: 6 hourly, 7 daily, 4 weekly, 6 monthly
- ❌ **Negative:**
  - Up to 6 hours of data could be lost in disaster scenario
  - 4 VolSync jobs per PVC per day (manageable overhead)

**Storage Impact:**
```yaml
Per PVC Backup:
  Snapshot size: ~1GB (example PostgreSQL)
  Backups/day: 4
  Retention: ~50 snapshots (6H + 7D + 4W + 6M)
  Total storage: ~50GB per PVC (with deduplication)

Network bandwidth:
  4 backups/day × 1GB = 4GB/day transferred to MinIO
  Incremental backups (Restic) reduce actual transfer
```

**Alternatives Considered:**
- 1-hour RPO: Rejected (excessive overhead for home use)
- 24-hour RPO: Rejected (too much potential data loss)

---

### ADR-007: Pod Security Standards
**Decision:** Gradual enforcement (Audit → Baseline → Restricted)

**Context:**
- Kubernetes Pod Security Standards for security hardening
- Options: Immediate enforcement or gradual rollout

**Decision:**
- **Weeks 1-8:** Audit mode (log violations, no enforcement)
- **Week 9:** Enforce "baseline" standard (except platform namespaces)
- **Month 3:** Enforce "restricted" standard for application namespaces

**Consequences:**
- ✅ **Positive:**
  - Platform components (Cilium, Rook) can run with necessary privileges
  - Learn which apps need which permissions before blocking
  - Gradual transition reduces operational friction
  - Applications can be remediated before enforcement
- ❌ **Negative:**
  - Not enforced initially (8-week window)
  - Platform namespaces permanently exempted from "restricted"

**Implementation:**
```yaml
# Week 1-8: Audit Mode
apiVersion: v1
kind: Namespace
metadata:
  name: applications
  labels:
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/enforce: privileged

# Week 9: Enforce Baseline
apiVersion: v1
kind: Namespace
metadata:
  name: applications
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/enforce: baseline

# Month 3: Enforce Restricted
apiVersion: v1
kind: Namespace
metadata:
  name: applications
  labels:
    pod-security.kubernetes.io/enforce: restricted

# Platform exemptions (permanent)
Exempted Namespaces:
  - kube-system (Cilium, CoreDNS need privileged)
  - rook-ceph (Ceph OSDs need privileged)
  - monitoring (Prometheus node-exporter needs hostPath)
```

**Alternatives Considered:**
- Immediate "restricted" enforcement: Rejected (breaks platform components)
- No enforcement: Rejected (security risk)

---

### ADR-008: Upgrade Strategy
**Decision:** Manual Talos and Kubernetes upgrades (no automation)

**Context:**
- Need to balance staying current with stability
- Options: Fully automated, semi-automated, or manual

**Decision:**
- **Talos:** Manual upgrades, quarterly cadence
- **Kubernetes:** Manual upgrades, every minor release (~3-4x/year)
- **Flux:** Renovate PRs, merged after review
- **Applications:** Renovate PRs, automatic merge for patch versions

**Consequences:**
- ✅ **Positive:**
  - Complete control over timing and testing
  - Can test upgrades in non-production first (local K3s)
  - Stability prioritized over cutting-edge versions
  - Learn upgrade procedures manually first year
- ❌ **Negative:**
  - Manual effort required quarterly
  - Could fall behind on security patches if delayed
  - No automatic rollback on failure

**Upgrade Schedule:**
```yaml
Quarterly Talos Upgrades:
  - Q1: January (after holiday break)
  - Q2: April
  - Q3: July
  - Q4: October

Kubernetes Upgrades (per minor version):
  - Wait 4-6 weeks after release for stability
  - Test on local K3s cluster first
  - Upgrade infra cluster (week 1)
  - Upgrade apps cluster (week 2)

Flux Upgrades:
  - Monthly Renovate PR
  - Review changelog
  - Merge after review

Application Upgrades:
  - Patch versions: Auto-merge after 3 days
  - Minor versions: Manual review
  - Major versions: Manual review + testing
```

**Alternatives Considered:**
- Automated with system-upgrade-controller: Rejected (want manual control first year)
- Never upgrade: Rejected (security risk)

---

### ADR-009: GitHub Actions Runners
**Decision:** Deploy self-hosted Actions runners on infra cluster

**Context:**
- Need CI/CD automation for GitOps
- Options: GitHub-hosted runners, self-hosted on cluster, or self-hosted on VMs

**Decision:**
- Deploy actions-runner-controller on infra cluster
- 2 runner pods with resource limits
- Auto-scaling based on workflow queue

**Consequences:**
- ✅ **Positive:**
  - No GitHub Actions minutes cost (free)
  - Faster workflow execution (no cold start)
  - Access to cluster internals (kubectl, helm)
  - Can cache dependencies locally
- ❌ **Negative:**
  - Uses infra cluster resources (~8GB RAM, 2 CPU)
  - Security consideration (CI jobs run in cluster)
  - Maintenance overhead (keep runners updated)

**Resource Allocation:**
```yaml
Actions Runner Configuration:
  Replicas: 2 (can scale to 5)
  CPU: 1 core per runner (burstable to 2)
  Memory: 4GB per runner (limit 6GB)
  Storage: 20GB ephemeral per runner

Total Resource Usage:
  Baseline: 8GB RAM, 2 CPU
  Peak (5 runners): 30GB RAM, 10 CPU
```

**Security Measures:**
```yaml
- Dedicated namespace: actions-runner-system
- Resource quotas enforced
- Network policies: Deny all except necessary
- RBAC: Least privilege service account
- Ephemeral runners (recreated per job)
- No persistent storage access
```

**Alternatives Considered:**
- GitHub-hosted runners: Rejected (cost, can't access cluster)
- Runners on apps cluster: Rejected (prefer isolation on infra)
- Runners on dedicated VM: Rejected (want Kubernetes-native solution)

---

### ADR-010: Staging Cluster Strategy
**Decision:** No staging cluster, use Flux dry-run and local testing

**Context:**
- Need testing strategy before production deployment
- Options: Dedicated staging cluster, apps cluster as staging, or no staging

**Decision:**
- **Local testing:** K3s/Kind on laptop for development
- **Flux validation:** `flux diff` and `flux build` before merge
- **Production testing:** Feature flags and gradual rollout
- **No dedicated staging cluster:** Too expensive for home lab

**Consequences:**
- ✅ **Positive:**
  - No additional hardware cost (3 more nodes = $3000+)
  - No 3x operational overhead
  - Sufficient validation with Flux + local testing
  - Production is the "staging" (acceptable for home)
- ❌ **Negative:**
  - Higher risk in production (no realistic staging)
  - Can't test Talos/hardware-specific issues locally
  - Network/storage testing not realistic on laptop

**Testing Workflow:**
```bash
# 1. Local development (K3s)
k3d cluster create test
kubectl apply -k ./apps/production/myapp
# Test functionality

# 2. Flux validation
flux diff kustomization apps --path ./apps/production
flux build kustomization apps --path ./apps/production --dry-run

# 3. Commit and push (Flux reconciles)
git commit -m "feat: add myapp"
git push origin main

# 4. Monitor deployment
flux logs --follow
kubectl get pods -n myapp-namespace --watch

# 5. Rollback if needed
flux suspend kustomization apps
git revert HEAD
git push
flux resume kustomization apps
```

**Alternatives Considered:**
- Dedicated staging cluster: Rejected (hardware cost, operational overhead)
- Apps cluster as staging: Rejected (production should be clean)

---

### ADR-011: Cloudflare Tunnel Architecture
**Decision:** One tunnel per cluster (infra-tunnel, apps-tunnel)

**Context:**
- With Cloudflare Tunnel decision (ADR-002), need to plan tunnel structure
- Options: One tunnel for all, one per cluster, or one per service

**Decision:**
- **Infra cluster:** One tunnel (`k8s-infra-tunnel`)
- **Apps cluster:** One tunnel (`k8s-apps-tunnel`)
- Independent failure domains, clean separation

**Consequences:**
- ✅ **Positive:**
  - Clear separation (infra = monitoring, apps = applications)
  - Independent failure (one tunnel down doesn't affect other cluster)
  - Easy to manage (2 tunnels total)
  - Simple credential management (2 tunnel tokens)
- ❌ **Negative:**
  - 2 tunnel tokens to store in 1Password
  - 2 tunnel pods to maintain

**Implementation:**
```yaml
Infra Cluster Tunnel:
  Tunnel Name: k8s-infra-tunnel
  Tunnel ID: <uuid>
  Routes:
    - grafana.monosense.io → grafana.monitoring.svc.cluster.local:3000
    - hubble.infra.monosense.io → hubble-ui.kube-system.svc:80
    - ceph.infra.monosense.io → rook-ceph-mgr-dashboard:7000
    - prometheus.monosense.io → vmalert.monitoring.svc:8080

Apps Cluster Tunnel:
  Tunnel Name: k8s-apps-tunnel
  Tunnel ID: <uuid>
  Routes:
    - *.monosense.io → <app-service>.svc.cluster.local:80/443
    - app1.monosense.io, app2.monosense.io, etc.

Cloudflared Deployment:
  Replicas: 2 per cluster (HA)
  Resources: 100m CPU, 128Mi RAM per replica
  Credentials: External Secret from 1Password
```

**Alternatives Considered:**
- Single tunnel for both clusters: Rejected (single point of failure)
- One tunnel per service: Rejected (too complex, many tokens)

---

### ADR-012: Authentication Strategy
**Decision:** Keycloak for centralized OAuth/OIDC authentication

**Context:**
- Need single sign-on for cluster services (Grafana, Hubble, Ceph, etc.)
- Options: Authentik, Keycloak, external provider, or basic auth

**Decision:**
- Deploy Keycloak on infra cluster
- PostgreSQL backend (shared with platform DB)
- OIDC/OAuth2 for all services
- SAML capability for future needs

**Consequences:**
- ✅ **Positive:**
  - Mature, enterprise-grade solution
  - Rich feature set (OIDC, OAuth2, SAML, LDAP)
  - Well-documented integrations
  - Large community and support
- ❌ **Negative:**
  - Resource-heavy (Java-based)
    - 2GB RAM baseline, 4GB under load
    - 1-2 CPU cores
  - Complex configuration initially
  - More moving parts than Authentik

**Resource Allocation:**
```yaml
Keycloak:
  Replicas: 2 (HA)
  Resources per replica:
    Requests: 1 CPU, 2GB RAM
    Limits: 2 CPU, 4GB RAM
  Database: PostgreSQL (shared platform DB)
  Storage: Configuration in PostgreSQL
  Total: 4GB RAM, 2 CPU (baseline)
```

**Integrations:**
```yaml
Services with SSO:
  - Grafana (OIDC)
  - Hubble UI (OAuth2 proxy)
  - Ceph Dashboard (SAML)
  - Harbor (OIDC) [when deployed]
  - GitLab (SAML) [when deployed]
  - Future applications (OIDC/OAuth2)
```

**Alternatives Considered:**
- Authentik: Rejected (user chose Keycloak for maturity)
- External provider (Auth0): Rejected (want self-hosted)
- Basic auth: Rejected (no centralized auth, multiple passwords)

**Note:** This decision differs from analyst recommendation (Authentik), but Keycloak is a valid choice given the available resources on infra cluster.

---

### ADR-013: DNS Management
**Decision:** External-DNS with Cloudflare provider for automatic DNS management

**Context:**
- Need DNS records for services (internal and external)
- Options: Manual DNS, external-dns with Cloudflare, or external-dns with local DNS

**Decision:**
- Deploy external-dns on both clusters
- Cloudflare provider for public DNS (monosense.io)
- Automatically manage DNS records for:
  - LoadBalancer services (internal IPs)
  - Ingress resources (Cloudflare Tunnel hostnames)

**Consequences:**
- ✅ **Positive:**
  - Automatic DNS record creation/deletion
  - No manual DNS management for new services
  - LoadBalancer IPs automatically registered
  - Cloudflare as authoritative DNS (fast, reliable)
- ❌ **Negative:**
  - Cloudflare API token management (security consideration)
  - External dependency on Cloudflare API
  - Potential for accidental DNS changes if misconfigured

**Configuration:**
```yaml
External-DNS (Infra Cluster):
  Provider: Cloudflare
  Domain: monosense.io
  Sources:
    - service (LoadBalancer only)
    - ingress
  Filters:
    - Annotation: external-dns.alpha.kubernetes.io/hostname
  DNS Records:
    - grafana.monosense.io → Cloudflare Tunnel
    - hubble.infra.monosense.io → Cloudflare Tunnel
    - ceph.infra.monosense.io → Cloudflare Tunnel

External-DNS (Apps Cluster):
  Provider: Cloudflare
  Domain: monosense.io
  Sources:
    - service (LoadBalancer only)
    - ingress
  DNS Records:
    - *.monosense.io → Cloudflare Tunnel
    - app-specific subdomains
```

**Safety Mechanisms:**
```yaml
- Domain filter: monosense.io only (prevent global DNS changes)
- TXT record ownership (external-dns managed only)
- Dry-run mode initially (verify before actual DNS changes)
- RBAC: Least privilege (only DNS management, no other Cloudflare API access)
```

**Alternatives Considered:**
- Manual DNS: Rejected (user wants automation)
- Local DNS (Bind/Pi-hole): Rejected (more components to manage)
- No external DNS: Rejected (user chose automation)

---

### ADR-014: Secret Rotation Policy
**Decision:** Manual quarterly secret rotation

**Context:**
- Need credential rotation policy for security
- Options: Automated rotation, manual rotation, or on-demand only

**Decision:**
- **Rotation frequency:** Quarterly (every 3 months)
- **Method:** Manual process with documented procedure
- **Scope:** API keys, database passwords, service account tokens
- **Exception:** TLS certificates (Let's Encrypt auto-rotates)

**Consequences:**
- ✅ **Positive:**
  - Controlled rotation process (test before/after)
  - Predictable schedule (4x per year)
  - Lower risk of service disruption
  - Appropriate for home environment (lower risk tolerance)
- ❌ **Negative:**
  - Manual effort required quarterly
  - 90-day credential lifetime (vs 30-day best practice)
  - Easy to forget without calendar reminders

**Rotation Schedule:**
```yaml
Q1 (January):
  - PostgreSQL passwords (all databases)
  - Application database credentials

Q2 (April):
  - MinIO credentials (VolSync, Velero)
  - S3 access keys

Q3 (July):
  - 1Password Connect tokens
  - External Secrets operator credentials

Q4 (October):
  - Cloudflare API tokens (external-dns, cloudflared)
  - GitHub PATs (Flux, Actions runners)

Ad-hoc (Security Events):
  - Rotate immediately if compromised
  - Rotate after employee/contractor access revoked
  - Rotate if credential appears in logs/metrics
```

**Rotation Procedure:**
```bash
# Example: PostgreSQL password rotation
# 1. Generate new password in 1Password
# 2. Update secret in 1Password vault
# 3. External Secrets will sync automatically (within 5 minutes)
# 4. Restart pods to pick up new credentials
kubectl rollout restart deployment/<app> -n <namespace>
# 5. Verify connectivity
kubectl logs -n <namespace> <pod> --tail=50
# 6. Document in change log
```

**Alternatives Considered:**
- Automated 90-day rotation: Rejected (risk of service disruption)
- On-demand only: Rejected (secrets never rotated routinely)
- Monthly rotation: Rejected (too frequent for home environment)

---

### ADR-015: Ceph Filesystem Strategy
**Decision:** RBD (block storage) only initially, add CephFS on-demand

**Context:**
- Rook Ceph supports RBD (ReadWriteOnce) and CephFS (ReadWriteMany)
- Options: Deploy both from start, or RBD only

**Decision:**
- **Phase 1:** Deploy RBD only (block storage)
- **On-demand:** Add CephFS when first RWX workload is needed
- CephFS can be added in ~10 minutes without disruption

**Consequences:**
- ✅ **Positive:**
  - Simpler initial Ceph deployment
  - Lower resource overhead (no MDS pods initially)
  - Most applications use ReadWriteOnce (databases, apps)
  - Can add CephFS quickly when needed
- ❌ **Negative:**
  - Need to deploy CephFS later if RWX storage is needed
  - Some workloads blocked until CephFS is added

**When to Add CephFS:**
```yaml
Use Cases Requiring ReadWriteMany:
  - Media streaming (Plex, Jellyfin)
  - Shared configuration directories
  - Multi-pod read workloads
  - NFS-like shared storage needs

Deployment Time:
  - Apply CephFilesystem CRD: 2 minutes
  - Wait for MDS pods ready: 5 minutes
  - Create StorageClass: 1 minute
  - Total: ~10 minutes
```

**CephFS Resources (when deployed):**
```yaml
MDS Pods:
  Active: 1 pod
  Standby: 1 pod
  Resources per MDS:
    Requests: 1 CPU, 2GB RAM
    Limits: 2 CPU, 4GB RAM
  Total: 4GB RAM, 2 CPU
```

**Alternatives Considered:**
- Deploy CephFS from day 1: Rejected (unnecessary complexity, resource overhead)
- Never use CephFS: Rejected (some workloads may need RWX)

---

### ADR-016: Ceph Object Storage (RGW)
**Decision:** Use MinIO on Synology NAS, no Ceph RGW deployment

**Context:**
- Need S3-compatible object storage for backups (VolSync, Velero)
- Options: Ceph RGW in cluster, or external MinIO on Synology

**Decision:**
- **S3 Backend:** MinIO on Synology NAS
- **No Ceph RGW:** Avoids duplicate S3 implementation
- **Future:** Can add RGW if in-cluster S3 is needed for applications

**Consequences:**
- ✅ **Positive:**
  - Leverage existing MinIO on Synology (already available)
  - No cluster resources for RGW (saves 2-4GB RAM, 1-2 CPU)
  - Simpler Ceph deployment (RBD only initially)
  - Backups stored on separate hardware (better DR isolation)
- ❌ **Negative:**
  - External dependency on Synology NAS availability
  - Network latency for S3 operations (mitigated: 10GbE same network)
  - Cannot provide S3 to applications without MinIO access

**MinIO Configuration:**
```yaml
MinIO on Synology:
  Location: Synology RS1221+ NAS
  Network: 10.25.11.x (same network as cluster)
  Access: 10GbE connection

Buckets:
  - volsync/ (VolSync Restic repositories)
  - velero-backups/ (Velero backup storage)
  - harbor/ (future Harbor image storage)
  - gitlab/ (future GitLab object storage)

Security:
  - Access keys stored in 1Password
  - Synced to clusters via External Secrets
  - Network access: Cluster nodes only (firewall rules)
```

**Alternatives Considered:**
- Ceph RGW in cluster: Rejected (duplicate S3, unnecessary resource usage)
- AWS S3: Rejected (want local control, no egress costs)
- Self-hosted MinIO in cluster: Rejected (already have it on Synology)

---

### ADR-017: Talos System Extensions
**Decision:** Current system extensions are sufficient (no additions)

**Context:**
- Talos supports system extensions for additional kernel modules
- Current extensions: intel-ucode, i915-ucode, iscsi-tools, nfsrahead

**Decision:**
- Keep current extension set
- No additional extensions needed initially
- Re-evaluate if new workloads require additional kernel modules

**Consequences:**
- ✅ **Positive:**
  - Current extensions cover essential needs
  - Simple Talos image (fewer components)
  - Lower maintenance overhead
- ❌ **Negative:**
  - May need to add extensions later if workloads require them

**Current Extensions:**
```yaml
System Extensions:
  - siderolabs/intel-ucode
    Purpose: Intel CPU microcode updates
    Required: Yes (Intel i7-8700T CPUs)

  - siderolabs/i915-ucode
    Purpose: Intel GPU firmware
    Required: Yes (Intel UHD Graphics 630)

  - siderolabs/iscsi-tools
    Purpose: iSCSI initiator support
    Required: Yes (Rook Ceph RBD uses iSCSI internally)

  - siderolabs/nfsrahead
    Purpose: NFS read-ahead optimization
    Required: Optional (improves NFS performance if used)
```

**Future Considerations:**
```yaml
Extensions to Consider Later:
  - qemu-guest-agent (if running on VMs in future)
  - stargz-snapshotter (faster image pulls, experimental)
  - thunderbolt (if workloads need Thunderbolt devices)
  - zfs (if ZFS storage is added)
```

**Alternatives Considered:**
- Add qemu-guest-agent: Rejected (bare metal, not VMs)
- Add stargz-snapshotter: Rejected (experimental, not needed)

---

### ADR-018: Maintenance Window Strategy
**Decision:** Rolling updates with no fixed maintenance window (HA design)

**Context:**
- Need strategy for cluster maintenance and updates
- Options: Fixed maintenance window, rolling updates, or ad-hoc

**Decision:**
- **Default:** Rolling updates (zero-downtime)
- **Exception:** Ad-hoc planning for disruptive operations
- **HA design** enables most operations without downtime

**Consequences:**
- ✅ **Positive:**
  - No scheduled downtime for users
  - Flexible maintenance timing
  - HA design (3 nodes per cluster) supports rolling updates
  - Most operations can be non-disruptive
- ❌ **Negative:**
  - Some operations still require downtime (Talos major upgrades)
  - Need to coordinate for disruptive maintenance
  - Cluster must always maintain quorum (2/3 nodes up)

**Zero-Downtime Operations:**
```yaml
Supported (Rolling Updates):
  - Pod updates (Deployments with rolling strategy)
  - Node reboots (drain → reboot → uncordon)
  - Kubernetes minor version upgrades
  - Application updates (with proper health checks)
  - Cert-manager certificate renewals
  - Storage expansion (Ceph can add OSDs online)

Requires Downtime (Plan Ahead):
  - Talos major version upgrades
  - Network reconfiguration (Cilium CNI changes)
  - Ceph major version upgrades
  - Control plane topology changes
  - Full cluster rebuild
```

**Rolling Update Procedure:**
```bash
# Example: Node maintenance with zero downtime
# 1. Drain node
kubectl drain prod-01 --ignore-daemonsets --delete-emptydir-data
# 2. Perform maintenance (reboot, upgrade, etc.)
talosctl reboot --nodes 10.25.11.11
# 3. Wait for node ready
kubectl wait --for=condition=Ready node/prod-01 --timeout=10m
# 4. Uncordon node
kubectl uncordon prod-01
# 5. Repeat for next node
```

**Alternatives Considered:**
- Fixed maintenance window (Sundays 2-6 AM): Rejected (HA design makes it unnecessary)
- Ad-hoc only: Rejected (some coordination still needed for disruptive ops)

---

### ADR-019: Disaster Recovery Testing Schedule
**Decision:** Tiered testing schedule (weekly/monthly/quarterly/annual)

**Context:**
- Need to validate backup/restore procedures regularly
- Options: Monthly full DR, quarterly full DR, or tiered approach

**Decision:**
- **Weekly:** Automated testing (single pod, snapshot creation)
- **Monthly:** Manual testing (single PVC restore, node reboot)
- **Quarterly:** Cluster rebuild testing (apps cluster)
- **Annual:** Full infrastructure DR (both clusters)

**Consequences:**
- ✅ **Positive:**
  - Comprehensive testing without excessive time investment
  - Critical components tested more frequently
  - Confidence in DR procedures
  - Issues caught early (before real disaster)
- ❌ **Negative:**
  - Requires dedicated time for testing
  - Monthly/quarterly tests can be disruptive
  - Need to document and track test results

**Testing Schedule:**
```yaml
Weekly (Automated):
  Time: <5 minutes
  Tests:
    - Delete single pod (verify auto-recovery)
    - Create PVC snapshot (verify CSI snapshotter works)
    - Verify VolSync last sync timestamp
    - Verify Velero last backup timestamp
  Automation: CI/CD pipeline or CronJob

Monthly (Manual):
  Time: ~1 hour
  Tests:
    - Restore single PVC from VolSync backup
    - Reboot single node (verify drain/uncordon)
    - Verify Velero backup restoration (dry-run)
    - Test cross-cluster service access (ClusterMesh)
  Documentation: Create test report

Quarterly (Manual):
  Time: ~3 hours
  Tests:
    - Full apps cluster rebuild from Talos configs
    - Flux bootstrap and reconciliation
    - Database restore from VolSync backup
    - ClusterMesh reconnection
    - Application deployment and validation
  Documentation: Detailed DR report

Annual (Manual):
  Time: ~6-8 hours (full day)
  Tests:
    - Complete infrastructure DR (both clusters)
    - Rebuild from Talos configs + Git repository
    - Restore all data from backups (VolSync + Velero)
    - Re-establish ClusterMesh
    - Validate all services operational
    - Document any procedure gaps or issues
  Documentation: Comprehensive DR drill report
```

**Test Result Tracking:**
```yaml
Location: docs/dr-tests/
Format:
  - YYYY-MM-weekly-tests.md
  - YYYY-MM-monthly-test.md
  - YYYY-QX-quarterly-test.md
  - YYYY-annual-dr-drill.md

Content:
  - Date/time of test
  - Test procedure followed
  - Results (pass/fail per test)
  - Issues encountered
  - Remediation actions
  - Time to complete
  - Lessons learned
```

**Alternatives Considered:**
- Monthly full DR: Rejected (too time-consuming, 4 hours every month)
- Quarterly full DR: Rejected (too infrequent for critical validation)
- No testing: Rejected (backups are useless if not tested)

---

### ADR-020: Resource Quota Strategy
**Decision:** Implement resource quotas in Phase 2 after observing usage patterns

**Context:**
- Need to prevent resource exhaustion by runaway workloads
- Options: Immediate strict quotas, monitoring only, or Phase 2 enforcement

**Decision:**
- **Weeks 1-6:** No quotas, observe usage with Victoria Metrics
- **Week 7:** Analyze resource usage patterns per namespace
- **Week 8:** Implement namespace resource quotas
- **Ongoing:** Adjust quotas based on actual usage

**Consequences:**
- ✅ **Positive:**
  - Learn actual resource requirements before restricting
  - Set realistic quotas based on observed usage
  - Avoid blocking legitimate workloads
  - Single-user environment = lower risk of abuse
- ❌ **Negative:**
  - No namespace-level protection initially (6-8 weeks)
  - One misbehaving app could exhaust cluster resources
  - Need to retrofit quotas to existing namespaces

**Implementation Timeline:**
```yaml
Weeks 1-6 (Observation):
  - Deploy Victoria Metrics
  - Monitor per-namespace resource usage
  - Identify resource consumption patterns
  - Document peak and average usage

Week 7 (Analysis):
  - Generate usage reports per namespace
  - Identify outliers and trends
  - Calculate quota recommendations (peak + 20% buffer)
  - Review with growth projections

Week 8 (Implementation):
  - Create ResourceQuota objects per namespace
  - Set limits based on analysis + buffer
  - Monitor quota violations (alerts)
  - Adjust as needed

Ongoing (Tuning):
  - Monthly review of quota usage
  - Adjust quotas if consistently hitting limits
  - Remove quotas if unnecessary
```

**Future Quota Strategy:**
```yaml
Namespace Resource Quotas (Week 8+):

databases:
  requests:
    cpu: "8"
    memory: 16Gi
    storage: 500Gi
  limits:
    cpu: "16"
    memory: 32Gi
  pods: "20"

monitoring:
  requests:
    cpu: "10"
    memory: 20Gi
    storage: 200Gi
  limits:
    cpu: "20"
    memory: 40Gi
  pods: "50"

kube-system:
  requests:
    cpu: "8"
    memory: 8Gi
  limits:
    cpu: "16"
    memory: 16Gi
  pods: "100"

applications (per namespace):
  requests:
    cpu: "4"
    memory: 8Gi
    storage: 100Gi
  limits:
    cpu: "8"
    memory: 16Gi
  pods: "20"

Platform (rook-ceph, cert-manager, etc.):
  No quotas (platform needs unrestricted resources)
```

**LimitRanges (Always Enforced):**
```yaml
# Default limits for pods without resource specifications
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: applications
spec:
  limits:
    - type: Container
      default:
        cpu: "1"
        memory: 512Mi
      defaultRequest:
        cpu: "100m"
        memory: 128Mi
      max:
        cpu: "4"
        memory: 8Gi
      min:
        cpu: "10m"
        memory: 16Mi
```

**Alternatives Considered:**
- Immediate strict quotas: Rejected (don't know actual requirements yet)
- No quotas ever: Rejected (risk of resource exhaustion)
- Soft quotas (monitoring only): Rejected (no enforcement when needed)

---

## Implementation Impact Summary

### Resource Allocation (Infra Cluster)

```yaml
Infra Cluster Total Capacity (3 nodes × 6 CPU, 64GB RAM):
  Total: 18 CPU, 192GB RAM

Reserved per Node:
  OS + K8s:           2 CPU, 8GB RAM
  Ceph MON:           1 CPU, 4GB RAM
  Ceph MGR:           0.5 CPU, 2GB RAM
  Ceph OSD:           4 CPU, 8GB RAM
  Subtotal:           7.5 CPU, 22GB RAM per node

Cluster-Wide Reserved:
  Platform:           22.5 CPU, 66GB RAM

Available for Workloads:
  Total:              ~13.5 CPU, 126GB RAM

Workload Allocation:
  PostgreSQL:         2 CPU, 4GB RAM
  Keycloak:           2 CPU, 4GB RAM (ADR-012)
  Victoria Metrics:   4 CPU, 16GB RAM
  Fluent-bit:         0.5 CPU, 1GB RAM
  Actions Runners:    2 CPU, 8GB RAM (ADR-009)
  Cloudflared:        0.2 CPU, 256MB RAM
  External-DNS:       0.1 CPU, 128MB RAM (ADR-013)
  Cert-manager:       0.5 CPU, 512MB RAM
  External Secrets:   0.2 CPU, 256MB RAM
  Misc Services:      2 CPU, 10GB RAM
  Subtotal:           13.5 CPU, 44GB RAM

Remaining Buffer:     0 CPU, 82GB RAM
```

**Verdict:** ✅ Infra cluster can support all decisions comfortably! RAM buffer is excellent.

### Network Configuration

```yaml
External Access:
  Method: Cloudflare Tunnel (ADR-002, ADR-011)
  Tunnels: 2 (infra, apps)
  No LoadBalancer IPs for ingress needed

LoadBalancer IP Pools:
  Infra: 10.25.11.100-149 (50 IPs)
    - ClusterMesh API: 10.25.11.101
    - Internal services: 10.25.11.102-149
  Apps: 10.25.11.150-199 (50 IPs)
    - Internal services: 10.25.11.150-199

DNS:
  Provider: Cloudflare (ADR-013)
  Automation: External-DNS
  Domain: monosense.io
  Records: Automatic (LoadBalancers, Ingress)
```

### Backup Strategy

```yaml
VolSync (PVC Data):
  Schedule: Every 6 hours (ADR-006)
  Method: Restic + Ceph CSI snapshots
  Destination: MinIO S3 on Synology (ADR-016)
  Retention: 6H/7D/4W/6M
  RPO: 6 hours

Velero (K8s Resources):
  Schedule: Weekly
  Method: CSI snapshots + object storage
  Destination: MinIO S3 on Synology
  Retention: 30 days
  Deployment: Day 1 (ADR-004)

Disaster Recovery:
  Testing: Tiered schedule (ADR-019)
  Weekly: Automated checks
  Monthly: PVC restore
  Quarterly: Cluster rebuild
  Annual: Full DR drill
```

### Security Posture

```yaml
Network Access:
  External: Cloudflare Tunnel only (zero-trust)
  Internal: ClusterMesh (cross-cluster)

Authentication:
  Method: Keycloak (OIDC/OAuth2/SAML) (ADR-012)
  Deployment: Infra cluster
  Backend: PostgreSQL

Network Policies:
  Phase 1 (Weeks 1-6): None (observe with Hubble)
  Phase 2 (Week 8+): Default deny + explicit allow (ADR-005)

Pod Security:
  Phase 1 (Weeks 1-8): Audit mode
  Phase 2 (Week 9): Baseline enforcement
  Phase 3 (Month 3): Restricted enforcement (ADR-007)

Secret Management:
  Storage: 1Password
  Sync: External Secrets Operator
  Rotation: Quarterly manual (ADR-014)
```

---

## Decision Authority

**Decisions Made By:** Platform Architect (User)
**Advisory Support:** AI Business Analyst (Mary)
**Review Date:** 2025-10-14
**Next Review:** After Phase 1 completion (Month 2)

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-14 | 1.0 | Initial ADR with all 20 decisions | Platform Team |

---

## References

- [Brainstorming Session Results](./brainstorming-session-results.md)
- [Technical Deep Dive](./technical-deep-dive.md)
- FluxCD Multi-Cluster Architecture: https://stefanprodan.com/blog/2024/fluxcd-multi-cluster-architecture/
- Cilium ClusterMesh Documentation: https://docs.cilium.io/en/stable/network/clustermesh/
- Rook Ceph Best Practices: https://rook.io/docs/rook/latest/Getting-Started/quickstart/
- VolSync Documentation: https://volsync.readthedocs.io/

---

*Architecture Decision Record - Version 1.0*
*Generated: 2025-10-14*
