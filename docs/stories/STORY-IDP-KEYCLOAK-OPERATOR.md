# 27 — STORY-IDP-KEYCLOAK-OPERATOR — Keycloak via Operator (Infra)

Sequence: 27/27 | Prev: STORY-OBS-VM-STACK.md | Next: —

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/identity/keycloak; kubernetes/bases/keycloak-operator

## Story
Deploy Keycloak using the official Keycloak Operator on the infra cluster, integrate with the shared CNPG Postgres (via dedicated pooler), expose over HTTPS, enable metrics scraping, and codify day‑2 operations (backup, upgrades, realm import, and SSO readiness).

## Why / Outcome
- Centralized identity provider managed declaratively with safe upgrades.
- Consistent DB connectivity through CNPG and PgBouncer with secure TLS.
- Clear day‑2 runbook for lifecycle, monitoring, and recovery.

## Scope
- Operator installation (OLM or manifest‑based) in `infra`.
- One `Keycloak` CR for the core instance (HA ready; small footprint).
- External Postgres via CNPG pooler `keycloak-pooler` and `keycloak_app` user.
- HTTPS exposure (Ingress or Gateway‑API route) with cert‑manager TLS.
- Metrics via ServiceMonitor and dashboards integration.

## Acceptance Criteria
1) Operator installed; CRDs Established; controller Available.
2) `Keycloak` instance Ready with N≥2 replicas, healthy probes, and HTTPS endpoint reachable with valid TLS.
3) DB connectivity through `keycloak-pooler-rw.cnpg-system.svc.cluster.local:5432` using secret `keycloak-db-credentials`; schema initialized.
4) Metrics discovered by Prometheus (`ServiceMonitor` present, scrape succeeds); basic dashboard shows uptime, requests, and DB pool.
5) Admin bootstrap complete (admin user managed via ExternalSecret) and at least one realm import applied idempotently.
6) Upgrade procedure documented and tested in a non‑prod namespace.

## Dependencies / Inputs
- CNPG operator + shared cluster + `keycloak-pooler` (session mode). 
- cert-manager issuers present; ingress/gateway class available.
- ExternalSecrets store for admin and DB credentials.

## Tasks / Subtasks
- [ ] Install Keycloak Operator (OLM or manifests under `bases/keycloak-operator`).
- [ ] Create namespace `keycloak-system` and RBAC labels.
- [ ] Add ExternalSecret for admin (`KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`).
- [ ] Create `Keycloak` CR: replicas, hostname, TLS, external DB.
- [ ] Optional: add HTTPRoute or Ingress, depending on platform standard.
- [ ] Add `ServiceMonitor` or enable operator‑managed monitoring.
- [ ] Add minimal realm import (e.g., base realm + client for platform login).
- [ ] Validation steps executed with evidence.

## Validation Steps
- kubectl -n keycloak-system get csv,deploy,po
- kubectl -n keycloak-system get keycloaks.k8s.keycloak.org
- curl -k https://<hostname>/.well-known/openid-configuration | jq .issuer
- kubectl -n cnpg-system exec -ti deploy/keycloak-pooler -- psql -h localhost -U keycloak_app -c '\\dt' keycloak
- Verify `ServiceMonitor` and VM scrape: check `up{job="keycloak"}` and `keycloak_*` metrics

## Definition of Done
- All ACs met; story updated with links to manifests and dashboards.

---

## Research — Keycloak Operator (Summary & Guidance)

- Operator install: Recommended via OLM (OperatorHub) or manual manifests. OLM provides managed upgrades; alternatively apply the official bundle manifests (CRDs + controller) for the targeted version. citeturn0search5turn0search6
- Basic deployment flow: Install operator → create namespace → define `Keycloak` CR → (optionally) configure ingress/hostname/TLS in CR → supply admin credentials (env/Secret) and external DB settings. citeturn0search6
- Ingress/TLS: Set `spec.hostname.hostname` and `spec.http.tlsSecret` in the `Keycloak` CR to enable HTTPS; you may also disable CR‑managed Ingress and provision your own (e.g., Gateway API HTTPRoute) if your platform standard prefers it. citeturn0search6
- External Postgres: Configure connection fields in the `Keycloak` CR to use external Postgres (vendor `postgres`) with host, port, db name, username/password from K8s Secret; Keycloak Operator will initialize the schema on first boot. Use PgBouncer session mode for Hibernate compatibility. citeturn0search6
- Monitoring: The operator supports Prometheus scraping through standard Service/ServiceMonitor patterns; confirm presence of a `ServiceMonitor` if the Prometheus Operator CRDs are installed. citeturn0search6
- Upgrades: With OLM, subscribe to a channel and set approval (Automatic/Manual). Test minor version bumps in a staging namespace; follow release notes for config changes. citeturn0search5

