# 03 — STORY-NET-CILIUM-GATEWAY — Create Gateway API Manifests

Sequence: 03/50 | Prev: STORY-NET-CILIUM-IPAM.md | Next: STORY-DNS-COREDNS-BASE.md
Sprint: 1 | Lane: Networking
Global Sequence: 03/50

## Status
Approved
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §10 Networking (Cilium); kubernetes/infrastructure/networking/cilium/gateway/

---

## Story

As a platform engineer, I want to **create Gateway API manifests** for exposing L7 HTTP(S) traffic using Cilium's Gateway API implementation, so that when deployed in Story 45, applications can use standards-based traffic management with eBPF-based L7 routing.

This story creates the declarative Gateway API manifests (GatewayClass, Gateway, TLS certificates). Actual deployment and gateway validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create Gateway API manifests with Cilium as the controller
- Configure cluster-specific gateways with dedicated LoadBalancer IPs
- Enable Git-managed routing and TLS termination
- Foundation for HTTPRoutes in application workload stories

## Scope

**This Story (Manifest Creation):**
- Create Gateway API manifests in `kubernetes/infrastructure/networking/cilium/gateway/`
- Create GatewayClass manifest (Cilium controller)
- Create Gateway manifests with cluster-specific IPs
- Create wildcard TLS Certificate manifests
- Create Kustomization for gateway resources
- Local validation (flux build, kubeconform)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying Gateway API resources to clusters
- Verifying Gateway programmed and ready
- Testing HTTP/HTTPS reachability
- BGP advertisement validation
- E2E testing with echo HTTPRoute

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **GatewayClass Manifest Created:**
   - `kubernetes/infrastructure/networking/cilium/gateway/gatewayclass.yaml` exists
   - Specifies `controllerName: io.cilium/gateway-controller`
   - GatewayClass name: `cilium`

2. **Gateway Manifests Created:**
   - `kubernetes/infrastructure/networking/cilium/gateway/gateway.yaml` exists
   - Gateway name: `cluster-gateway` in `kube-system` namespace
   - References GatewayClass `cilium`
   - Specifies LoadBalancer IP via `spec.addresses[0].value: ${CILIUM_GATEWAY_LB_IP}`
   - Listeners configured for HTTP (80) and HTTPS (443)
   - TLS certificate reference configured

3. **Certificate Manifests Created:**
   - Wildcard certificate manifest exists
   - References cert-manager ClusterIssuer `letsencrypt-production` (from Story 06)
   - Certificate namespace: `kube-system`
   - DNS names include wildcard (e.g., `*.${SECRET_DOMAIN}`)

4. **Cluster-Specific Configuration:**
   - Gateway IP substitution configured via `postBuild.substitute`
   - Infra gateway uses `10.25.11.110` (from cluster-settings)
   - Apps gateway uses `10.25.11.121` (from cluster-settings)
   - Certificate domains use `${SECRET_DOMAIN}` substitution

5. **Kustomization Created (Cluster-Level):**
   - Cluster-level Flux `Kustomization` named `cilium-gateway` is added in:
     - `kubernetes/clusters/infra/infrastructure.yaml` → path `./kubernetes/infrastructure/networking/cilium/gateway`
     - `kubernetes/clusters/apps/infrastructure.yaml` → path `./kubernetes/infrastructure/networking/cilium/gateway`
   - Includes `dependsOn: [ { name: cilium-core }, { name: cilium-ipam } ]`
   - `kubernetes/infrastructure/networking/cilium/gateway/kustomization.yaml` glue file exists and lists gateway manifests

6. **Local Validation Passes:**
   - `flux build -f kubernetes/clusters/infra/infrastructure.yaml --path .` succeeds
   - `flux build -f kubernetes/clusters/apps/infrastructure.yaml --path .` succeeds
   - Output shows correct IP substitution for each cluster
   - `kubeconform --strict -ignore-missing-schemas` validates Gateway API manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ Gateway API CRDs installed (handled in Story 43)
