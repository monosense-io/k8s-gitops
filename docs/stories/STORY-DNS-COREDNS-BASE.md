# 04 — STORY-DNS-COREDNS-BASE — Create CoreDNS GitOps Manifests

Sequence: 04/50 | Prev: STORY-NET-CILIUM-GATEWAY.md | Next: STORY-SEC-EXTERNAL-SECRETS-BASE.md
Sprint: 1 | Lane: Networking
Global Sequence: 04/50

## Status
Approved (v3.1 QA-Aligned)
Owner: Platform Engineering
Date: 2025-10-27 (v3.1 QA-Aligned)
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
 - Local validation (kustomize build; optional flux build); OCI chart preflight
 - Add cluster-level Flux Kustomizations for CoreDNS in `kubernetes/clusters/{infra,apps}/infrastructure.yaml` with `dependsOn: cilium-core` and health checks

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

2. **OCIRepository Manifest Created (Preflighted):**
   - `kubernetes/infrastructure/networking/coredns/ocirepository.yaml` exists (or reuses existing)
   - References CoreDNS Helm chart from registry
   - Chart version: `1.38.0`
   - URL set (no placeholder) and basic preflight succeeds (chart metadata fetch or Flux source reconcile)

3. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/networking/coredns/prometheusrule.yaml` exists
   - Alert rules defined: CoreDNSAbsent, CoreDNSDown, CoreDNSHighErrorRate, CoreDNSLatencyHigh

4. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/coredns/kustomization.yaml` glue file exists (references all CoreDNS manifests)
   - Cluster-level Flux Kustomizations for CoreDNS added in `kubernetes/clusters/{infra,apps}/infrastructure.yaml` with `dependsOn: cilium-core` and healthCheck on HelmRelease/coredns

5. **Cluster Settings Alignment:**
   - Cluster-settings include CoreDNS variables:
     - Infra: `COREDNS_REPLICAS: "2"`, `COREDNS_CLUSTER_IP: "10.245.0.10"`
     - Apps: `COREDNS_REPLICAS: "2"`, `COREDNS_CLUSTER_IP: "10.247.0.10"`

6. **Local Validation Passes:**
  - `kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/` succeeds
  - `kustomize build kubernetes/infrastructure/networking/coredns` succeeds
  - Flux build inspection (if available) or cross-check with cluster-settings shows correct ClusterIP/replicas substitution
  - ClusterIP values belong to each cluster's Service CIDR
  - OCI chart source preflight succeeds (reachable URL, chart metadata available)
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

## Tasks / Subtasks

### T1: Verify Prerequisites (Local Validation Only) (AC5, AC6)

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
  ```

---

### T2: Create CoreDNS Manifests (AC1–AC4)

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/coredns
  ```

- [ ] Create `ocirepository.yaml` (chart source, aligns with Architecture §19 "Helm (OCI)"):
  ```yaml
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: OCIRepository
  metadata:
    name: coredns-charts
    namespace: flux-system
  spec:
    interval: 12h
    # MUST-SET BEFORE APPLY: Replace with the approved OCI registry URL for the CoreDNS chart (no placeholders allowed at commit time).
    # Example (adjust per org policy): oci://YOUR_REGISTRY/coredns
    url: oci://<APPROVED_REGISTRY>/coredns
    ref:
      semver: "1.38.0"
  ```

  - [ ] Must-Set (AC2): Confirm `spec.url` is set to an approved, reachable OCI URL and preflight succeeds (e.g., `helm show chart oci://<approved>/coredns --version 1.38.0`).

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
          kind: OCIRepository
          name: coredns-charts
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
        enabled: false  # Enable in Observability story when Prometheus CRDs exist
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

### T3: Optional — Component Kustomization CR (AC4)

- If your pattern uses component-scoped Flux Kustomizations checked into the component directory, you may create `kubernetes/infrastructure/networking/coredns/ks.yaml` (as a `Kustomization` manifest) similar to below. In this repo, cluster-level Kustomizations are preferred (see T5), so this step can be skipped.
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: coredns
    namespace: flux-system
  spec:
    interval: 10m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/coredns
    prune: true
    wait: true
    dependsOn:
      - name: cilium-core
    postBuild:
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
  ```

---

### T4: Local Validation (NO Cluster Access) (AC6)

- [ ] Validate manifest syntax (kustomize):
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/coredns
  ```

