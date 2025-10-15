# Implementation Timeline

**Project:** Multi-Cluster Kubernetes Platform
**Timeline:** 10 weeks (70 days)
**Based on:** Architecture Decision Record v1.0
**Start Date:** TBD

---

## Phase Overview

```
Week 1-2:  Foundation (Talos, Flux, Cilium)
Week 3-4:  Storage & Backup (Rook Ceph, VolSync, Velero)
Week 5-6:  Platform Services (Databases, Auth, Monitoring)
Week 7-8:  Security Hardening & CI/CD
Week 9-10: Applications & Validation
```

---

## Week 1-2: Foundation

### Week 1: Infra Cluster Bootstrap

#### Day 1-2: Talos Installation
- [ ] Download Talos 1.11.2 ISO
- [ ] Create Talos schematic with system extensions
- [ ] Install Talos on infra nodes (10.25.11.11-13)
- [ ] Apply Talos machine configs
- [ ] Verify cluster formation
- [ ] Configure kubectl access

**Commands:**
```bash
# Generate Talos configs
talosctl gen config infra https://10.25.11.11:6443 \
  --with-cluster-discovery \
  --config-patch @talos/patches/infra-cluster.yaml

# Apply to nodes
talosctl apply-config --nodes 10.25.11.11 --file talos/controlplane/10.25.11.11.yaml
talosctl apply-config --nodes 10.25.11.12 --file talos/controlplane/10.25.11.12.yaml
talosctl apply-config --nodes 10.25.11.13 --file talos/controlplane/10.25.11.13.yaml

# Wait for cluster ready
talosctl health --nodes 10.25.11.11

# Get kubeconfig
talosctl kubeconfig --nodes 10.25.11.11
```

#### Day 3-4: Cilium CNI
- [ ] Deploy Cilium 1.18+ with BGP control plane
- [ ] Configure LB IPAM pools
- [ ] Configure BGP peering with Juniper SRX320
- [ ] Enable ClusterMesh (prepare for multi-cluster)
- [ ] Verify pod networking

**Implementation:**
```bash
# Bootstrap Flux (will install Cilium)
flux bootstrap github \
  --owner=<your-org> \
  --repository=k8s-gitops \
  --branch=main \
  --path=clusters/infra \
  --personal

# Verify Cilium
cilium status --wait
cilium connectivity test
```

#### Day 5-7: Flux GitOps
- [ ] Create Git repository structure
- [ ] Bootstrap Flux on infra cluster
- [ ] Configure Git repository sync
- [ ] Create Kustomization layers (CRDs, Operators, etc.)
- [ ] Test Flux reconciliation

---

### Week 2: Apps Cluster Bootstrap

#### Day 8-9: Talos Installation
- [ ] Install Talos on apps nodes (10.25.11.14-16)
- [ ] Apply Talos machine configs (different PodCIDR!)
- [ ] Verify cluster formation
- [ ] Configure kubectl access (separate context)

#### Day 10-11: Cilium CNI
- [ ] Deploy Cilium with different cluster ID (id: 2)
- [ ] Configure LB IPAM pools (different range)
- [ ] Configure BGP peering with SRX320
- [ ] Enable ClusterMesh

#### Day 12-14: Flux GitOps + ClusterMesh
- [ ] Bootstrap Flux on apps cluster
- [ ] Connect ClusterMesh (infra ↔ apps)
- [ ] Verify cross-cluster connectivity
- [ ] Test global service

**ClusterMesh Verification:**
```bash
# Enable ClusterMesh on both clusters
cilium clustermesh enable --context infra
cilium clustermesh enable --context apps

# Connect clusters
cilium clustermesh connect --context infra --destination-context apps

# Verify
cilium clustermesh status --context infra
cilium clustermesh status --context apps

# Test connectivity
cilium connectivity test --context infra --multi-cluster apps
```

---

## Week 3-4: Storage & Backup

### Week 3: Rook Ceph Deployment

#### Day 15-16: Rook Operator
- [ ] Deploy Rook CRDs (Layer 0)
- [ ] Deploy Rook Ceph Operator (Layer 1)
- [ ] Verify operator readiness

#### Day 17-19: Ceph Cluster
- [ ] Deploy CephCluster (3 OSDs on infra nodes)
- [ ] Wait for Ceph cluster HEALTH_OK (can take 20-30 min)
- [ ] Create CephBlockPool (replicapool)
- [ ] Create StorageClasses (ceph-block, VolumeSnapshotClass)
- [ ] Test PVC creation and mounting

**Validation:**
```bash
# Check Ceph cluster status
kubectl -n rook-ceph get cephcluster
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# Test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-block
EOF

kubectl get pvc test-pvc --watch
```

#### Day 20-21: OpenEBS LocalPV
- [ ] Deploy OpenEBS Operator
- [ ] Configure local-hostpath StorageClass
- [ ] Test PVC creation

