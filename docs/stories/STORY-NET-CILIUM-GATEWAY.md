# 04 — STORY-NET-CILIUM-GATEWAY — Gateway API with Cilium

Sequence: 04/41 | Prev: STORY-NET-CILIUM-IPAM.md | Next: STORY-DNS-COREDNS-BASE.md
Sprint: 1 | Lane: Networking
Global Sequence: 4/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/gateway

---

## 🎯 Quick Start (Greenfield)

**Prerequisites**: STORY-NET-CILIUM-IPAM (03/41) complete, bootstrap Phase 1 & 2 done
**Estimated Time**: 2-3 hours
**Key Deliverable**: Working Gateway with TLS + echo test

---

## Story

Expose L7 HTTP(S) traffic using Gateway API implemented by Cilium, managed by Flux, with a default GatewayClass and a cluster Gateway per environment.

## Why / Outcome

- Standards‑based traffic management (Gateway API) with Cilium dataplane
- Git‑managed routing, TLS termination delegated to cert‑manager issuers
- High-performance eBPF-based L7 routing with near bare-metal performance
- Foundation for advanced traffic policies (rate limiting, timeouts, retries)

## Scope

- **Clusters**: infra, apps
- **Resources**: `kubernetes/infrastructure/networking/cilium/gateway/*`
- **Gateway controller**: Enabled via Cilium Helm values in bootstrap phase

---

## Acceptance Criteria

1. **CRD Presence**: Gateway API CRDs installed and Ready
2. **GatewayClass Ready**: `cilium` GatewayClass Accepted=True
3. **Gateway Programmed**: `cluster-gateway` in `kube-system` with Programmed=True
4. **Correct IPs**: Infra `10.25.11.110`, Apps `10.25.11.121`
5. **BGP Advertisement**: Gateway IPs advertised via BGP
6. **HTTP Reachability**: `curl http://<GATEWAY-IP>` responds
7. **TLS Certificate**: Wildcard cert Ready
8. **E2E Test**: Echo HTTPRoute working

---

## Dependencies

- **STORY-NET-CILIUM-IPAM**: IPAM pools with cluster isolation
- **STORY-SEC-CERT-MANAGER-ISSUERS**: ClusterIssuer ready
- **Bootstrap Phase 1 & 2**: Cilium with `gatewayAPI.enabled: true`

---

## Implementation Tasks

### Phase 1: Prerequisites (5 tasks, 10 min)

- [ ] Verify IPAM pools deployed:
  ```bash
  kubectl --context=infra get ciliumloadbalancerippool -A
  kubectl --context=apps get ciliumloadbalancerippool -A
  ```

- [ ] Verify Gateway API CRDs installed:
  ```bash
  kubectl --context=infra get crd gateways.gateway.networking.k8s.io
  ```

- [ ] Verify Gateway controller running:
  ```bash
  kubectl --context=infra -n kube-system logs -l app.kubernetes.io/name=cilium-operator --tail=50 | grep -i gateway
  ```

- [ ] Verify cert-manager ClusterIssuer Ready:
  ```bash
  kubectl --context=infra get clusterissuer letsencrypt-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
  # Expected: True
  ```

- [ ] Verify cluster-settings have correct Gateway IPs:
  ```bash
  # Infra: 10.25.11.110
  kubectl --context=infra -n flux-system get cm cluster-settings -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}'
  # Apps: 10.25.11.121
  kubectl --context=apps -n flux-system get cm cluster-settings -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}'
  ```

---

### Phase 2: Create Manifests (5 tasks, 20 min)

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

- [ ] Create `kustomization.yaml`:
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

### Phase 3: Flux Wiring (2 tasks, 10 min)

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

- [ ] Validate manifests:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/gateway
  ```

---

### Phase 4: Deploy & Validate (7 tasks, 30 min)

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/gateway/
  git commit -m "feat(networking): add Cilium Gateway API resources"
  git push origin main
  ```

- [ ] Monitor Flux reconciliation:
  ```bash
  flux get kustomizations -n flux-system --context=infra --watch
  # Wait for cilium-gateway Applied/True
  ```

- [ ] Verify GatewayClass Accepted:
  ```bash
  kubectl --context=infra get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'
  # Expected: True
  ```

- [ ] Verify Gateway Programmed:
  ```bash
  kubectl --context=infra get gateway -n kube-system cluster-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
  # Expected: True
  ```

- [ ] Verify Gateway IP allocation:
  ```bash
  kubectl --context=infra get gateway -n kube-system cluster-gateway -o jsonpath='{.status.addresses[0].value}'
  # Expected: 10.25.11.110 (infra) or 10.25.11.121 (apps)
  ```

- [ ] Test HTTP reachability:
  ```bash
  curl -v http://10.25.11.110
  # Expected: Connection succeeds, 404 response
  ```

- [ ] Verify Certificate Ready:
  ```bash
  kubectl --context=infra -n kube-system get certificate wildcard-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
  # Expected: True
  ```

---

### Phase 5: E2E Test (6 tasks, 30 min)

- [ ] Create `httproute-echo.yaml`:
  ```yaml
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: testing
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: http-echo
    namespace: testing
  spec:
    selector:
      app: http-echo
    ports:
    - port: 8080
      targetPort: 8080
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: http-echo
    namespace: testing
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: http-echo
    template:
      metadata:
        labels:
          app: http-echo
      spec:
        containers:
        - name: echo
          image: ealen/echo-server:latest
          ports:
          - containerPort: 8080
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: echo-route
    namespace: testing
  spec:
    parentRefs:
    - name: cluster-gateway
      namespace: kube-system
    hostnames:
    - "echo.${SECRET_DOMAIN}"
    rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
      - name: http-echo
        port: 8080
  ```

- [ ] Add to kustomization:
  ```yaml
  # Edit kubernetes/infrastructure/networking/cilium/gateway/kustomization.yaml
  resources:
  - gatewayclass.yaml
  - gateway.yaml
  - certificate.yaml
  - httproute-echo.yaml
  ```

- [ ] Commit and deploy:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/gateway/
  git commit -m "test(networking): add echo HTTPRoute for Gateway validation"
  git push origin main
  ```

- [ ] Wait for echo pod ready:
  ```bash
  kubectl --context=infra -n testing get pods -l app=http-echo --watch
  ```

- [ ] Verify HTTPRoute attached:
  ```bash
  kubectl --context=infra -n testing get httproute echo-route -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
  # Expected: True
  ```

- [ ] Test routing (PROOF):
  ```bash
  curl -H "Host: echo.monosense.io" http://10.25.11.110
  # Expected: Echo service response
  # Save output as proof
  ```

---

## Definition of Done

- [ ] Both clusters: Gateway Programmed=True
- [ ] Correct IPs: infra .110, apps .121
- [ ] BGP advertising Gateway IPs
- [ ] HTTP/HTTPS reachable
- [ ] Certificate Ready
- [ ] Echo HTTPRoute working
- [ ] Flux Kustomization healthy
- [ ] Test evidence captured

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
