# Data Classification Framework

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** ✅ Approved for Implementation
**Validation:** Infrastructure Validation - Security BLOCKER #3

---

## Executive Summary

This document defines the data classification framework for the multi-cluster Kubernetes platform. Data classification ensures appropriate security controls (encryption, access control, backup, audit logging) are applied based on sensitivity level, balancing security with operational efficiency.

---

## 🎯 Classification Objectives

### Primary Goals

1. **Risk-Based Security** - Apply controls proportionate to data sensitivity
2. **Compliance Readiness** - Framework extensible for future regulatory requirements
3. **Operational Efficiency** - Avoid over-securing low-risk data (performance impact)
4. **Clear Ownership** - Every dataset has a defined sensitivity level and owner
5. **Integration** - Classification drives RBAC, encryption, backup, and audit policies

### Classification Drives Security Controls

```
┌─────────────────────────────────────────────────────────────────┐
│ Data Classification                                              │
│   ↓                                                              │
│ ┌─────────────┬─────────────┬─────────────┬──────────────┐     │
│ │   Public    │  Internal   │ Confidential│  Restricted  │     │
│ └─────────────┴─────────────┴─────────────┴──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│ Security Controls                                                │
│ ┌──────────────┬───────────────┬────────────────┬────────────┐   │
│ │ Encryption   │ Access Control│ Backup Strategy│ Audit Level│   │
│ ├──────────────┼───────────────┼────────────────┼────────────┤   │
│ │ Optional     │ Authenticated │ Optional       │ None       │   │ Public
│ │ TLS only     │ Authenticated │ Standard (24h) │ Metadata   │   │ Internal
│ │ At-rest      │ RBAC required │ Encrypted (6h) │ Request    │   │ Confidential
│ │ At-rest+wire │ MFA + audit   │ Encrypted (1h) │ Request    │   │ Restricted
│ └──────────────┴───────────────┴────────────────┴────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📊 Classification Levels

### Level 0: Public

**Definition**: Data intended for public disclosure with no confidentiality requirements.

**Examples**:
- Public documentation (README.md, architecture diagrams)
- Open-source code repositories
- Public-facing website content
- Status page metrics (uptime, response times)

**Security Controls**:
| Control | Requirement | Implementation |
|---------|-------------|----------------|
| **Encryption at Rest** | Optional | Ceph encryption: disabled (performance) |
| **Encryption in Transit** | TLS for external | Cloudflare Tunnel |
| **Access Control** | Unauthenticated read allowed | Public endpoints |
| **Backup** | Optional | Standard backup, 7-day retention |
| **Audit Logging** | None | Not logged |
| **Retention** | Indefinite | No automatic deletion |

**RBAC**: Anonymous read access permitted
**Namespace Example**: None (no k8s workloads with public data)

---

### Level 1: Internal

**Definition**: Data for internal use within the organization. Low risk if disclosed, but not intended for public access.

**Examples**:
- Application logs (non-sensitive)
- Monitoring metrics (CPU, memory, network)
- Internal documentation
- Non-production configuration files
- Build artifacts and container images
- CI/CD pipeline logs

**Security Controls**:
| Control | Requirement | Implementation |
|---------|-------------|----------------|
| **Encryption at Rest** | Optional | Ceph encryption: disabled |
| **Encryption in Transit** | TLS (internal only) | Cilium: plaintext (trusted network) |
| **Access Control** | Authenticated users only | RBAC: developer role minimum |
| **Backup** | Standard (24h RPO) | VolSync: daily backups |
| **Audit Logging** | Metadata level | API access logged (who, when, what) |
| **Retention** | 90 days (logs), indefinite (config) | Victoria Logs auto-deletion |

**RBAC**: `developer` role (namespace-scoped read)
**Namespace Examples**: `monitoring`, `gitlab` (logs), `harbor` (images)

---

### Level 2: Confidential

**Definition**: Sensitive business data requiring protection from unauthorized disclosure. Moderate impact if compromised.

**Examples**:
- Database credentials (application passwords)
- API keys and tokens
- SSL/TLS certificates (private keys)
- Internal user data (email addresses, usernames)
- Source code (proprietary applications)
- Configuration with embedded secrets
- Backup encryption keys

**Security Controls**:
| Control | Requirement | Implementation |
|---------|-------------|----------------|
| **Encryption at Rest** | **REQUIRED** | Ceph encryption: RECOMMENDED (per-PVC) |
| **Encryption in Transit** | **REQUIRED** | Cilium WireGuard: RECOMMENDED |
| **Access Control** | RBAC with least privilege | Service accounts only, no human read access |
| **Backup** | Encrypted backups, 6h RPO | VolSync with Age encryption |
| **Audit Logging** | **REQUEST level** | Full request body logged |
| **Retention** | 90 days (compliance) | Encrypted backups, automatic rotation |

**RBAC**: No direct human access, service accounts via `ExternalSecret` only
**Namespace Examples**: `databases`, `external-secrets`, `cert-manager`

**CRITICAL**: All Kubernetes `Secret` resources are classified as **Confidential** by default.

---

### Level 3: Restricted

**Definition**: Highly sensitive data requiring maximum protection. Significant legal, financial, or reputational impact if compromised.

**Examples**:
- Master encryption keys (Talos secrets, cluster tokens)
- Root CA private keys
- 1Password Connect credentials
- Production database master passwords
- PII/PHI (if applicable in future)
- Financial records (if applicable)
- Legal documents (if applicable)

**Security Controls**:
| Control | Requirement | Implementation |
|---------|-------------|----------------|
| **Encryption at Rest** | **MANDATORY** | 1Password vault (AES-256) |
| **Encryption in Transit** | **MANDATORY** | TLS 1.3 minimum |
| **Access Control** | Break-glass only, time-bound | Emergency access with approval |
| **Backup** | Offline encrypted backups, 1h RPO | 1Password automated backups |
| **Audit Logging** | **REQUEST level + alerting** | Real-time AlertManager notifications |
| **Retention** | 1 year (legal hold) | Immutable storage (1Password) |

**RBAC**: No Kubernetes access. Stored externally in 1Password vault.
**Access**: Manual retrieval via `op` CLI with MFA
**Namespace Examples**: None (stored outside Kubernetes)

**CRITICAL**: Restricted data should **NEVER** exist as Kubernetes `Secret` resources.

---

## 🗂️ Data Inventory & Classification Map

### Infra Cluster Data Inventory

| Service | Data Type | Classification | Storage | Encryption | Backup RPO |
|---------|-----------|----------------|---------|------------|------------|
| **Talos Secrets** | Cluster tokens, CA keys | **Restricted** | 1Password | AES-256 | Real-time (1Password) |
| **FluxCD** | GitOps state, reconciliation data | Internal | etcd | None | Daily |
| **External Secrets** | Secret mappings (not secret data) | Internal | etcd | None | Daily |
| **cert-manager** | TLS certificate private keys | **Confidential** | etcd + Secret | etcd encryption | 6h |
| **Rook Ceph** | Storage metadata, OSD state | Internal | Ceph cluster | None | Daily |
| **Victoria Metrics** | Time-series metrics | Internal | Ceph block (vmcluster) | None | None (ephemeral) |
| **Victoria Logs** | Application + audit logs | Internal/**Confidential** | Ceph block | Optional | 6h |
| **CloudNativePG** | PostgreSQL database data | **Confidential** | Ceph block | **RECOMMENDED** | 6h |
| **Dragonfly** | Redis cache data | Internal | Memory (ephemeral) | None | None (cache) |
| **1Password Connect** | Cached secrets | **Confidential** | Memory only | TLS in transit | None (sync from 1Password) |
| **Keycloak** | User accounts, auth sessions | **Confidential** | PostgreSQL | Via CNPG | 6h |

---

### Apps Cluster Data Inventory

| Service | Data Type | Classification | Storage | Encryption | Backup RPO |
|---------|-----------|----------------|---------|------------|------------|
| **GitLab** | Git repositories, CI/CD artifacts | **Confidential** | Ceph block + PostgreSQL | **RECOMMENDED** | 6h |
| **GitLab Database** | User data, project metadata | **Confidential** | CNPG (infra cluster) | Via ClusterMesh | 6h |
| **Harbor** | Container images, scan results | Internal | Ceph block + PostgreSQL | None | Daily |
| **Mattermost** | Chat messages, file uploads | Internal/**Confidential** | PostgreSQL + S3 | Optional | 6h |
| **Cilium** | Network policies, ClusterMesh state | Internal | etcd | None | Daily |

---

### Namespace-Level Classification

| Namespace | Primary Classification | Rationale | Key Security Controls |
|-----------|------------------------|-----------|----------------------|
| `flux-system` | Internal | GitOps state, non-sensitive | RBAC: platform-admin only |
| `external-secrets` | **Confidential** | Secret mapping (indirect access) | Audit: Request level |
| `cert-manager` | **Confidential** | TLS private keys | etcd encryption, 6h backup |
| `rook-ceph` | Internal | Storage infrastructure | RBAC: platform-admin only |
| `monitoring` | Internal | Metrics and logs | Victoria Logs access control |
| `databases` | **Confidential** | PostgreSQL clusters | **Encryption recommended**, 6h backup |
| `kube-system` | **Confidential** | Core cluster components | Minimal access, audit logging |
| `gitlab` | **Confidential** | Source code, credentials | Encryption recommended, 6h backup |
| `harbor` | Internal | Container images | Standard backup |
| `mattermost` | Internal/**Confidential** | Team communications | Optional encryption |

**Default Classification**: All new namespaces default to **Internal** unless explicitly classified higher.

---

## 🔐 Security Controls by Classification

### Encryption Requirements

| Classification | At-Rest Encryption | In-Transit Encryption | Key Management |
|----------------|-------------------|----------------------|----------------|
| Public | Optional | TLS (external only) | N/A |
| Internal | Optional | TLS (external only) | N/A |
| **Confidential** | **Recommended** | TLS + optional WireGuard | 1Password or etcd encryption |
| **Restricted** | **Mandatory** | TLS 1.3 minimum | 1Password vault (offline backup) |

**Implementation Notes**:
- **At-rest encryption**: Rook Ceph per-PVC encryption for Confidential data
- **In-transit encryption**: Cilium WireGuard for ClusterMesh (Confidential cross-cluster traffic)
- **etcd encryption**: Kubernetes Secrets encrypted at rest (Confidential minimum)

---

### Access Control Requirements

| Classification | RBAC Level | Service Account | Human Access | MFA Required |
|----------------|-----------|----------------|--------------|--------------|
| Public | Unauthenticated | Not applicable | Allowed | No |
| Internal | Developer role | Read-only SA | Read allowed | No |
| **Confidential** | Restricted SA | Write via ExternalSecret | No direct access | Yes (via 1Password) |
| **Restricted** | No k8s access | Not in k8s | Break-glass only | **Yes (mandatory)** |

**Implementation**:
- Internal: `developer` Role (namespace-scoped)
- Confidential: Service accounts only, humans access via 1Password → ExternalSecret
- Restricted: 1Password CLI with MFA (`op` command)

---

### Backup Requirements

| Classification | RPO | Retention | Encryption | Storage Location |
|----------------|-----|-----------|------------|------------------|
| Public | 7 days | 30 days | No | Synology NAS (MinIO) |
| Internal | 24 hours | 30 days | No | Synology NAS (MinIO) |
| **Confidential** | **6 hours** | **90 days** | **Yes (Age)** | Synology NAS (encrypted) |
| **Restricted** | 1 hour | 1 year | Yes (AES-256) | 1Password vault |

**Implementation**:
- VolSync: Restic backups with Age encryption for Confidential
- 1Password: Native encrypted backups for Restricted
- Velero: Weekly cluster-wide backups (Internal retention)

---

### Audit Logging Requirements

| Classification | Audit Level | Retention | Real-Time Alerts | Compliance Reporting |
|----------------|-------------|-----------|------------------|----------------------|
| Public | None | N/A | No | No |
| Internal | Metadata | 90 days | No | Optional |
| **Confidential** | **Request** | **90 days** | **Yes** | **Yes** |
| **Restricted** | **Request + alerting** | **1 year** | **Yes (immediate)** | **Yes (mandatory)** |

**Implementation**:
- Kubernetes audit policy: Request level for Secrets, RBAC
- Victoria Logs: 90-day retention
- AlertManager: Real-time alerts for Confidential/Restricted access

---

## 📝 Data Handling Procedures

### Procedure 1: Creating New Namespaces

```bash
# 1. Determine data classification
# What is the most sensitive data this namespace will handle?

