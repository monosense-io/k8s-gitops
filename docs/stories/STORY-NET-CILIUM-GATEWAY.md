# 03 — STORY-NET-CILIUM-GATEWAY — Create Gateway API Manifests

Sequence: 03/50 | Prev: STORY-NET-CILIUM-IPAM.md | Next: STORY-DNS-COREDNS-BASE.md
Sprint: 1 | Lane: Networking
Global Sequence: 03/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/gateway/

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
   - Specifies LoadBalancer IP via annotation: `${CILIUM_GATEWAY_LB_IP}`
   - Listeners configured for HTTP (80) and HTTPS (443)
   - TLS certificate reference configured

3. **Certificate Manifests Created:**
   - Wildcard certificate manifest exists
   - References cert-manager ClusterIssuer
   - Certificate namespace: `kube-system`
   - DNS names include wildcard (e.g., `*.${SECRET_DOMAIN}`)

4. **Cluster-Specific Configuration:**
   - Gateway IP substitution configured via `postBuild.substitute`
   - Infra gateway uses `10.25.11.110` (from cluster-settings)
   - Apps gateway uses `10.25.11.121` (from cluster-settings)
   - Certificate domains use `${SECRET_DOMAIN}` substitution

5. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/cilium/gateway/ks.yaml` exists
   - References all gateway manifests
   - Includes dependency on cilium-core and cert-manager
   - `kubernetes/infrastructure/networking/cilium/gateway/kustomization.yaml` glue file exists

6. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct IP substitution for each cluster
   - `kubeconform --strict` validates Gateway API manifests

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

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ ClusterIssuer deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  # Confirm gatewayAPI.enabled: true in values
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

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
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
    - name: cilium-ipam
    - name: cert-manager-issuers
    postBuild:
      substitute: {}
      substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
    healthChecks:
    - apiVersion: gateway.networking.k8s.io/v1
      kind: GatewayClass
      name: cilium
      namespace: ""
    - apiVersion: gateway.networking.k8s.io/v1
      kind: Gateway
      name: cluster-gateway
      namespace: kube-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/gateway/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/gateway
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster (should substitute 10.25.11.110)
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  # Expected: 10.25.11.110

  # Apps cluster (should substitute 10.25.11.121)
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "Gateway") | .spec.addresses[0].value'
  # Expected: 10.25.11.121
  ```

- [ ] Validate Gateway API schemas with kubeconform:
  ```bash
  kubeconform --strict kubernetes/infrastructure/networking/cilium/gateway/*.yaml
  ```

- [ ] Verify certificate domain substitution:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "Certificate") | .spec.dnsNames'
  # Expected: ["*.monosense.io", "monosense.io"] (or actual SECRET_DOMAIN)
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/networking/cilium/kustomization.yaml`:
  ```yaml
  resources:
  - core/ks.yaml
  - ipam/ks.yaml
  - gateway/ks.yaml  # ADD THIS LINE
  ```

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
