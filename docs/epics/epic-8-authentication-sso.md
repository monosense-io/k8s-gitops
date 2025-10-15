# EPIC-8: Authentication & SSO
**Goal:** Deploy Keycloak
**Status:** ❌ 0% Complete (not implemented)

## Story 8.1: Deploy Keycloak Operator
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Keycloak operator base HelmRelease created
- [ ] Keycloak operator infrastructure config created
- [ ] Operator deployed on infra cluster
- [ ] Operator healthy

**Tasks:**
- Create `kubernetes/bases/keycloak-operator/helmrelease.yaml`
- Create `kubernetes/workloads/platform/auth/keycloak/operator/kustomization.yaml`
- Update `kubernetes/workloads/platform/kustomization.yaml` to include auth/
- Deploy via Flux
- Verify: `kubectl --context infra get pods -n auth`

**Files to Create:**
- 🔲 `kubernetes/bases/keycloak-operator/helmrelease.yaml`
- 🔲 `kubernetes/workloads/platform/auth/keycloak/operator/kustomization.yaml`

**Note:** This is a **BLOCKER** for EPIC-9 applications that need SSO.

---

## Story 8.2: Deploy Keycloak Instance
**Priority:** P0 | **Points:** 5 | **Days:** 2 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Keycloak instance manifest created
- [ ] Connected to shared PostgreSQL (CloudNativePG)
- [ ] Admin credentials in 1Password
- [ ] Admin console accessible via HTTPRoute
- [ ] TLS certificate configured (cert-manager)
- [ ] Backup configured

**Tasks:**
- Create Keycloak instance CR
- Create ExternalSecret for admin password and DB credentials
- Create HTTPRoute for external access
- Configure cert-manager Certificate
- Deploy via Flux
- Access admin console: `https://keycloak.monosense.io`
- Configure initial realm

**Files to Create:**
- 🔲 `kubernetes/workloads/platform/auth/keycloak/instance/keycloak.yaml`
- 🔲 `kubernetes/workloads/platform/auth/keycloak/instance/externalsecret.yaml`
- 🔲 `kubernetes/workloads/platform/auth/keycloak/instance/httproute.yaml`

**Keycloak Configuration:**
- Database: PostgreSQL from Story 7.3
- Storage: OpenEBS for Keycloak data
- Replicas: 2 (HA)
- Resources: 2 CPU, 4GB RAM per replica (per ADR-012)

---

## Story 8.3: Configure SSO for Services
**Priority:** P1 | **Points:** 3 | **Days:** 2 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Grafana configured with Keycloak SSO (OIDC)
- [ ] GitLab configured with Keycloak SSO (OIDC)
- [ ] Harbor configured with Keycloak SSO (OIDC)
- [ ] Test logins work for each service

**Tasks:**
- Create Keycloak clients:
  - grafana-oidc
  - gitlab-oidc
  - harbor-oidc

- Update application HelmReleases with OIDC configuration:
  - Grafana: Add OIDC provider config
  - GitLab: Add OIDC provider
  - Harbor: Add OIDC auth

- Create ExternalSecrets for client secrets

- Test login flow:
  - Access Grafana → redirect to Keycloak → login → redirect back
  - Access GitLab → same flow
  - Access Harbor → same flow

**Files Modified:**
- 🔲 `kubernetes/workloads/platform/observability/victoria-metrics/grafana-oidc.yaml`
- 🔲 `kubernetes/workloads/tenants/gitlab/oidc-config.yaml`
- 🔲 `kubernetes/workloads/tenants/harbor/oidc-config.yaml` (when created)

---
