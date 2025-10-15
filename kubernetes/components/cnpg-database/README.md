# CloudNative-PG Database Provisioning Component

Reusable Kustomize component for provisioning databases on the shared-postgres cluster.

## Features

- ✅ Automated database creation
- ✅ Application-specific user with proper grants
- ✅ Credential management via ExternalSecret
- ✅ Database-specific service endpoint
- ✅ Idempotent operations

## Usage

### 1. Create database directory for your application

```bash
mkdir -p kubernetes/workloads/tenants/myapp/database
```

### 2. Create kustomization.yaml

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp

components:
  - ../../../../components/cnpg-database

patches:
  - target:
      kind: Job
      name: database-provisioner
    patch: |-
      - op: replace
        path: /metadata/name
        value: myapp-db-provisioner
      - op: replace
        path: /spec/template/spec/containers/0/env
        value:
          - name: DB_NAME
            value: myapp
          - name: DB_OWNER
            value: myapp_app
          - name: CLUSTER_NAME
            value: shared-postgres
          - name: CLUSTER_NAMESPACE
            value: cnpg-system

  - target:
      kind: ExternalSecret
      name: database-credentials
    patch: |-
      - op: replace
        path: /metadata/name
        value: myapp-db-credentials
      - op: replace
        path: /spec/data/0/remoteRef/key
        value: kubernetes/infra/cloudnative-pg/myapp
```

### 3. Run the provisioner job

The job will:
1. Connect to shared-postgres cluster
2. Create database `myapp`
3. Create user `myapp_app`
4. Grant appropriate permissions
5. Install common extensions

### 4. Application connection

Use these environment variables in your application:

```yaml
env:
  - name: DB_HOST
    value: "shared-postgres-rw.cnpg-system.svc.cluster.local"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "myapp"
  - name: DB_USER
    value: "myapp_app"
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: myapp-db-credentials
        key: password
```

## With PgBouncer Pooler

For high-traffic applications, use a pooler:

```yaml
env:
  - name: DB_HOST
    value: "myapp-pooler-rw.cnpg-system.svc.cluster.local"
  - name: DB_PORT
    value: "5432"
```

See `kubernetes/workloads/platform/databases/cloudnative-pg/poolers/` for pooler examples.

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_NAME` | Database name to create | Required |
| `DB_OWNER` | Database owner username | Required |
| `CLUSTER_NAME` | Target CNPG cluster | `shared-postgres` |
| `CLUSTER_NAMESPACE` | CNPG cluster namespace | `cnpg-system` |
| `EXTENSIONS` | Extensions to install | `pg_stat_statements` |

## Examples

See existing applications:
- GitLab: `kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/`
- Harbor: Create using this component
- Mattermost: Create using this component