- [ ] Schema validation note: PrometheusRule and HelmRelease CRDs may be missing locally; when using `kubeconform`, add `--strict -ignore-missing-schemas` to avoid false negatives.

- [ ] Validate rendering and substitutions:
  - Option A (Flux offline build; requires Flux CLI supporting postBuild substitutions without cluster access):
    ```bash
    # Build CoreDNS kustomization (same path for both clusters; values come from postBuild.substituteFrom)
    flux build kustomization coredns --path ./kubernetes/infrastructure/networking/coredns | \
      yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.service.clusterIP'
    ```
  - Option B (Path-only check when offline):
    ```bash
    # Render manifests; verify placeholders present and cross-check cluster-settings separately
    kustomize build kubernetes/infrastructure/networking/coredns | \
      yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.service.clusterIP'
    # Then verify expected values in cluster settings
    yq '.data.COREDNS_CLUSTER_IP' kubernetes/clusters/infra/cluster-settings.yaml  # expect 10.245.0.10
    yq '.data.COREDNS_CLUSTER_IP' kubernetes/clusters/apps/cluster-settings.yaml  # expect 10.247.0.10
    ```

- [ ] Validate ClusterIP-in-CIDR for each cluster (offline-friendly):
  ```bash
  # Infra
  python3 - <<'PY'
import ipaddress
cidr = ipaddress.ip_network('10.245.0.0/16')
ip = ipaddress.ip_address('10.245.0.10')
assert ip in cidr, f"{ip} not in {cidr}"
print("infra ClusterIP in CIDR")
PY
  # Apps
  python3 - <<'PY'
import ipaddress
cidr = ipaddress.ip_network('10.247.0.0/16')
ip = ipaddress.ip_address('10.247.0.10')
assert ip in cidr, f"{ip} not in {cidr}"
print("apps ClusterIP in CIDR")
PY
  ```

- [ ] OCI chart preflight (one):
  ```bash
  # Option A (helm)
helm show chart oci://<APPROVED_REGISTRY>/coredns --version 1.38.0
  # Option B (flux)
  flux reconcile source oci coredns-charts --with-source --timeout 2m
  ```

- [ ] Verify replica count substitution:
  ```bash
  # Option A: Flux build (if available)
  flux build kustomization coredns --path ./kubernetes/infrastructure/networking/coredns | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.replicaCount'
  # Option B: Cross-check expected value in cluster settings
  yq '.data.COREDNS_REPLICAS' kubernetes/clusters/infra/cluster-settings.yaml  # expect 2
  ```

- [ ] Verify security context configuration:
  ```bash
  kustomize build kubernetes/infrastructure/networking/coredns | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "coredns") | .spec.values.securityContext'
  # Expected: runAsNonRoot: true, readOnlyRootFilesystem: true, capabilities.drop: [ALL]
  ```

---

### T5: Wire Into Cluster Infrastructure (AC4)

- [ ] Add a Flux Kustomization entry for CoreDNS to each cluster file.

  - File: `kubernetes/clusters/infra/infrastructure.yaml`
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: coredns
      namespace: flux-system
    spec:
      interval: 10m
      prune: true
      wait: true
      timeout: 5m
      sourceRef:
        kind: GitRepository
        name: flux-system
      path: ./kubernetes/infrastructure/networking/coredns
      dependsOn:
        - name: cilium-core
      postBuild:
        substituteFrom:
          - kind: ConfigMap
            name: cluster-settings
      healthChecks:
        - apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          name: coredns
          namespace: kube-system
    ```

  - File: `kubernetes/clusters/apps/infrastructure.yaml`
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: coredns
      namespace: flux-system
    spec:
      interval: 10m
      prune: true
      wait: true
      timeout: 5m
      sourceRef:
        kind: GitRepository
        name: flux-system
      path: ./kubernetes/infrastructure/networking/coredns
      dependsOn:
        - name: cilium-core
      postBuild:
        substituteFrom:
          - kind: ConfigMap
            name: cluster-settings
      healthChecks:
        - apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          name: coredns
          namespace: kube-system
    ```

  - [ ] Must-Set (AC4): Confirm both cluster files contain the CoreDNS Kustomization with:
    - `metadata.name: coredns`
    - `spec.path: ./kubernetes/infrastructure/networking/coredns`
    - `spec.dependsOn: [ { name: cilium-core } ]`
    - `healthChecks` including `HelmRelease/coredns` in `kube-system`

---

