# 🚀 Platform Delivery Schedule (Q4 2025 – Q1 2026)

> **Multi-cluster GitOps platform delivery roadmap**

---

## 📋 Assumptions

| Parameter | Value |
|-----------|-------|
| **Sprint Length** | 2 weeks |
| **Sprint 1 Start** | Monday, October 27, 2025 |
| **Change Freeze** | December 22, 2025 – January 2, 2026 |
| **Target Clusters** | `infra`, `apps` (+ optional `apps-dev`/`stg`/`prod`) |

---

## 🛤️ Parallelization Model

| Lane | Scope | Priority |
|------|-------|----------|
| **Infra** | `kubernetes/infrastructure` + shared platform workloads | Critical Path |
| **Apps** | `kubernetes/workloads` on apps cluster(s) | Secondary |
| **Cross-Platform** | Observability, CI/CD, Registry, Tenancy | Shared |

**Rule of Thumb**: Complete "Critical Path" first; run "Parallel Options" in the same sprint when prerequisites are explicitly met.

---

## 📊 Story Sequence Index (1–41)

<details>
<summary><strong>Click to expand complete story sequence</strong></summary>

### 🥾 Bootstrap & Foundation (1-7)
1. `STORY-BOOT-TALOS` — Talos Linux base
2. `STORY-BOOT-CRDS` — Custom Resource Definitions
3. `STORY-BOOT-CORE` — Core Kubernetes components
4. `STORY-GITOPS-SELF-MGMT-FLUX` — Flux self-management
5. `STORY-SEC-EXTERNAL-SECRETS-BASE` — External Secrets Operator
6. `STORY-OPS-RELOADER-ALL-CLUSTERS` — Reloader for config/secret updates
7. `STORY-BOOT-AUTOMATION-ALIGN` — Bootstrap automation alignment

### 🌐 Networking & DNS (8-13)
8. `STORY-NET-CILIUM-CORE-GITOPS` — Cilium core networking
9. `STORY-NET-CILIUM-IPAM` — Cilium IP address management
10. `STORY-NET-CILIUM-GATEWAY` — Cilium Gateway API
11. `STORY-DNS-COREDNS-BASE` — CoreDNS base configuration
12. `STORY-SEC-CERT-MANAGER-ISSUERS` — Certificate Manager & issuers
13. `STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL` — ExternalDNS with Cloudflare

### 💾 Storage Foundation (14-16)
14. `STORY-STO-ROOK-CEPH-OPERATOR` — Rook-Ceph operator
15. `STORY-STO-ROOK-CEPH-CLUSTER` — Rook-Ceph cluster deployment
16. `STORY-STO-OPENEBS-BASE` — OpenEBS local storage

### 📈 Observability Stack (17-22)
17. `STORY-OBS-VM-STACK` — Victoria Metrics stack (design)
18. `STORY-OBS-VICTORIA-LOGS` — Victoria Logs (design)
19. `STORY-OBS-FLUENT-BIT` — Fluent Bit (design)
20. `STORY-OBS-VM-STACK-IMPLEMENT` — Victoria Metrics implementation
21. `STORY-OBS-VICTORIA-LOGS-IMPLEMENT` — Victoria Logs implementation
22. `STORY-OBS-FLUENT-BIT-IMPLEMENT` — Fluent Bit implementation

### 🔀 Advanced Networking (23-25)
23. `STORY-NET-CILIUM-BGP` — Cilium BGP (design)
24. `STORY-NET-CILIUM-BGP-CP-IMPLEMENT` — BGP Control Plane implementation
25. `STORY-NET-SPEGEL-REGISTRY-MIRROR` — Spegel registry mirror

### 🗄️ Database Platforms (26-28)
26. `STORY-DB-CNPG-OPERATOR` — CloudNative-PG operator
27. `STORY-DB-CNPG-SHARED-CLUSTER` — Shared PostgreSQL cluster
28. `STORY-DB-DRAGONFLY-OPERATOR-CLUSTER` — DragonflyDB operator & cluster

### 🔒 Security & Identity (29-31)
29. `STORY-SEC-NP-BASELINE` — Network Policy baseline
30. `STORY-SEC-SPIRE-CILIUM-AUTH` — SPIRE + Cilium authentication
31. `STORY-IDP-KEYCLOAK-OPERATOR` — Keycloak identity provider

### 🕸️ Cluster Mesh (32-33)
32. `STORY-NET-CILIUM-CLUSTERMESH` — Cilium ClusterMesh
33. `STORY-NET-CLUSTERMESH-DNS` — ClusterMesh DNS

### 💾 Apps Cluster Storage (34-36)
34. `STORY-STO-APPS-OPENEBS-BASE` — OpenEBS for apps cluster
35. `STORY-STO-APPS-ROOK-CEPH-OPERATOR` — Rook-Ceph operator (apps)
36. `STORY-STO-APPS-ROOK-CEPH-CLUSTER` — Rook-Ceph cluster (apps)

