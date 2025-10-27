# 04 — STORY-DNS-COREDNS-BASE — Create CoreDNS GitOps Manifests

Sequence: 04/50 | Prev: STORY-NET-CILIUM-GATEWAY.md | Next: STORY-SEC-EXTERNAL-SECRETS-BASE.md
Sprint: 1 | Lane: Networking
Global Sequence: 04/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/coredns/

---

## Story

As a platform engineer, I want to **create CoreDNS GitOps manifests** with HA configuration, security hardening, and observability integration, so that when deployed in Story 45, clusters have reliable DNS resolution with proper monitoring and resilience.

This story creates the declarative CoreDNS manifests (HelmRelease, OCIRepository, PrometheusRule, ServiceMonitor). Actual deployment and DNS validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create CoreDNS manifests with cluster-specific replicas and ClusterIP settings
- Configure HA topology spread and PodDisruptionBudget
- Enable security hardening (non-root, read-only filesystem, capabilities dropped)
- Enable observability (Prometheus metrics, health/ready endpoints)
- Foundation for cluster DNS resolution

## Scope

**This Story (Manifest Creation):**
- Create CoreDNS manifests in `kubernetes/infrastructure/networking/coredns/`
- Create HelmRelease with HA and security configuration
- Create OCIRepository for CoreDNS Helm chart
- Create PrometheusRule for DNS alerting
- Create Kustomization for CoreDNS resources
- Update cluster-settings with CoreDNS variables (if needed)
- Local validation (flux build, helmfile template)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying CoreDNS to clusters
- Verifying DNS resolution (internal/external/pod)
- Testing HA resilience (rolling updates, node drains)
- Validating metrics scraping
- Network policy enforcement testing

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/infrastructure/networking/coredns/helmrelease.yaml` exists
   - CoreDNS version: `1.38.0` (chart tag)
   - Replicas configured via `${COREDNS_REPLICAS}` substitution
   - ClusterIP configured via `${COREDNS_CLUSTER_IP}` substitution
   - HA topology spread constraints configured
   - PodDisruptionBudget enabled (minAvailable: 1)
   - Resource limits defined (CPU: 200m, Memory: 256Mi)
   - Security context hardened (non-root, read-only filesystem, capabilities dropped)
   - Health/ready probes configured (health: 8080, ready: 8181, metrics: 9153)

2. **OCIRepository Manifest Created:**
   - `kubernetes/infrastructure/networking/coredns/ocirepository.yaml` exists (or reuses existing)
   - References CoreDNS Helm chart from registry
   - Chart version: `1.38.0`

3. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/networking/coredns/prometheusrule.yaml` exists
   - Alert rules defined: CoreDNSAbsent, CoreDNSDown, CoreDNSHighErrorRate, CoreDNSLatencyHigh

4. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/coredns/ks.yaml` exists
   - References all CoreDNS manifests
   - Includes dependency on cilium-core
   - `kubernetes/infrastructure/networking/coredns/kustomization.yaml` glue file exists

5. **Cluster Settings Alignment:**
   - Cluster-settings include CoreDNS variables:
     - Infra: `COREDNS_REPLICAS: "2"`, `COREDNS_CLUSTER_IP: "10.245.0.10"`
     - Apps: `COREDNS_REPLICAS: "2"`, `COREDNS_CLUSTER_IP: "10.247.0.10"`

6. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct ClusterIP substitution for each cluster
   - `helmfile template` renders CoreDNS chart successfully
   - Security context verification shows hardened configuration

**Deferred to Story 45 (Deployment & Validation):**
- ❌ CoreDNS pods running and ready
- ❌ DNS resolution working (internal/external/pod)
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Health/ready endpoints responding
- ❌ HA resilience validated (rolling updates, node drains)
- ❌ Network policies enforced
- ❌ Alert rules loaded in Prometheus

---

## Dependencies

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium core manifests created)
- Cluster-settings ConfigMaps with `COREDNS_REPLICAS` and `COREDNS_CLUSTER_IP`
- Tools: kubectl (for dry-run), flux CLI, helmfile, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ VictoriaMetrics deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  ```

- [ ] Verify cluster-settings have CoreDNS variables:
  ```bash
  grep -E 'COREDNS_(REPLICAS|CLUSTER_IP)' kubernetes/clusters/infra/cluster-settings.yaml
  grep -E 'COREDNS_(REPLICAS|CLUSTER_IP)' kubernetes/clusters/apps/cluster-settings.yaml
  ```

- [ ] Check existing CoreDNS manifests (if any):
  ```bash
  ls -la kubernetes/infrastructure/networking/coredns/ 2>/dev/null || echo "Directory not found (will create)"
  ls -la kubernetes/bases/coredns/ 2>/dev/null || echo "Directory not found (will create)"
  ```

---