### T6: Update Cluster Settings (If Needed) (AC5)

- [ ] Verify infra cluster-settings have CoreDNS variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  COREDNS_REPLICAS: "2"
  COREDNS_CLUSTER_IP: "10.245.0.10"
  # Optional (enable when Prometheus CRDs present):
  # COREDNS_SERVICEMONITOR_ENABLED: "true"
  ```

- [ ] Verify apps cluster-settings have CoreDNS variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  COREDNS_REPLICAS: "2"
  COREDNS_CLUSTER_IP: "10.247.0.10"
  # Optional (enable when Prometheus CRDs present):
  # COREDNS_SERVICEMONITOR_ENABLED: "true"
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
  - Enable Prometheus metrics; include ServiceMonitor config (default disabled until CRDs present)
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
  - [ ] ServiceMonitor configuration present and default disabled (enable when Prometheus CRDs are available)
- [ ] PrometheusRule manifest created with alert rules
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Cluster-settings have CoreDNS variables (COREDNS_REPLICAS, COREDNS_CLUSTER_IP)
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds (syntax)
  - [ ] `flux build` inspection or cross-check against cluster-settings shows correct ClusterIP and replica substitution
  - [ ] ClusterIP belongs to Service CIDR for each cluster
  - [ ] OCI chart source preflight succeeds
  - [ ] Security context configuration verified in rendered output
  - [ ] OCIRepository `spec.url` committed without placeholders and points to approved registry (AC‑2)
- [ ] Infrastructure kustomization updated to include CoreDNS
  - [ ] Includes `dependsOn: [cilium-core]` and a `healthCheck` for `HelmRelease/coredns` in `kube-system`
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
| 2025-10-27 | 3.1     | **v3.1 QA-Aligned**: Set Status to Approved; added OCI chart preflight; gated ServiceMonitor (default disabled until Prometheus CRDs present); added ClusterIP-in-CIDR checks; clarified cluster-level Flux wiring; linked QA risk and test design; added navigation tips. | Product Owner |
| 2025-10-27 | 3.1.2   | **PO Course Correction (QA‑Aligned rev 3)**: Integrated QA risks and test design into PO Course Correction; clarified Must‑Fix (OCI URL preflight), cluster Kustomization wiring with healthChecks, schema/CI guidance; added QA references. | Product Owner |
| 2025-10-27 | 3.1.1   | **PO Course Correction**: Added `## Status` section; added Must‑Set for OCI URL and preflight; marked `ks.yaml` optional; added schema validation guidance and Service CIDR references; updated DoD to enforce approved OCI URL with preflight. | Product Owner |

---

## Dev Notes

- Sources of truth used in this story:
  - docs/architecture.md §8 (Cluster Settings & Substitution), §19 (Workloads & Versions → CoreDNS 1.38.0), and bootstrap flow references.
  - kubernetes/clusters/{infra,apps}/cluster-settings.yaml for `${COREDNS_CLUSTER_IP}` and `${COREDNS_REPLICAS}`.
  - kubernetes/clusters/{infra,apps}/infrastructure.yaml for Flux wiring pattern (`dependsOn: cilium-core`, health checks).
- Repository layout notes:
  - CoreDNS manifests live under `kubernetes/infrastructure/networking/coredns/`.
  - Cluster-level Flux Kustomizations are declared in `kubernetes/clusters/<cluster>/infrastructure.yaml` (no aggregate `kubernetes/infrastructure/networking/kustomization.yaml` exists).
- Chart source:
  - Architecture specifies Helm (OCI). This story creates `ocirepository.yaml` and points the HelmRelease `sourceRef` to it. Update the OCI URL to your approved registry prior to apply.
  - Service CIDRs (for ClusterIP checks): infra `10.245.0.0/16`, apps `10.247.0.0/16`.

- ServiceMonitor enablement:
  - Default is disabled to avoid CRD timing issues. Enable in the observability story (after Prometheus CRDs exist) or via a documented cluster-settings toggle.

### Navigation Tips

- CoreDNS component directory: `kubernetes/infrastructure/networking/coredns/`
- Cluster wiring locations (add these Kustomizations during implementation):
  - `kubernetes/clusters/infra/infrastructure.yaml` (Kustomization `coredns`, dependsOn `cilium-core`)
  - `kubernetes/clusters/apps/infrastructure.yaml` (Kustomization `coredns`, dependsOn `cilium-core`)

### Testing