### 🔄 CI/CD & Registry (37-39)
37. `STORY-CICD-GITHUB-ARC` — GitHub Actions Runner Controller
38. `STORY-CICD-GITLAB-APPS` — GitLab on apps cluster
39. `STORY-APP-HARBOR` — Harbor container registry

### 🏢 Tenancy & Backup (40-41)
40. `STORY-TENANCY-BASELINE` — Multi-tenant namespace baseline
41. `STORY-BACKUP-VOLSYNC-APPS` — Volsync backup for apps

</details>

---

## 📅 Sprint Schedule

### 🥾 Sprint 1 — Bootstrap & GitOps
**Oct 27 – Nov 7, 2025** | 2 weeks

#### ⭐ Critical Path
1. `STORY-BOOT-TALOS` — Talos Linux base
2. `STORY-BOOT-CRDS` — Custom Resource Definitions
3. `STORY-BOOT-CORE` — Core Kubernetes components
4. `STORY-GITOPS-SELF-MGMT-FLUX` — Flux self-management
5. `STORY-SEC-EXTERNAL-SECRETS-BASE` — External Secrets Operator
6. `STORY-OPS-RELOADER-ALL-CLUSTERS` — Reloader for config/secret updates
7. `STORY-BOOT-AUTOMATION-ALIGN` — Bootstrap automation alignment

#### 🔀 Parallel Options (when ready)
- Author "runbooks" and automate bootstrap verifications
- Prep placeholders for cluster‑settings and secrets paths across infra/apps

### 🌐 Sprint 2 — Networking Core & DNS
**Nov 10 – Nov 21, 2025** | 2 weeks

#### ⭐ Critical Path
8. `STORY-NET-CILIUM-CORE-GITOPS` — Cilium core networking
9. `STORY-NET-CILIUM-IPAM` — Cilium IP address management
10. `STORY-NET-CILIUM-GATEWAY` — Cilium Gateway API
11. `STORY-DNS-COREDNS-BASE` — CoreDNS base configuration
12. `STORY-SEC-CERT-MANAGER-ISSUERS` — Certificate Manager & issuers
13. `STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL` — ExternalDNS with Cloudflare

#### 🔀 Parallel Options
- Draft BGP design (23) in parallel during the sprint tail, once core Cilium is stable
- Prep Gateway‑attached route examples for first apps

### 💾 Sprint 3 — Storage (Infra) & Observability Base
**Nov 24 – Dec 5, 2025** | 2 weeks

#### ⭐ Critical Path
14. `STORY-STO-ROOK-CEPH-OPERATOR` — Rook-Ceph operator
15. `STORY-STO-ROOK-CEPH-CLUSTER` — Rook-Ceph cluster deployment
16. `STORY-STO-OPENEBS-BASE` — OpenEBS local storage
17. `STORY-OBS-VM-STACK` — Victoria Metrics stack (design)
18. `STORY-OBS-VICTORIA-LOGS` — Victoria Logs (design)
19. `STORY-OBS-FLUENT-BIT` — Fluent Bit (design)

#### 🔀 Parallel Options
- Begin drafting CI for kubeconform/kustomize build checks on platform dirs
- Start policy baselines (read‑only review) to accelerate Sprint 5 security work

> ⚠️ **Note**: Nov 27 (Thanksgiving) — pace scope accordingly

### 📈 Sprint 4 — Obs Implementation & Networking Advanced
**Dec 8 – Dec 19, 2025** | 2 weeks

#### ⭐ Critical Path
20. `STORY-OBS-VM-STACK-IMPLEMENT` — Victoria Metrics implementation
21. `STORY-OBS-VICTORIA-LOGS-IMPLEMENT` — Victoria Logs implementation
22. `STORY-OBS-FLUENT-BIT-IMPLEMENT` — Fluent Bit implementation
23. `STORY-NET-CILIUM-BGP` — Cilium BGP (design)
24. `STORY-NET-CILIUM-BGP-CP-IMPLEMENT` — BGP Control Plane implementation
25. `STORY-NET-SPEGEL-REGISTRY-MIRROR` — Spegel registry mirror

#### 🔀 Parallel Options
- Prep CNPG operator values and secrets paths for Sprint 5
- Draft Keycloak operator requirements

---

### ❄️ Change Freeze
**Dec 22, 2025 – Jan 2, 2026**

> 🎄 **Holiday break** — No production changes during this period

---

### 🗄️ Sprint 5 — Databases, Security Advanced, IDP
**Jan 5 – Jan 16, 2026** | 2 weeks

