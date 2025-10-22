# 41 — STORY-OPS-RELOADER-ALL-CLUSTERS — Stakater Reloader on All Clusters

Sequence: 41/41 | Prev: STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL.md | Next: —
Sprint: 1 | Lane: Bootstrap & Platform
Global Sequence: 6/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §23; docs/stories/STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL.md

## Story
Deploy Stakater Reloader to all clusters (infra and apps-family) as a baseline ops utility to roll pods automatically when ConfigMaps/Secrets change. This supports secrets rotated by External Secrets (Cloudflare API token, TSIG keys, Tunnel token) and reduces manual restarts.

## Why / Outcome
- Automatic rollouts on config/secret changes, minimizing toil and outage windows.
- Enables fully automated cred rotation for cloudflared and ExternalDNS.

## Scope
- Install the Reloader Helm chart (OCI) into `kube-system` on all clusters.
- Expose PodMonitor for observability.
- No app annotations changed in this story; dependent stories (e.g., DNS) will set `reloader.stakater.com/auto: "true"` where needed.

## Acceptance Criteria
1) Deployment `reloader` Available in `kube-system` on infra and apps clusters (and apps-dev/stg/prod if enabled).
2) PodMonitor present and scraping on both clusters.
3) Manual test: update a dummy ConfigMap and verify annotated test Deployment restarts within 1 minute.

## Dependencies / Inputs
- Flux operational on target clusters.
- Monitoring stack present to scrape PodMonitor (optional for AC2).

## Tasks / Subtasks
- [ ] Add manifests under `kubernetes/workloads/platform/system/reloader/app/helmrelease.yaml` (OCIRepository + HelmRelease).
- [ ] Add `kubernetes/workloads/platform/system/reloader/ks.yaml` and `kubernetes/workloads/platform/system/kustomization.yaml`.
- [ ] Update `kubernetes/workloads/platform/kustomization.yaml` to include `system`.
- [ ] Reconcile clusters and validate ACs.

## Draft Manifests (for commit upon approval)

### A) Reloader (HelmRelease + OCIRepository)
`kubernetes/workloads/platform/system/reloader/app/helmrelease.yaml`
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: reloader
  namespace: kube-system
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: 2.2.3
  url: oci://ghcr.io/stakater/charts/reloader
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: reloader
  namespace: kube-system
spec:
  chartRef:
    kind: OCIRepository
    name: reloader
    namespace: kube-system
  interval: 1h
  install:
    remediation:
      retries: 2
    createNamespace: true
  upgrade:
    remediation:
      retries: 2
      strategy: rollback
    cleanupOnFail: true
  rollback:
    recreate: true
    cleanupOnFail: true
  values:
    fullnameOverride: reloader
    reloader:
      readOnlyRootFileSystem: true
      podMonitor:
        enabled: true
        namespace: kube-system
```

### B) Kustomize wiring (platform/system)
`kubernetes/workloads/platform/system/reloader/ks.yaml`
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: reloader
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/workloads/platform/system/reloader/app
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: kube-system
```

`kubernetes/workloads/platform/system/kustomization.yaml`
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - reloader
```

Update aggregator to include `system`:
`kubernetes/workloads/platform/kustomization.yaml`
```diff
 resources:
   - observability
   - databases
   - cicd
   - mesh-demo
+  - system
```

## Validation Steps
- flux -n flux-system --context=infra reconcile ks cluster-infra-workloads --with-source
- flux -n flux-system --context=apps reconcile ks cluster-apps-workloads --with-source
- kubectl --context=infra -n kube-system get deploy reloader
- kubectl --context=apps -n kube-system get deploy reloader
- Verify PodMonitor present; check metrics in Prometheus.

## Definition of Done
- ACs pass on all target clusters; reloader stays healthy; linked DNS story may add annotations to its Deployments.