- Validation methods to use locally:
  - Syntax: `kubectl --dry-run=client -f kubernetes/infrastructure/networking/coredns/` and `kustomize build ...`.
  - Render checks: `flux build kustomization coredns --path ./kubernetes/infrastructure/networking/coredns` (if available), or cross-check placeholders against values in cluster-settings using `yq`.
- CI alignment:
  - Ensure repo CI runs kubeconform/kustomize/flux build where applicable.
  - Add unit render checks for CoreDNS HelmRelease fields (replicaCount, service.clusterIP, securityContext) using `yq` filters.

---

## Dev Agent Record

### Agent Model Used

<record model/version>

### Debug Log References

- See `.ai/debug-log.md` if applicable.

### Completion Notes List

-

### File List

- kubernetes/infrastructure/networking/coredns/ocirepository.yaml
- kubernetes/infrastructure/networking/coredns/helmrelease.yaml
- kubernetes/infrastructure/networking/coredns/prometheusrule.yaml
 - kubernetes/infrastructure/networking/coredns/kustomization.yaml
 - (optional) kubernetes/infrastructure/networking/coredns/ks.yaml  # only if component-scoped Kustomization pattern is used
- kubernetes/clusters/infra/infrastructure.yaml (updated)
- kubernetes/clusters/apps/infrastructure.yaml (updated)

---

## PO Course Correction (2025-10-27, QA‑Aligned rev 3)

- Critical (Must Fix before gate = GO)
  - OCIRepository URL: Set `spec.url` in `kubernetes/infrastructure/networking/coredns/ocirepository.yaml` to an approved OCI registry (no placeholders) and preflight (helm show chart or Flux Source reconcile). Maps to QA risk TECH-001-OCI-URL (score 9).

- Should-Fix (Implementation under this story)
  - Cluster wiring: Append CoreDNS Flux Kustomizations to `kubernetes/clusters/{infra,apps}/infrastructure.yaml` with `dependsOn: [cilium-core]` and a HelmRelease `healthCheck` for `coredns`. Maps to QA WIRE-001-FLUX and WIRE-002-HEALTH.
  - File list alignment: Mark `coredns/ks.yaml` optional (component Kustomization is not the default pattern here).
  - Preflight fallback: If network restricted locally, document that the preflight reconcile will be executed when connectivity is available.

- Nice-to-Have (Quality/CI)
  - Schema validation note: Use `kubeconform --strict -ignore-missing-schemas` locally to avoid CRD-related false negatives (Prometheus/Helm CRDs). Maps to QA SCHEMA-001-CRDs.
  - CIDR/substitution checks: Add CI assertions that `${COREDNS_CLUSTER_IP}` is inside the Service CIDR per cluster and that `${COREDNS_REPLICAS}`/`${COREDNS_CLUSTER_IP}` substitutions render without placeholders. Maps to QA SUB-001-VALUES and CIDR checks.

QA References
- Risk profile: docs/qa/assessments/STORY-DNS-COREDNS-BASE-risk-20251027-183610.md (rev 3)
- Test design: docs/qa/assessments/STORY-DNS-COREDNS-BASE-test-design-20251027-183716.md (rev 3)

---

## QA Results

Risk profile created: docs/qa/assessments/STORY-DNS-COREDNS-BASE-risk-20251027-183610.md (rev 3)

```yaml
# risk_summary
risk_summary:
  totals: { critical: 1, high: 1, medium: 3, low: 1 }
  highest: { id: TECH-001-OCI-URL, score: 9, title: 'OCIRepository URL placeholder not set' }
  recommendations:
    must_fix:
      - 'Set approved OCI chart URL and preflight (helm show chart or Flux Source reconcile)'
      - 'Add cluster-level CoreDNS Kustomizations with dependsOn cilium-core'
    monitor:
      - 'Validate HA spread/PDB behavior during drain/rollout'
      - 'Enforce substitution and CIDR checks in CI'
```

Summary
- Gate signal: CONCERNS (one Critical, one High). Record `@qa *gate` decision after Must-Fix items are staged.

Test design created: docs/qa/assessments/STORY-DNS-COREDNS-BASE-test-design-20251027-183716.md (rev 3)

```yaml
test_design:
  scenarios_total: 18
  by_level: { unit: 0, integration: 18, e2e: 0 }
  by_priority: { p0: 8, p1: 8, p2: 2 }
  coverage_gaps: []
```
