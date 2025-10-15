# RBAC Base Manifests

**Purpose**: Base ClusterRoles for platform-wide access control
**Validation**: Security BLOCKER #1 - RBAC Model
**Documentation**: [RBAC Security Model](../../../docs/security/rbac-model.md)

---

## 📁 Files

| File | Purpose | Scope |
|------|---------|-------|
| `platform-admin-clusterrole.yaml` | Platform engineering team cluster-wide read + infra namespace write | ClusterRole |
| `monitoring-reader-clusterrole.yaml` | Monitoring tools cluster-wide read-only for metrics | ClusterRole |
| `view-no-secrets-clusterrole.yaml` | Auditors read-only access excluding secrets | ClusterRole |
| `developer-role-template.yaml` | **Template**: Per-namespace developer access | Role (copy to namespace) |
| `cicd-deployer-template.yaml` | **Template**: Per-namespace CI/CD automation | Role + ServiceAccount (copy to namespace) |

---

## 🚀 Quick Start

### 1. Deploy Base ClusterRoles

```bash
# ClusterRoles are automatically deployed via Flux
flux reconcile kustomization infrastructure -n flux-system
```

### 2. Add Platform Admin Users

Edit `kubernetes/infrastructure/security/rbac/platform-admin-bindings.yaml`:

```yaml
subjects:
  - kind: User
    name: your.email@monosense.io
    apiGroup: rbac.authorization.k8s.io
```

### 3. Create Developer Access for a Namespace

```bash
# Copy template to your namespace directory
cp kubernetes/bases/rbac/developer-role-template.yaml \
   kubernetes/workloads/<your-namespace>/rbac/developer-role.yaml

# Replace <NAMESPACE> with actual namespace
sed -i 's/<NAMESPACE>/your-namespace/g' \
   kubernetes/workloads/<your-namespace>/rbac/developer-role.yaml

# Add users/groups to RoleBinding
# Then commit and push
```

### 4. Create CI/CD ServiceAccount

```bash
# Copy template
cp kubernetes/bases/rbac/cicd-deployer-template.yaml \
   kubernetes/workloads/<your-namespace>/rbac/cicd-deployer.yaml

# Replace <NAMESPACE>
sed -i 's/<NAMESPACE>/your-namespace/g' \
   kubernetes/workloads/<your-namespace>/rbac/cicd-deployer.yaml

# Generate token for CI/CD
kubectl create token cicd-deployer -n <your-namespace> --duration=8760h
```

---

## 🔐 Security Best Practices

### Do's ✅

1. **Principle of Least Privilege** - Grant minimum required permissions
2. **Regular Audits** - Quarterly review of all bindings
3. **Service Accounts for Automation** - Never use personal credentials
4. **Time-Bound Break-Glass** - Revoke emergency access after incident

### Don'ts ❌

1. **Never commit tokens** - Use External Secrets for automation credentials
2. **Avoid cluster-admin** - Except for Flux and emergency break-glass
3. **No wildcard permissions** - Explicit allow lists only
4. **Don't use default ServiceAccount** - Create dedicated accounts

---

## 🔍 RBAC Audit Commands

```bash
# List all ClusterRoleBindings
kubectl get clusterrolebindings -o wide

# Find cluster-admin users (should be minimal)
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}'

# Check what a user can do
kubectl auth can-i --list --as=user@monosense.io

# Check what a ServiceAccount can do
kubectl auth can-i --list --as=system:serviceaccount:monitoring:vmagent

# List all Roles in a namespace
kubectl get roles -n <namespace> -o wide
```

---

## 📊 RBAC Compliance Checklist

Before deploying to production:

- [ ] All platform admin users documented in bindings
- [ ] Monitoring ServiceAccounts bound to monitoring-reader
- [ ] Developer roles created for application namespaces
- [ ] CI/CD ServiceAccounts use dedicated roles (not admin)
- [ ] No cluster-admin bindings except Flux and break-glass
- [ ] Quarterly audit scheduled in calendar
- [ ] Break-glass procedure documented and tested
- [ ] RBAC violations integrated into AlertManager

---

## 🛠️ Troubleshooting

### "Forbidden: User cannot access resource"

```bash
# Check user's permissions
kubectl auth can-i get pods -n <namespace> --as=user@example.com

# Check RoleBinding
kubectl get rolebindings -n <namespace> -o yaml | grep -A10 "name: <user>"

# Verify ClusterRole exists
kubectl get clusterrole platform-admin -o yaml
```

### "ServiceAccount lacks permissions"

```bash
# Check ServiceAccount's bindings
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq '.items[] | select(.subjects[]?.name=="<serviceaccount-name>")'

# Test ServiceAccount access
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<name>
```

---

## 🔗 Related Documentation

- [RBAC Security Model](../../../docs/security/rbac-model.md) - Complete RBAC strategy
- [Data Classification](../../../docs/security/data-classification.md) - BLOCKER #3
- [Talos Audit Logging](../../../docs/security/talos-audit-policy.md) - BLOCKER #2
- [Architecture Decision Record](../../../docs/architecture-decision-record.md) - ADR-007

---

**Status**: ✅ Ready for Deployment
**Last Updated**: 2025-10-14
**Owner**: Platform Team