# 2. Apply namespace label
kubectl create namespace my-app
kubectl label namespace my-app \
  monosense.io/data-classification=confidential \
  monosense.io/backup-required=true \
  monosense.io/encryption-required=true

# 3. Create RBAC from template
cp kubernetes/bases/rbac/developer-role-template.yaml \
   kubernetes/workloads/my-app/rbac/developer-role.yaml
sed -i 's/<NAMESPACE>/my-app/g' kubernetes/workloads/my-app/rbac/developer-role.yaml

# 4. Configure backup per classification
# Confidential: 6h RPO, Age encryption
# See: kubernetes/components/volsync/

# 5. Document in data inventory
# Add row to this document under "Data Inventory & Classification Map"
```

---

### Procedure 2: Handling Secrets (Confidential)

```bash
# ❌ NEVER create Kubernetes Secrets directly
# kubectl create secret generic my-secret --from-literal=key=value

# ✅ ALWAYS use 1Password + External Secrets
# 1. Store secret in 1Password
op item create \
  --category=password \
  --title="my-app-credentials" \
  --vault="Prod" \
  password="$(openssl rand -base64 32)"

# 2. Create ExternalSecret manifest
cat <<EOF > kubernetes/workloads/my-app/secrets/externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-credentials
  namespace: my-app
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: my-app-credentials
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: my-app-credentials
EOF