### T2: Create CoreDNS Manifests

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/coredns
  ```

- [ ] Create `helmrelease.yaml` with HA and security configuration:
  ```yaml
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: coredns
    namespace: kube-system
  spec:
    interval: 30m
    chart:
      spec:
        chart: coredns
        version: 1.38.0
        sourceRef:
          kind: HelmRepository
          name: coredns
          namespace: flux-system
    install:
      remediation:
        retries: 3
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
    values:
      replicaCount: ${COREDNS_REPLICAS}

      service:
        name: kube-dns
        clusterIP: ${COREDNS_CLUSTER_IP}

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              k8s-app: kube-dns

      podDisruptionBudget:
        enabled: true
        minAvailable: 1

      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL

      livenessProbe:
        httpGet:
          path: /health
          port: 8080
        initialDelaySeconds: 60
        periodSeconds: 10

      readinessProbe:
        httpGet:
          path: /ready
          port: 8181
        initialDelaySeconds: 5
        periodSeconds: 10

      prometheus:
        service:
          enabled: true
          annotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "9153"

      serviceMonitor:
        enabled: true
  ```

- [ ] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: coredns
    namespace: kube-system
  spec:
    groups:
      - name: coredns
        interval: 30s
        rules:
          - alert: CoreDNSAbsent
            expr: absent(up{job="coredns"})
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "CoreDNS metrics absent"
              description: "CoreDNS metrics have been absent for 5 minutes"

          - alert: CoreDNSDown
            expr: up{job="coredns"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "CoreDNS is down"
              description: "CoreDNS pod {{ $labels.pod }} is down"

          - alert: CoreDNSHighErrorRate
            expr: rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]) > 0.05
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "CoreDNS high error rate"
              description: "CoreDNS error rate above 5% for 10 minutes"

          - alert: CoreDNSLatencyHigh
            expr: histogram_quantile(0.99, rate(coredns_dns_request_duration_seconds_bucket[5m])) > 1
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "CoreDNS high latency"
              description: "CoreDNS p99 latency above 1s for 10 minutes"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
    - prometheusrule.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: coredns
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/coredns
    prune: true
    wait: true
    dependsOn:
      - name: cilium-core
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: coredns
        namespace: kube-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/coredns
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster (should substitute 10.245.0.10)
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.service.clusterIP'
  # Expected: 10.245.0.10

  # Apps cluster (should substitute 10.247.0.10)
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.service.clusterIP'
  # Expected: 10.247.0.10
  ```

- [ ] Verify replica count substitution:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.replicaCount'
  # Expected: 2
  ```

- [ ] Verify security context configuration:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.securityContext'
  # Expected: runAsNonRoot: true, readOnlyRootFilesystem: true, capabilities.drop: [ALL]
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/networking/kustomization.yaml` (or appropriate parent):
  ```yaml
  resources:
    - cilium/
    - coredns/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have CoreDNS variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  COREDNS_REPLICAS: "2"
  COREDNS_CLUSTER_IP: "10.245.0.10"
  ```

- [ ] Verify apps cluster-settings have CoreDNS variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  COREDNS_REPLICAS: "2"
  COREDNS_CLUSTER_IP: "10.247.0.10"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMaps

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/coredns/
  git commit -m "feat(dns): add CoreDNS GitOps manifests

  - Create HelmRelease with HA topology spread and PDB
  - Configure security hardening (non-root, read-only filesystem)
  - Enable Prometheus metrics and ServiceMonitor
  - Create PrometheusRule for DNS alerting
  - Configure cluster-specific replicas and ClusterIP
  - Add health/ready probe configuration

  Part of Story 04 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy CoreDNS (Story 45 only)
flux reconcile kustomization coredns --with-source

# Verify deployment
kubectl get deploy,pdb,svc -n kube-system -l k8s-app=kube-dns

# Test DNS resolution - internal
kubectl run dns-test --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local

# Test DNS resolution - external
kubectl run dns-test --rm -it --image=busybox --restart=Never -- nslookup example.com

# Verify metrics
kubectl port-forward -n kube-system deploy/coredns 9153:9153
curl http://localhost:9153/metrics | grep coredns_dns_requests_total

# Verify health/ready endpoints
kubectl port-forward -n kube-system deploy/coredns 8080:8080 8181:8181
curl http://localhost:8080/health
curl http://localhost:8181/ready

# Test HA resilience - rolling update
kubectl -n kube-system rollout restart deployment coredns
# Continuously test DNS resolution during rollout (should have zero failures)

# Test HA resilience - node drain
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# PDB should prevent draining last replica, DNS should continue working
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/networking/coredns/`
- [ ] HelmRelease manifest created with:
  - [ ] CoreDNS version 1.38.0
  - [ ] Cluster-specific replicas and ClusterIP substitution
  - [ ] HA topology spread constraints
  - [ ] PodDisruptionBudget (minAvailable: 1)
  - [ ] Resource limits defined
  - [ ] Security context hardened
  - [ ] Health/ready probes configured
  - [ ] Prometheus metrics enabled
  - [ ] ServiceMonitor enabled
- [ ] PrometheusRule manifest created with alert rules
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Cluster-settings have CoreDNS variables (COREDNS_REPLICAS, COREDNS_CLUSTER_IP)
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct ClusterIP substitution for both clusters
  - [ ] Security context configuration verified in rendered output
- [ ] Infrastructure kustomization updated to include CoreDNS
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ CoreDNS pods running and ready
- ❌ DNS resolution working (internal/external/pod)
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Health/ready endpoints responding
- ❌ HA resilience validated (rolling updates, node drains)
- ❌ Network policies enforced
- ❌ Alert rules loaded in Prometheus
- ❌ Integration testing with Spegel, cert-manager

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Removed extensive runtime validation sections. | Platform Engineering |