- ❌ GatewayClass Accepted=True
- ❌ Gateway Programmed=True
- ❌ LoadBalancer IP allocated correctly
- ❌ BGP advertisement working
- ❌ HTTP/HTTPS reachability
- ❌ TLS certificate issued
- ❌ E2E testing with HTTPRoute

---

## Dependencies

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium core manifests with `gatewayAPI.enabled: true`)
- Story 02 (STORY-NET-CILIUM-IPAM) complete (IPAM pools created)
- Story 06 (STORY-SEC-CERT-MANAGER-ISSUERS) complete (cert-manager manifests created)
- Cluster-settings ConfigMaps with `CILIUM_GATEWAY_LB_IP` and `SECRET_DOMAIN`
- Tools: kubectl (for dry-run), flux CLI, kubeconform

Note: As of 2025-10-27, `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` does not declare `values.gatewayAPI.enabled: true`. Treat this as a should-fix before cluster-level validation stories; this story remains local-only.

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ ClusterIssuer deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Tasks / Subtasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  # Confirm gatewayAPI.enabled: true in values
  ```
  If missing, prepare a minimal patch to align with prerequisites (apply in Story 01 or as a separate chore PR):
  ```yaml
  # kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml (values excerpt)
  values:
    gatewayAPI:
      enabled: true
  ```

- [ ] Verify Story 02 complete (IPAM pool manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-*.yaml
  ```

- [ ] Verify Story 06 complete (cert-manager manifests created):
  ```bash
  ls -la kubernetes/infrastructure/security/cert-manager/
  # Confirm ClusterIssuer manifests exist
  ```

- [ ] Verify cluster-settings have Gateway IP variables:
  ```bash
  grep CILIUM_GATEWAY_LB_IP kubernetes/clusters/infra/cluster-settings.yaml
  grep CILIUM_GATEWAY_LB_IP kubernetes/clusters/apps/cluster-settings.yaml
  grep SECRET_DOMAIN kubernetes/clusters/infra/cluster-settings.yaml
  ```

---

### T2: Create Gateway API Manifests (5 files)

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/cilium/gateway
  ```

- [ ] Create `gatewayclass.yaml`:
  ```yaml
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: GatewayClass
  metadata:
    name: cilium
  spec:
    controllerName: io.cilium/gateway-controller
    description: "Cilium Gateway API implementation using eBPF dataplane"
  ```

- [ ] Create `gateway.yaml`:
  ```yaml
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: cluster-gateway
    namespace: kube-system
  spec:
    gatewayClassName: cilium
    addresses:
    - type: IPAddress
      value: ${CILIUM_GATEWAY_LB_IP}
    listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
        - kind: Secret
          name: wildcard-tls
          namespace: kube-system
  ```

- [ ] Create `certificate.yaml`:
  ```yaml
  ---
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: wildcard-tls
    namespace: kube-system
  spec:
    secretName: wildcard-tls
    issuerRef:
      name: letsencrypt-production
      kind: ClusterIssuer
    dnsNames:
    - "*.${SECRET_DOMAIN}"
    - "${SECRET_DOMAIN}"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
  - gatewayclass.yaml
  - gateway.yaml
  - certificate.yaml
  ```

---

### T3: Create Flux Kustomization (Cluster-Level)

- [ ] Add `Kustomization` entries to cluster files (no `ks.yaml` in the component directory):
  - File: `kubernetes/clusters/infra/infrastructure.yaml`
  - File: `kubernetes/clusters/apps/infrastructure.yaml`
  - Example snippet to append (adjust path per cluster):
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: cilium-gateway
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/cilium/gateway
    prune: true
    wait: true
    dependsOn:
    - name: cilium-core
    - name: cilium-ipam
    postBuild:
      substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
    healthChecks:
    - apiVersion: gateway.networking.k8s.io/v1
      kind: GatewayClass
      name: cilium
    - apiVersion: gateway.networking.k8s.io/v1
      kind: Gateway
      name: cluster-gateway
      namespace: kube-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl apply --dry-run=client -f kubernetes/infrastructure/networking/cilium/gateway/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/gateway
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster (should substitute 10.25.11.110)
  flux build -f kubernetes/clusters/infra/infrastructure.yaml --path . | \
    yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  # Expected: 10.25.11.110

  # Apps cluster (should substitute 10.25.11.121)
  flux build -f kubernetes/clusters/apps/infrastructure.yaml --path . | \
    yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  # Expected: 10.25.11.121
  ```