# 3. Commit to Git (no secrets in Git!)
git add kubernetes/workloads/my-app/secrets/externalsecret.yaml
git commit -m "feat(my-app): add secret sync from 1Password"
```

---

### Procedure 3: Accessing Restricted Data (Break-Glass)

```bash
# Restricted data (Talos secrets, root CA keys) requires break-glass access

# 1. Create incident ticket
# Document reason for access

# 2. Authenticate with MFA
op signin

# 3. Retrieve secret
op item get "prod-talos" --vault="Prod" --format=json

# 4. Use for intended purpose (e.g., emergency cluster recovery)

# 5. Audit log review
# Access automatically logged in 1Password activity log

# 6. Document in incident postmortem
```

---

### Procedure 4: Data Classification Review (Quarterly)

```bash
# Every 90 days, review data classification

# 1. Review namespace labels
kubectl get namespaces -L monosense.io/data-classification

# 2. Verify encryption status
kubectl get pvc -A -o json | \
  jq '.items[] | select(.metadata.annotations["encrypted"]=="true") | .metadata.name'

# 3. Audit backup configurations
kubectl get replicationsources -A

# 4. Review access logs for Confidential data
# Query Victoria Logs for Secret access

# 5. Update classification if needed
kubectl label namespace my-app monosense.io/data-classification=confidential --overwrite