---

### Week 4: Backup Infrastructure

#### Day 22-24: VolSync (ADR-006)
- [ ] Deploy VolSync Operator
- [ ] Configure MinIO S3 credentials (1Password → External Secret)
- [ ] Create test ReplicationSource
- [ ] Create test ReplicationDestination
- [ ] Verify backup to MinIO
- [ ] Verify restore from MinIO

**VolSync Test:**
```bash
# Create test PVC with data
kubectl apply -f test-pvc-with-data.yaml

# Create ReplicationSource (backup)
kubectl apply -f volsync/test/replicationsource.yaml

# Wait for backup completion
kubectl get replicationsource -A --watch

# Check MinIO for backup
mc ls minio/volsync/test-backup

# Create ReplicationDestination (restore)
kubectl apply -f volsync/test/replicationdestination.yaml

# Verify restored data
```

#### Day 25-28: Velero (ADR-004)
- [ ] Deploy Velero with Restic node agent
- [ ] Configure MinIO as backup location
- [ ] Configure CSI snapshot location
- [ ] Create backup schedule (weekly)
- [ ] Test backup creation
- [ ] Test restore (dry-run)

**Velero Test:**
```bash
# Create test backup
velero backup create test-backup --include-namespaces default

# Check backup status
velero backup describe test-backup

# Test restore (dry-run)
velero restore create test-restore --from-backup test-backup --dry-run

# Verify backup in MinIO
mc ls minio/velero-backups/backups/test-backup
```

---

## Week 5-6: Platform Services

### Week 5: Core Platform Services