### Recommended Baseline (Infra)
- Namespace: `keycloak-system`; label for GitOps ownership.
- Operator: OLM `Subscription` pinned to a minor channel; manual approval in prod.
- Replicas: 2 (HA), CPU 500m each, memory 1–2Gi; horizontal scaling via HPA if needed.
- DB: CNPG shared cluster via `keycloak-pooler` (session mode); credentials from ExternalSecret `keycloak-db-credentials`.
- TLS: cert-manager issued secret `sso-tls` for hostname `sso.infra.example.com` (replace with actual).
- Ingress: prefer Gateway API HTTPRoute; if not available, use Ingress class per platform.
- Monitoring: Enable ServiceMonitor; add Keycloak overview dashboard in Grafana.

### Example (illustrative snippets)

OLM Subscription (operator namespace can be `keycloak-operator` or `keycloak-system`):
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: keycloak-operator
  namespace: keycloak-system
spec:
  channel: stable
  installPlanApproval: Manual
  name: keycloak-operator
  source: operatorhubio-catalog
  sourceNamespace: olm
```

Keycloak CR (external DB + TLS):
```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak-system
spec:
  instances: 2
  hostname:
    hostname: sso.infra.example.com
  http:
    tlsSecret: sso-tls
  ingress:
    enabled: true
  db:
    vendor: postgres
    host: keycloak-pooler-rw.cnpg-system.svc.cluster.local
    port: 5432
    database: keycloak
    usernameSecret:
      name: keycloak-db-credentials
      key: username
    passwordSecret:
      name: keycloak-db-credentials
      key: password
```

Notes: Replace `channel`, `hostname`, secrets, and class names to match the environment and GitOps conventions.

### References
- Keycloak Operator — Installation and Upgrade. citeturn0search5
- Keycloak — Basic deployment and CR fields (hostname, http.tlsSecret, db). citeturn0search6

---

## Optional Steps (Recommended Add‑Ons)

- GitOps scaffolding
  - bases/keycloak-operator: OLM `Namespace` + `OperatorGroup` + `Subscription` (channel pinned; Manual approval in prod)
  - workloads/platform/identity/keycloak: `Keycloak` CR, `ExternalSecret` for admin, exposure (`Ingress` or `HTTPRoute`), optional `ServiceMonitor`
- Admin and DB secrets management
  - `ExternalSecret` for `KEYCLOAK_ADMIN`/`KEYCLOAK_ADMIN_PASSWORD`
  - `keycloak-db-credentials` managed in `cnpg-system`; read in `keycloak-system`
- Realm import (idempotent)
  - Store realm JSON/YAML in repo; apply via `KeycloakRealmImport` (or init job using `kcadm.sh`)
  - Add a lightweight check to ensure imports don’t re-create existing clients/roles
- Realm export / backup
  - CronJob using `kcadm.sh` to export realms nightly to S3 (MinIO) with retention (e.g., 30 days); tag with git SHA
  - Document restore flow (import back from S3 to staging, then prod)
- Monitoring and alerts
  - Ensure `ServiceMonitor` discovery; add Grafana dashboards (uptime, login rates, 4xx/5xx, DB pool usage)
  - Alerting: elevated 5xx, admin login failures spike, DB pool saturation, JVM OOM risk
- Exposure choices
  - Prefer Gateway API `HTTPRoute`; otherwise use `Ingress` with TLS via cert‑manager secret `sso-tls`
  - If using L7 with sticky sessions, enable session affinity only if required by upstream proxy policy
- Scaling & performance
  - Start with 2 instances; add HPA (CPU 60% target) and track RPS/P99 latency
  - Keep PgBouncer in `session` mode for Hibernate; validate prepared statements behavior
- Network and security
  - NetworkPolicy: restrict egress to CNPG pooler, DNS, and cert authority endpoints
  - Rotate admin and DB passwords on a schedule; document break‑glass access
- Upgrades & channels
  - Stage OLM upgrades in a non‑prod namespace first; approve to prod after smoke tests

---

## UI Customization — Red Hat Portal‑Inspired Login Theme (Story‑Only)

Goal
- Deliver a branded, accessible Keycloak login experience inspired by the Red Hat portal aesthetic (clean layout, restrained use of primary red accents, ample whitespace), without copying proprietary assets. Maintain WCAG AA contrast and support dark mode.

Deliverables
- Theme name: `monosense-rh`
- Files (not committed in this story; paths to be used later):
  - `kubernetes/workloads/apps/keycloak/themes/monosense-rh/theme.properties`
  - `kubernetes/workloads/apps/keycloak/themes/monosense-rh/login/login.ftl`
  - `kubernetes/workloads/apps/keycloak/themes/monosense-rh/login/resources/css/styles.css`
  - `kubernetes/workloads/apps/keycloak/themes/monosense-rh/login/messages/messages_en.properties`
  - Assets: `.../resources/img/logo.svg`, `.../resources/img/bg.svg` (placeholders, no trademarks)

Design spec (high level)
- Layout: Centered card, max‑width 480–560px; generous spacing; clear error states.
- Color palette: primary `#EE0000` accents, neutrals `#151515`, `#6A6E73`, surfaces `#F5F5F5`/white; dark mode with tokens.
- Typography: Prefer system stack or open fonts (e.g., Red Hat Text/Display under OFL) with fallbacks; 16px base.
- Components: Branded header with logo, prominent “Sign in” CTA, subtle link styling, keyboard focus rings, error banners.
- Accessibility: WCAG AA contrast; visible focus; aria‑labels for inputs; RTL support.