# 6. Document changes in this file
```

---

## 🚨 Data Breach Response

### Classification-Specific Response

| Classification | Response Time | Notification Required | Remediation |
|----------------|---------------|----------------------|-------------|
| Public | None | No | No action |
| Internal | 7 days | No | Rotate credentials (optional) |
| **Confidential** | **24 hours** | **Platform team** | **Immediate key rotation** |
| **Restricted** | **1 hour** | **All stakeholders** | **Emergency lockdown + rotation** |

### Breach Response Procedure

```bash
# 1. Identify compromised data classification level
CLASSIFICATION="confidential"  # or restricted

# 2. Isolate affected namespace (Confidential/Restricted only)
kubectl cordon <node-with-breach>
kubectl delete pod <compromised-pod> -n <namespace>

# 3. Rotate all credentials immediately
# For Confidential: Regenerate in 1Password
op item edit <item-id> --generate-password

# For Restricted: Full cluster certificate rotation
talosctl gen secrets -o /tmp/new-secrets.yaml

# 4. Review audit logs
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | namespace="<namespace>" | last 24h'

# 5. Document incident
# Create post-mortem in docs/incidents/

# 6. Implement preventive measures
# Update network policies, RBAC, or reclassify data
```

---

## 📋 Implementation Checklist

### Phase 1: Documentation & Labeling
- [x] Define classification levels (Public, Internal, Confidential, Restricted)
- [x] Create data inventory for all services
- [x] Document security controls per classification
- [ ] Label all namespaces with `monosense.io/data-classification`
- [ ] Document data handling procedures
- [ ] Create classification decision tree

### Phase 2: Technical Controls
- [ ] Enable etcd encryption for Kubernetes Secrets (Confidential minimum)
- [ ] Configure Rook Ceph per-PVC encryption for Confidential data
- [ ] Enable Cilium WireGuard for cross-cluster Confidential traffic
- [ ] Configure VolSync with Age encryption (Confidential backups)
- [ ] Create AlertManager rules for Confidential data access
- [ ] Verify audit logging captures Confidential operations

### Phase 3: Process & Training
- [ ] Schedule quarterly data classification review
- [ ] Document break-glass access procedures
- [ ] Create incident response runbooks per classification
- [ ] Train platform team on classification framework
- [ ] Integrate classification into namespace creation workflow

---

## 🔗 Integration with Other Security Controls

### RBAC Integration (BLOCKER #1)

```yaml
# Namespace RBAC inherits from data classification
apiVersion: v1
kind: Namespace
metadata:
  name: my-confidential-app
  labels:
    monosense.io/data-classification: confidential