#### Day 29-31: Cert-Manager & External Secrets
- [ ] Deploy cert-manager operator
- [ ] Create ClusterIssuers (Let's Encrypt prod/staging)
- [ ] Test certificate issuance
- [ ] Deploy external-secrets operator
- [ ] Configure 1Password Connect connection
- [ ] Create ClusterSecretStore
- [ ] Test secret synchronization

**External Secrets Test:**
```bash
# Create test ExternalSecret
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: test-secret
  data:
    - secretKey: password
      remoteRef:
        key: test-item
        property: password
EOF

# Verify secret created
kubectl get secret test-secret -o yaml
```

#### Day 32-35: PostgreSQL (ADR-001)
- [ ] Deploy CloudNativePG Operator
- [ ] Create PostgreSQL cluster (3 replicas)
- [ ] Configure backups to MinIO (via VolSync)
- [ ] Test failover
- [ ] Create database for Keycloak
- [ ] Test connection from apps cluster (ClusterMesh)

**PostgreSQL Validation:**
```bash
# Check cluster status
kubectl -n databases get cluster postgres

# Test connection from apps cluster
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never \
  --context apps -- psql -h postgres-rw.databases.svc.infra.local -U postgres

# Test failover
kubectl -n databases delete pod postgres-1
# Verify automatic failover and recovery
```

---

### Week 6: Observability & Authentication

#### Day 36-39: Victoria Metrics (ADR-001)
- [ ] Deploy Victoria Metrics Operator
- [ ] Deploy VMCluster on infra (3 VMStorage, 2 VMInsert, 2 VMSelect)
- [ ] Deploy VMAgent on infra (scrape infra cluster)
- [ ] Deploy VMAgent on apps (remote-write to infra)
- [ ] Deploy VMAlert and Alertmanager
- [ ] Configure Grafana
- [ ] Create dashboards (Ceph, Cilium, Kubernetes)
- [ ] Test cross-cluster metrics

**Metrics Validation:**
```bash
# Check VMCluster health
kubectl -n monitoring get vmcluster

# Query from VMSelect
curl -s 'http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus/api/v1/query?query=up'

# Verify apps cluster metrics in infra
# Query should show cluster="apps" labels
curl -s 'http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus/api/v1/query?query=up{cluster="apps"}'
```

#### Day 40-42: Victoria Logs & Fluent-bit
- [ ] Deploy Victoria Logs
- [ ] Deploy Fluent-bit on infra cluster
- [ ] Deploy Fluent-bit on apps cluster (forward to infra)
- [ ] Configure log retention
- [ ] Test log queries

#### Day 41-42: Keycloak (ADR-012)
- [ ] Deploy Keycloak on infra cluster
- [ ] Configure PostgreSQL backend
- [ ] Create initial realm and admin user
- [ ] Configure OIDC clients (Grafana, Hubble)
- [ ] Test SSO login to Grafana

---

## Week 7-8: Security & CI/CD

### Week 7: Security Hardening

#### Day 43-45: Network Policy Analysis (ADR-005)
- [ ] Export Hubble flow logs (Weeks 1-6 data)
- [ ] Analyze inter-namespace communication
- [ ] Document required connections
- [ ] Draft network policy YAMLs
- [ ] Review policies for completeness

**Hubble Analysis:**
```bash
# Export flows
hubble observe --since 1440h --output json > flows-6weeks.json

# Analyze top connections
hubble observe --since 1440h --from-namespace databases --to-namespace monitoring

# Generate policy recommendations
# (manual analysis of flows.json)
```

#### Day 46-49: Network Policy Implementation
- [ ] Create namespace-level default deny policies
- [ ] Create explicit allow policies per app
- [ ] Test policies in audit mode
- [ ] Enable enforcement
- [ ] Verify no broken services

#### Day 48-49: Pod Security Standards (ADR-007)
- [ ] Configure Pod Security Admission (audit mode)
- [ ] Review violations
- [ ] Document exemptions (kube-system, rook-ceph)
- [ ] Plan remediation for applications

---

### Week 8: CI/CD & Cloudflare Tunnel

#### Day 50-52: GitHub Actions Runners (ADR-009)
- [ ] Deploy actions-runner-controller on infra
- [ ] Create runner deployment (2 replicas)
- [ ] Configure GitHub App or PAT
- [ ] Test workflow execution
- [ ] Configure resource limits

**Runner Test:**
```yaml
# .github/workflows/test-runner.yaml
name: Test Self-Hosted Runner
on: push
jobs:
  test:
    runs-on: self-hosted
    steps:
      - run: echo "Running on self-hosted runner"
      - run: kubectl version
```

#### Day 53-56: Cloudflare Tunnel (ADR-002, ADR-011)
- [ ] Create Cloudflare Tunnels (infra-tunnel, apps-tunnel)
- [ ] Store tunnel credentials in 1Password
- [ ] Deploy cloudflared on infra cluster
- [ ] Deploy cloudflared on apps cluster
- [ ] Configure DNS routes
- [ ] Test external access (Grafana, apps)

**Cloudflare Tunnel Setup:**
```bash
# Create tunnels
cloudflared tunnel create k8s-infra-tunnel
cloudflared tunnel create k8s-apps-tunnel

# Store credentials in 1Password
# Copy tunnel credentials JSON to 1Password

# Configure routes
cloudflared tunnel route dns k8s-infra-tunnel grafana.monosense.io
cloudflared tunnel route dns k8s-apps-tunnel app1.monosense.io

# Test
curl https://grafana.monosense.io
```

#### Day 53-56: External DNS (ADR-013)
- [ ] Deploy external-dns on both clusters
- [ ] Configure Cloudflare provider
- [ ] Test automatic DNS record creation
- [ ] Verify LoadBalancer IP registration

---

## Week 9-10: Applications & Validation

### Week 9: Application Deployment

#### Day 57-59: Deploy Sample Applications
- [ ] Create application namespace
- [ ] Deploy test application with PVC
- [ ] Configure ingress/gateway
- [ ] Test external access via Cloudflare Tunnel
- [ ] Verify database connectivity (cross-cluster)
- [ ] Verify monitoring (metrics, logs)

#### Day 60-63: Monitoring & Alerting
- [ ] Configure Grafana dashboards
- [ ] Configure alert rules (VMAlert)
- [ ] Test alerting (trigger test alert)
- [ ] Configure notification channels
- [ ] Create Prometheus recording rules

**Key Dashboards:**
```
- Cluster Overview (CPU, RAM, Disk)
- Ceph Cluster Health
- Cilium Network Stats
- Victoria Metrics Performance
- Application Metrics (per namespace)
```

---

### Week 10: Validation & Hardening

#### Day 64-66: Disaster Recovery Testing (ADR-019)
- [ ] Test single PVC restore (VolSync)
- [ ] Test single node reboot
- [ ] Verify automatic recovery
- [ ] Test ClusterMesh resilience
- [ ] Document DR procedures

**DR Tests:**
```bash
# Test 1: PVC restore
# Create test PVC with data, backup, delete PVC, restore from backup

# Test 2: Node reboot
kubectl drain prod-01 --ignore-daemonsets --delete-emptydir-data
talosctl reboot --nodes 10.25.11.11
# Verify automatic recovery

# Test 3: ClusterMesh resilience
# Stop cloudflared on one cluster, verify cross-cluster services still work
```

#### Day 67-69: Pod Security Baseline Enforcement (ADR-007)
- [ ] Enable baseline enforcement for app namespaces
- [ ] Review and remediate violations
- [ ] Verify no broken deployments
- [ ] Document exemptions

#### Day 70: Final Validation & Documentation
- [ ] Verify all services operational
- [ ] Run connectivity tests (Cilium, ClusterMesh)
- [ ] Verify monitoring and alerting
- [ ] Verify backups running (VolSync, Velero)
- [ ] Update documentation with actual configs
- [ ] Create runbooks for common operations
- [ ] Platform handoff / go-live decision

---

## Success Criteria Checklist

### Infrastructure
- [ ] Both clusters operational (infra + apps)
- [ ] Talos 1.11.2 on all 6 nodes
- [ ] Cilium 1.18+ with BGP functional
- [ ] ClusterMesh connected (infra ↔ apps)
- [ ] BGP peering with Juniper SRX320

### Storage
- [ ] Rook Ceph cluster HEALTH_OK
- [ ] 3 OSDs operational (1TB each)
- [ ] ceph-block StorageClass working
- [ ] OpenEBS local-hostpath working
- [ ] VolumeSnapshot support enabled

### Backup
- [ ] VolSync backing up to MinIO (6-hour RPO)
- [ ] Velero weekly backups configured
- [ ] Successful restore test completed
- [ ] Backup retention policies configured

### Platform Services
- [ ] PostgreSQL cluster operational
- [ ] Databases accessible from apps cluster
- [ ] Cert-manager issuing certificates
- [ ] External Secrets syncing from 1Password
- [ ] Keycloak SSO functional

### Observability
- [ ] Victoria Metrics collecting from both clusters
- [ ] Grafana accessible via Cloudflare Tunnel
- [ ] Logs flowing to Victoria Logs
- [ ] Alert rules configured and tested
- [ ] Dashboards created for key services

### Security
- [ ] Cloudflare Tunnels operational (zero-trust access)
- [ ] Network policies enforced (Week 8+)
- [ ] Pod Security baseline enforced (Week 9+)
- [ ] Secrets managed via External Secrets
- [ ] RBAC configured appropriately

### CI/CD
- [ ] GitHub Actions runners operational
- [ ] Flux reconciling from Git
- [ ] Renovate creating update PRs
- [ ] External DNS managing records

### Operations
- [ ] DR testing procedures documented
- [ ] Runbooks created for common tasks
- [ ] Monitoring dashboards functional
- [ ] Alert notification channels configured
- [ ] Secret rotation schedule defined

---

## Post-Implementation Tasks

### Month 2 (Weeks 11-14)
- [ ] Monitor resource usage patterns (for ADR-020 quotas)
- [ ] Fine-tune Ceph performance
- [ ] Optimize Victoria Metrics retention
- [ ] Review and adjust alert thresholds
- [ ] First quarterly secret rotation (ADR-014)

### Month 3 (Weeks 15-18)
- [ ] Implement resource quotas (ADR-020)
- [ ] Enforce Pod Security "restricted" for apps (ADR-007)
- [ ] First quarterly DR test
- [ ] Review and optimize costs
- [ ] Add CephFS if needed (ADR-015)

### Month 4+ (Future)
- [ ] Evaluate self-hosted GitLab/Harbor (ADR-003)
- [ ] Consider staging cluster if needed
- [ ] Add more applications
- [ ] Implement automated Talos/K8s upgrades (optional)
- [ ] Expand cluster if needed

---

## Risk Mitigation

### High-Risk Activities
| Activity | Risk | Mitigation |
|----------|------|------------|
| ClusterMesh connection | Misconfiguration breaks networking | Test thoroughly, have rollback plan |
| Network policy enforcement | Broken services | Audit mode first, test each policy |
| Ceph OSD deployment | Data loss if misconfigured | Verify device paths, test on single node first |
| Velero restore | Data corruption | Always test restore in separate namespace first |
| Talos upgrades | Cluster unavailable | Rolling upgrade, test on apps cluster first |

### Rollback Procedures
```bash
# Flux Kustomization rollback
flux suspend kustomization <name>
git revert <commit-hash>
git push
flux resume kustomization <name>

# Manual rollback (emergency)
kubectl delete -k ./path/to/kustomization
kubectl apply -f ./backup/previous-config.yaml
```

---

## Daily Standup Template

```markdown
## Date: YYYY-MM-DD

### Completed Yesterday
- [ ] Task 1
- [ ] Task 2

### Today's Plan
- [ ] Task 1 (estimated time)
- [ ] Task 2 (estimated time)

### Blockers
- None / [describe blocker]

### Notes
- [Any observations or decisions]
```

---

## Contact & Escalation

### Resources
- FluxCD Slack: https://cloud-native.slack.com/messages/flux
- Cilium Slack: https://cilium.slack.com
- Rook Slack: https://rook.slack.com
- Kubernetes @ Home Discord: https://discord.gg/k8s-at-home

### Documentation
- [Architecture Decision Record](./architecture-decision-record.md)
- [Brainstorming Session Results](./brainstorming-session-results.md)
- [Technical Deep Dive](./technical-deep-dive.md)

---

*Implementation Timeline - Version 1.0*
*Based on Architecture Decision Record v1.0*
*Last Updated: 2025-10-14*