- [ ] Validate Gateway API schemas with kubeconform:
  ```bash
  kubeconform --strict -ignore-missing-schemas kubernetes/infrastructure/networking/cilium/gateway/*.yaml
  ```

- [ ] Verify certificate domain substitution:
  ```bash
  flux build -f kubernetes/clusters/infra/infrastructure.yaml --path . | \
    yq 'select(.kind == "Certificate") | .spec.dnsNames'
  # Expected: ["*.monosense.io", "monosense.io"] (or actual SECRET_DOMAIN)
  ```

---

### T5: Cluster Kustomization Updates

- [ ] Ensure `cilium-gateway` Kustomization is present in both cluster files and depends on `cilium-core` and `cilium-ipam`.
- [ ] No changes are required to `kubernetes/infrastructure/networking/cilium/kustomization.yaml` (aggregator not used for cluster-level Kustomizations).

---

## Dev Notes

- Source of truth for networking and gateway: `docs/architecture.md` §10 (Networking — Cilium) and Cluster Settings ConfigMaps:
  - `kubernetes/clusters/infra/cluster-settings.yaml` → `CILIUM_GATEWAY_LB_IP: 10.25.11.110`
  - `kubernetes/clusters/apps/cluster-settings.yaml` → `CILIUM_GATEWAY_LB_IP: 10.25.11.121`
- Repository layout:
  - Component manifests: `kubernetes/infrastructure/networking/cilium/gateway/`
  - Cluster-level wiring: `kubernetes/clusters/{infra,apps}/infrastructure.yaml` (`Kustomization` named `cilium-gateway`)
- Controller and API:
  - GatewayClass `controllerName: io.cilium/gateway-controller`
  - Gateway IP configured via `spec.addresses[0].value`
  - Ensure Cilium HelmRelease sets `values.gatewayAPI.enabled: true` (prereq; separate chore if missing)
- Dependencies (manifests-first):
  - Story 01: Cilium core manifests (Gateway API controller enabled in bootstrap)
  - Story 02: IPAM pools
  - Story 06: cert-manager issuers (`letsencrypt-production`)

### Testing

- Flux dry-runs (per cluster):
  ```bash
  flux build -f kubernetes/clusters/infra/infrastructure.yaml --path . \
    | yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  flux build -f kubernetes/clusters/apps/infrastructure.yaml --path . \
    | yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  ```
- Schema validation (local):
  ```bash
  kubeconform --strict -ignore-missing-schemas kubernetes/infrastructure/networking/cilium/gateway/*.yaml
  ```
- Manifest syntax:
  ```bash
  kubectl apply --dry-run=client -f kubernetes/infrastructure/networking/cilium/gateway/
  ```

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## PO Course Correction (2025-10-27, rev 2)

- Critical
  - Cert-manager dependency ordering for Certificate (DEP-001): Ensure `cilium-gateway` Kustomization depends on the cert-manager issuers Kustomization, or split `Certificate` into a Kustomization that depends on cert-manager. Prevents reconciliation failures when issuers/CRDs are not yet present.

- Should-Fix
  - Enable Cilium Gateway API controller by adding `values.gatewayAPI.enabled: true` to `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` (GAPI-001). This is a prereq from Story 01 and required for Gateway programming in validation stories.
  - Core config mismatch: `.bmad-core/core-config.yaml` has `prdSharded: true` while `docs/prd/` is absent; reconcile to avoid process confusion.
  - Append `cilium-gateway` Kustomization to both clusters with `dependsOn: [cilium-core, cilium-ipam]` and include optional healthChecks for GatewayClass/Gateway.

- Nice-to-Have
  - In `gateway.yaml`, `certificateRefs[].namespace: kube-system` is redundant since Gateway and Secret share a namespace; can be omitted for brevity.
  - Clarify that `issuerRef` is a reference only; issuer manifests ship in Story 06 and are not required for this story’s local validations.

## QA Results