Implementation options (choose one later)
1) Baked image (recommended for stability)
   - Create image extending official Keycloak: copy `themes/monosense-rh` to `/opt/keycloak/themes/monosense-rh`.
   - Publish to your registry; set `spec.image` in `Keycloak` CR to the custom image.
2) InitContainer + ConfigMap (no image build)
   - Store theme files in ConfigMap(s); use an initContainer to copy into an `emptyDir`, mount at `/opt/keycloak/themes` in the main container.
   - Configure `podTemplate` in the `Keycloak` CR to add volumes/volumeMounts and initContainer.

Realm configuration
- Set realm login theme to `monosense-rh` via realm import (add to your existing realm JSON) or admin API.
- If you use Keycloak Operator realm import, include: `"loginTheme": "monosense-rh"`.

Acceptance Criteria (Theme)
1) Login page renders with `monosense-rh` theme on `${GITLAB_HOST}` SSO flow (OIDC) and directly on Keycloak host; all images/CSS load.
2) Theme passes WCAG AA checks for primary flows; keyboard navigation and screen readers work on the login page.
3) Dark mode variant available (CSS media query or toggle); branding remains consistent.
4) No inline scripts or external trackers; CSP remains default/strict.

Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Create theme skeleton under `kubernetes/workloads/apps/keycloak/themes/monosense-rh/` with `theme.properties`, `login.ftl`, `styles.css`, messages, and assets placeholders.
- [ ] Choose delivery option:
  - A) Build `ghcr.io/monosense/keycloak:with-theme` (Dockerfile extends `quay.io/keycloak/keycloak:<version>` and COPY the theme).
  - B) Add ConfigMap(s) + initContainer to project the theme at `/opt/keycloak/themes`.
- [ ] Update realm import to set `loginTheme: monosense-rh`.
- [ ] Add basic e2e check in CI: curl Keycloak login page and assert `<link href="/resources/.../styles.css">` and `<title>` contain expected tokens.

Validation Steps (later)
- Open `https://<keycloak-host>/realms/<realm>/account` → Sign In → verify theme; test light/dark; tab through inputs; check error state.
- Lighthouse/axe scan achieves AA contrast and no critical accessibility violations.
