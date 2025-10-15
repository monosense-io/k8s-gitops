# Data Classification Quick Reference

**Quick decision guide for data classification**
**Security BLOCKER #3 - Implementation Reference**

---

## 🚦 Quick Classification Guide

| Ask Yourself | Classification | Example |
|--------------|----------------|---------|
| "Can anyone see this?" | **Public** | README, status page |
| "Is it just internal tooling?" | **Internal** | Logs, metrics, configs |
| "Is it a password or key?" | **Confidential** | Secrets, certificates |
| "Would losing this destroy the cluster?" | **Restricted** | Root CA, Talos tokens |

---

## 📋 Classification Matrix

| Data Type | Classification | Encryption | Backup RPO | Audit Level |
|-----------|----------------|------------|------------|-------------|
| Logs, metrics | Internal | None | 24h | Metadata |
| Container images | Internal | None | 24h | Metadata |
| App configs (no secrets) | Internal | None | 24h | Metadata |
| **Kubernetes Secrets** | **Confidential** | **Recommended** | **6h** | **Request** |
| Database credentials | **Confidential** | **Recommended** | **6h** | **Request** |
| TLS private keys | **Confidential** | **Required** | **6h** | **Request** |
| **Cluster CA keys** | **Restricted** | **Mandatory** | **1h** | **Request + Alert** |
| **Talos secrets** | **Restricted** | **Mandatory** | **Real-time** | **Request + Alert** |

---

## ⚡ Quick Actions

### Label a Namespace

```bash
# Internal (default)
kubectl label namespace my-app \
  monosense.io/data-classification=internal

# Confidential
kubectl label namespace databases \
  monosense.io/data-classification=confidential \
  monosense.io/encryption-required=true \
  monosense.io/backup-required=true
```

### Create a Secret (Confidential)

```bash
# 1. Store in 1Password
op item create --vault=Prod --title=my-secret password="$(openssl rand -base64 32)"

# 2. Create ExternalSecret
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-app
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: my-secret
  dataFrom:
    - extract:
        key: my-secret
EOF
```

### Audit Confidential Access

```bash
# Last 24h Secret access
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource="secrets" | last 24h'
```

---

## 🔐 Security Control Summary

| Classification | Encryption | RBAC | Backup | Audit |
|----------------|-----------|------|--------|-------|
| Public | ❌ No | 🌐 Anonymous | Optional | ❌ None |
| Internal | ❌ No | 👤 Developer | Standard | 📝 Metadata |
| **Confidential** | ✅ **Recommended** | 🤖 **SA only** | **Encrypted** | 📋 **Request** |
| **Restricted** | ✅ **Mandatory** | 🚨 **Break-glass** | **Offline** | 🚨 **Alert** |

---

## 🚨 Red Flags

### ❌ DON'T DO THIS

```bash
# NEVER store secrets directly in Kubernetes
kubectl create secret generic bad-idea --from-literal=password=hunter2

# NEVER commit secrets to Git
echo "password: hunter2" > config.yaml
git add config.yaml  # ❌ BAD!

# NEVER use plaintext secrets in manifests
password: "hunter2"  # ❌ Visible in audit logs!
```

### ✅ DO THIS INSTEAD

```bash
# Store secrets in 1Password
op item create --vault=Prod --title=app-password password="$(pwgen 32 1)"

# Reference via ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-password
spec:
  secretStoreRef:
    name: onepassword
  dataFrom:
    - extract:
        key: app-password
```

---

## 📞 Decision Flowchart

```
Is this data a credential/key/password?
├─ YES ──> CONFIDENTIAL (minimum)
│          └─ Is it a root/cluster key?
│             └─ YES ──> RESTRICTED
│
└─ NO ──> Would disclosure cause harm?
   ├─ YES ──> CONFIDENTIAL
   └─ NO ──> Can it be public?
      ├─ YES ──> PUBLIC
      └─ NO ──> INTERNAL
```

---

## 🔗 Full Documentation

[Complete Data Classification Framework →](./data-classification.md)

---

**Quick Tip**: When in doubt, classify higher. It's easier to downgrade than upgrade.