### Risk Profile (2025-10-27, rev 2)
- Totals: 1 Critical, 1 High, 3 Medium, 5 Low
- Highest: DEP-001 — Cert‑Manager dependency ordering for Certificate manifests (score 9)

| ID       | Category | Description                                                                                                         | Prob. | Impact | Score | Priority |
|----------|----------|---------------------------------------------------------------------------------------------------------------------|-------|--------|-------|----------|
| DEP-001  | OPS      | Certificate depends on ClusterIssuer; if cert-manager CRDs/issuers aren’t applied first, reconciliation will fail   | High (3) | High (3) | 9 | Critical |
| GAPI-001 | TECH     | Cilium Gateway API controller not enabled (`values.gatewayAPI.enabled: true` missing); Gateway will not program     | Medium (2) | High (3) | 6 | High |
| WIRE-001 | OPS      | Missing or incorrect cluster‑level `cilium-gateway` Kustomization/dependsOn                                         | Medium (2) | Medium (2) | 4 | Medium |
| SUB-001  | TECH     | `${CILIUM_GATEWAY_LB_IP}` substitution missing/wrong                                                                | Medium (2) | Medium (2) | 4 | Medium |
| NET-001  | OPS      | Gateway reconciled before BGP reachability validated                                                                 | Medium (2) | Medium (2) | 4 | Medium |
| API-001  | TECH     | Using `spec.addresses` requires Gateway API v1/Cilium compatibility                                                  | Low (1) | Medium (2) | 2 | Low |
| IPAM-001 | TECH     | Gateway IP outside IPAM pool range                                                                                  | Low (1) | Medium (2) | 2 | Low |
| SCHEMA-001| OPS     | Local schema validation without CRDs can mislead                                                                     | Medium (2) | Low (1) | 2 | Low |
| SEC-001  | SEC      | Wildcard TLS secret in `kube-system` broadens blast radius                                                          | Low (1) | Medium (2) | 2 | Low |
| DOC-001  | OPS      | PRD sharding config mismatch (core-config vs repo layout)                                                           | Low (1) | Low (1) | 1 | Minimal |

Gate Snippet (pasteable)
```yaml
risk_summary:
  totals: { critical: 1, high: 1, medium: 3, low: 5 }
  highest: { id: DEP-001, score: 9, title: Cert-Manager dependency ordering for Certificate manifests }
  recommendations:
    must_fix:
      - Enable Cilium Gateway API controller (values.gatewayAPI.enabled: true)
      - Add cluster-level cilium-gateway Kustomizations with dependsOn
      - Ensure cert-manager issuers before reconciling Certificate
    monitor:
      - Validate IP substitution and IPAM pool alignment in CI
      - Verify Gateway API schema compatibility with Cilium
```

Test Design Gate Snippet (pasteable)
```yaml
test_design:
  scenarios_total: 20
  by_level: { unit: 8, integration: 12, e2e: 0 }
  by_priority: { p0: 7, p1: 9, p2: 4 }
  coverage_gaps: []
```

### Risk Profile (2025-10-27)
- Totals: 0 Critical, 1 High, 4 Medium, 3 Low
- Highest: DEP-001 — Cert‑Manager dependency ordering for Certificate manifests (score 9)

| ID       | Category | Description                                                                                                         | Prob. | Impact | Score | Priority |
|----------|----------|---------------------------------------------------------------------------------------------------------------------|-------|--------|-------|----------|
| DEP-001  | OPS      | Certificate depends on ClusterIssuer; if cert-manager CRDs/issuers aren’t applied first, reconciliation will fail   | High (3) | High (3) | 9 | High |
| WIRE-001 | OPS      | Missing or incorrect cluster‑level `cilium-gateway` Kustomization/dependsOn                                         | Medium (2) | Medium (2) | 4 | Medium |
| API-001  | TECH     | Using `spec.addresses` requires Gateway API v1/Cilium compatibility                                                  | Low (1) | Medium (2) | 2 | Low |
| SUB-001  | TECH     | `${CILIUM_GATEWAY_LB_IP}` substitution missing/wrong                                                                | Medium (2) | Medium (2) | 4 | Medium |
| IPAM-001 | TECH     | Gateway IP outside IPAM pool range                                                                                  | Low (1) | Medium (2) | 2 | Low |
| SCHEMA-001| OPS     | Local schema validation without CRDs can mislead                                                                     | Medium (2) | Low (1) | 2 | Low |
| SEC-001  | SEC      | Wildcard TLS secret in `kube-system` broadens blast radius                                                          | Low (1) | Medium (2) | 2 | Low |
| NET-001  | OPS      | Gateway exposed before BGP reachability validated                                                                    | Medium (2) | Medium (2) | 4 | Medium |