---
# Automatically restrict to service accounts (no human access)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: restrict-human-access
  namespace: my-confidential-app
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
  # Only service accounts, no User or Group subjects
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-confidential-app
```

### Audit Logging Integration (BLOCKER #2)

Audit policy rules map directly to classification:

- **Public**: `level: None`
- **Internal**: `level: Metadata`
- **Confidential**: `level: Request`
- **Restricted**: `level: Request` + AlertManager

Implemented in `talos/machineconfig.yaml.j2` lines 143-166.

---

## 🔍 Compliance & Auditing

### Classification Compliance Report

```bash
# Generate compliance report
cat <<'EOF' > /tmp/classification-audit.sh
#!/bin/bash
echo "=== Data Classification Compliance Report ==="
echo "Date: $(date)"
echo ""

echo "1. Namespace Classification Labels:"
kubectl get namespaces -L monosense.io/data-classification -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.metadata.labels["monosense.io/data-classification"] // "UNCLASSIFIED")"'
echo ""

echo "2. Confidential Namespaces Backup Status:"
kubectl get replicationsources -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.spec.restic.repository)"'
echo ""

echo "3. Secret Access Audit (Last 7 days):"
curl -s 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource="secrets" | last 7d | stats count() by user.username' | \
  jq .
EOF

chmod +x /tmp/classification-audit.sh
/tmp/classification-audit.sh
```

---

## 🎓 Classification Decision Tree

```
START: What type of data is this?
  │
  ├─ Can it be public? (website, docs)
  │   └─> PUBLIC
  │
  ├─ Is it sensitive if disclosed?
  │   NO ──> INTERNAL (logs, metrics, configs)
  │   │
  │   YES ──> Is it a credential, key, or password?
  │            │
  │            YES ──> CONFIDENTIAL (secrets, certs, API keys)
  │            │
  │            NO ──> Is it critical infrastructure?
  │                    │
  │                    YES ──> RESTRICTED (root CAs, cluster tokens)
  │                    │
  │                    NO ──> CONFIDENTIAL (default for sensitive data)
```

---

## 📚 Related Documentation

- **RBAC Security Model**: [docs/security/rbac-model.md](./rbac-model.md) - BLOCKER #1
- **Talos Audit Logging**: [docs/security/talos-audit-policy.md](./talos-audit-policy.md) - BLOCKER #2
- **Architecture Decision Record**: [docs/architecture-decision-record.md](../architecture-decision-record.md)
- **External Secrets Setup**: [kubernetes/infrastructure/security/external-secrets/](../../kubernetes/infrastructure/security/external-secrets/)

---

**Status**: ✅ Ready for Implementation
**Next Action**: Label namespaces and configure encryption per classification
**Owner**: Platform Team
**Review Date**: Quarterly (next: 2026-01-14)