#### ⭐ Critical Path
26. `STORY-DB-CNPG-OPERATOR` — CloudNative-PG operator
27. `STORY-DB-CNPG-SHARED-CLUSTER` — Shared PostgreSQL cluster
28. `STORY-DB-DRAGONFLY-OPERATOR-CLUSTER` — DragonflyDB operator & cluster
29. `STORY-SEC-NP-BASELINE` — Network Policy baseline
30. `STORY-SEC-SPIRE-CILIUM-AUTH` — SPIRE + Cilium authentication
31. `STORY-IDP-KEYCLOAK-OPERATOR` — Keycloak identity provider

#### 🔀 Parallel Options
- Draft ClusterMesh topology docs and pre‑checklists
- Identify tenant namespaces and baseline policies for Sprint 7

### 🕸️ Sprint 6 — Mesh & Apps Storage & CI/CD
**Jan 19 – Jan 30, 2026** | 2 weeks

#### ⭐ Critical Path
32. `STORY-NET-CILIUM-CLUSTERMESH` — Cilium ClusterMesh
33. `STORY-NET-CLUSTERMESH-DNS` — ClusterMesh DNS
34. `STORY-STO-APPS-OPENEBS-BASE` — OpenEBS for apps cluster
35. `STORY-STO-APPS-ROOK-CEPH-OPERATOR` — Rook-Ceph operator (apps)
36. `STORY-STO-APPS-ROOK-CEPH-CLUSTER` — Rook-Ceph cluster (apps)
37. `STORY-CICD-GITHUB-ARC` — GitHub Actions Runner Controller

#### 🔀 Parallel Options
- Prep GitLab (38) manifests and secrets in a non‑wired folder
- Draft Harbor (39) values and storage requirements

### 🔄 Sprint 7 — CI/CD (part 2), Registry, Tenancy, Backup
**Feb 2 – Feb 13, 2026** | 2 weeks

#### ⭐ Critical Path
38. `STORY-CICD-GITLAB-APPS` — GitLab on apps cluster
39. `STORY-APP-HARBOR` — Harbor container registry
40. `STORY-TENANCY-BASELINE` — Multi-tenant namespace baseline
41. `STORY-BACKUP-VOLSYNC-APPS` — Volsync backup for apps

#### 🔀 Parallel Options
- App team onboarding and sample pipelines
- Backup DR drill rehearsal plan (dry‑run)

---

## 🔀 Concurrency Notes (Safe Parallels)

| Scenario | Details |
|----------|---------|
| **Secrets + Reloader** | Stories 5, 6 can run parallel with CRD bootstrap (2) after initial Talos/Flux readiness (1, 4) |
| **DNS Stack** | Stories 11, 12, 13 benefit from Cilium Gateway (10) but CoreDNS (11) can begin once Cilium core (8) is Ready |
| **Observability Base** | Stories 17–19 can be staged on infra while storage (14–16) finishes, if ephemeral storage is acceptable; prefer to wait for storage Ready for persistence |
| **BGP Design** | Story 23 overlaps with obs implementation (20–22); avoid enabling BGP on prod until observability alerts are live |
| **DB Operator Prep** | Story 26 prep can overlap with Sprint 4; apply in Sprint 5 when storage and certs are stable |

---

## ✅ Go/No-Go Gates

| Sprint | Success Criteria |
|--------|------------------|
| **Sprint 1** | ✓ Flux + External Secrets healthy<br>✓ Bootstrap idempotent |
| **Sprint 2** | ✓ Public HTTPS via Gateway + certs<br>✓ External/internal DNS resolved correctly |
| **Sprint 3** | ✓ Persistent storage and base observability operational |
| **Sprint 4** | ✓ Alerts/metrics/logs validated<br>✓ BGP contained and stable |
| **Sprint 5** | ✓ DB platforms usable<br>✓ Baseline network policies enforced |
| **Sprint 6** | ✓ Mesh functional<br>✓ Apps storage ready<br>✓ ARC connected |
| **Sprint 7** | ✓ CI/CD + registry + tenancy + backups in place |

---

## 🔄 Change Management

### GitOps Principles

- ✅ **All implementations** occur via GitOps PRs with environment‑scoped Kustomizations and `postBuild` substitution
- 🏷️ **Story IDs** must be used in PR titles and commit messages for traceability
  - Example: `STORY-NET-CILIUM-GATEWAY: implement Gateway API routes`
- 🚫 **Do not wire** draft manifests into cluster Kustomizations until the owning story is approved

### Workflow

```mermaid
graph LR
    A[Story Approved] --> B[Create Branch]
    B --> C[Implement Changes]
    C --> D[Create PR with Story ID]
    D --> E[Review & Test]
    E --> F[Merge to Main]
    F --> G[Flux Auto-Deploy]
```

---

<div align="center">

**Generated**: October 2025
**Maintained By**: Platform Engineering Team
**Last Updated**: October 22, 2025

</div>