Recommendations
- Must‑fix before deployment: add cluster‑level `cilium-gateway` Kustomizations with dependsOn; ensure cert‑manager issuers are present before reconciling Certificate.
- Monitor: Gateway API schema compatibility with Cilium; validate IP substitution from cluster‑settings.

Gate Snippet (pasteable)
```yaml
risk_summary:
  totals: { critical: 0, high: 1, medium: 4, low: 3 }
  highest: { id: DEP-001, score: 9, title: Cert-Manager dependency ordering for Certificate manifests }
  recommendations:
    must_fix:
      - Add cluster-level cilium-gateway Kustomization with dependsOn
      - Ensure cert-manager issuers before reconciling Certificate
    monitor:
      - Verify Gateway API schema compatibility with Cilium
      - Validate IP substitution from cluster-settings
```

### Test Design (2025-10-27, rev 2)
- Scenarios: 20 total — Unit 8, Integration 12, E2E 0 (runtime E2E in Story 45)
- Priorities: P0: 7, P1: 9, P2: 4

AC‑1: GatewayClass Manifest
- 03.gateway-UNIT-001 (P0, Unit): gatewayclass.yaml exists; name=cilium.
- 03.gateway-UNIT-002 (P0, Unit): controllerName=io.cilium/gateway-controller.

AC‑2: Gateway Manifest
- 03.GW-UNIT-003 (P0, Unit): name=cluster-gateway, namespace=kube-system.
- 03.GW-UNIT-004 (P0, Unit): gatewayClassName=cilium.
- 03.GW-UNIT-005 (P1, Unit): addresses[0].type=IPAddress; value present.
- 03.GW-UNIT-006 (P1, Unit): listeners HTTP:80 and HTTPS:443; allowedRoutes.namespaces.from=All.
- 03.GW-INT-001 (P0, Integration): tls.certificateRefs points to Secret wildcard-tls in kube-system (via render).

AC‑3: Certificate Manifest
- 03.GW-UNIT-007 (P0, Unit): certificate.yaml present; namespace=kube-system; secretName=wildcard-tls.
- 03.GW-UNIT-008 (P1, Unit): issuerRef.kind=ClusterIssuer; name=letsencrypt-production.
- 03.GW-INT-002 (P1, Integration): Flux build renders dnsNames from SECRET_DOMAIN (no placeholders).

AC‑4: Cluster‑Specific Substitution
- 03.GW-INT-003 (P0, Integration): Infra build ⇒ addresses[0].value=10.25.11.110.
- 03.GW-INT-004 (P0, Integration): Apps build ⇒ addresses[0].value=10.25.11.121.
- 03.GW-INT-005 (P1, Integration): Certificate dnsNames substituted for both clusters.
- 03.GW-INT-006 (P1, Integration): No unresolved placeholders in rendered output.

AC‑5: Cluster‑Level Kustomization
- 03.GW-INT-007 (P0, Integration): `cilium-gateway` Kustomization appended in both clusters with dependsOn [cilium-core, cilium-ipam].
- 03.GW-INT-008 (P0, Integration): Present in apps cluster.
- 03.GW-INT-009 (P1, Integration): dependsOn includes both names.
- 03.GW-INT-010 (P1, Integration): Health checks for GatewayClass/Gateway configured (optional).

AC‑6: Local Validation
- 03.GW-INT-011 (P1, Integration): kubectl dry-run succeeds.
- 03.GW-INT-012 (P1, Integration): kustomize build succeeds.
- 03.GW-INT-013 (P1, Integration): kubeconform --strict -ignore-missing-schemas passes.

Risk‑Driven Assurance
- 03.GW-INT-014 (P0, Integration): Cilium HelmRelease sets values.gatewayAPI.enabled: true.
- 03.GW-INT-015 (P1, Integration): Rendered Gateway IP falls within IPAM pool per cluster.
- 03.GW-INT-016 (P2, Integration): YAML structural lint on gateway files succeeds.
- 03.GW-INT-017 (P2, Integration): certificateRefs[].namespace omitted or equals kube-system.

Recommended Execution Order
1) P0 first: 001–005, 003–004, 007–008, 014
2) P1 next: 006, 008–013, 015
3) P2 last: 016–017

---

### T6: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/gateway/
  git commit -m "feat(networking): add Cilium Gateway API manifests

  - Create GatewayClass for Cilium controller
  - Create Gateway with cluster-specific LoadBalancer IPs
  - Create wildcard TLS Certificate
  - Configure Flux Kustomization with dependencies
  - Add local validation steps

  Part of Story 03 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy & Validate Gateway (Story 45 only)
flux reconcile kustomization cilium-gateway --with-source

# Verify GatewayClass Accepted
kubectl get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'

# Verify Gateway Programmed
kubectl get gateway -n kube-system cluster-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'

# Verify Gateway IP allocation
kubectl get gateway -n kube-system cluster-gateway -o jsonpath='{.status.addresses[0].value}'

# Test HTTP reachability
curl -v http://10.25.11.110

# Verify Certificate Ready
kubectl -n kube-system get certificate wildcard-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# E2E test with echo HTTPRoute
curl -H "Host: echo.monosense.io" http://10.25.11.110
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/networking/cilium/gateway/`
- [ ] GatewayClass manifest created with Cilium controller
- [ ] Gateway manifest created with cluster-specific IP substitution
- [ ] Certificate manifest created with wildcard domain
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct IP substitution for both clusters
  - [ ] `kubeconform --strict` validates Gateway API schemas
  - [ ] Cilium HelmRelease includes `values.gatewayAPI.enabled: true` (or a tracking chore/PR is filed to add it in Story 01)
- [ ] Infrastructure kustomization updated to include gateway
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ Gateway API CRDs installed
- ❌ GatewayClass Accepted=True
- ❌ Gateway Programmed=True
- ❌ LoadBalancer IP allocated correctly (infra .110, apps .121)
- ❌ BGP advertising Gateway IPs
- ❌ HTTP/HTTPS reachable
- ❌ Certificate Ready
- ❌ Echo HTTPRoute working
- ❌ E2E test evidence captured

---

## Quick Troubleshooting

**Gateway Programmed=False**:
- Check: Gateway IP in IPAM pool range
- Check: Cilium operator logs for errors

**HTTPRoute Not Attaching**:
- Check: `allowedRoutes.namespaces: All`
- Check: ParentRef name/namespace match

**Gateway Not Reachable**:
- Check: BGP peering status
- Check: Network policies
- Test from cluster node first

---

## Architecture Notes

### IP Allocation

| Service | Infra | Apps | Range |
|---|---|---|---|
| ClusterMesh | 10.25.11.100 | 10.25.11.120 | Reserved |
| Gateway | 10.25.11.110 | 10.25.11.121 | Reserved |
| Available | .111-.119 | .122-.139 | Pool |

### Component Flow

```
Client → Gateway IP → Cilium Controller → Gateway Service →
eBPF Dataplane → HTTPRoute → Backend Service → Pods
```

### Key Configuration

- **Bootstrap**: `gatewayAPI.enabled: true` in `bootstrap/clusters/<cluster>/cilium-values.yaml`
- **IPAM**: Pools with `disabled: ${INFRA_POOL_DISABLED}` / `${APPS_POOL_DISABLED}`
- **TLS**: cert-manager Certificate with Cloudflare DNS validation
- **Flux**: `postBuild.substituteFrom: cluster-settings` for IP injection

---

**References**:
- Cilium Gateway API: https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/
- Architecture: docs/architecture.md §9

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T6 focusing on local validation only. | Platform Engineering |
