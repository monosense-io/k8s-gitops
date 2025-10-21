# Runbook — Bootstrapping a Fresh Cluster from Zero (Talos → Core → Flux)

Last Updated: 2025-10-21

Audience: Platform Engineers

Overview
- This runbook uses Taskfiles only. No ad‑hoc kubectl/helmfile/flux commands.

Prereqs
- Tools installed: talosctl, kubectl, flux, helmfile, minijinja-cli, op, jq, yq
- Talos patches exist under `talos/<cluster>/*.yaml` and are correct for your nodes.

Steps (per cluster)
1) Preflight
   - `task cluster:preflight CLUSTER=<infra|apps>`

2) Talos bring‑up (Phase −1)
   - `task bootstrap:talos CLUSTER=<infra|apps>`

3) Kubernetes readiness
   - `task :cluster:layer:2-kubernetes CLUSTER=<infra|apps> CONTEXT=<infra|apps>`

4) CRDs and Core (Phases 0–2)
   - `task :bootstrap:phase:0 CLUSTER=<cluster> CONTEXT=<cluster>`
   - `task :bootstrap:phase:1 CLUSTER=<cluster> CONTEXT=<cluster>`
   - `task :bootstrap:phase:2 CLUSTER=<cluster> CONTEXT=<cluster>`

5) Validation (Phase 3)
   - `task :bootstrap:phase:3 CLUSTER=<cluster> CONTEXT=<cluster>`
   - `task bootstrap:status CLUSTER=<cluster> CONTEXT=<cluster>`

6) Handover to GitOps
   - Confirm `flux get kustomizations -A --context=<cluster>` shows Ready.

Troubleshooting
- Talos API not ready: rerun Talos health, check network, verify IPs and patches.
- CRDs missing: re-run Phase 1; verify chart versions in `bootstrap/helmfile.d/00-crds.yaml`.
- Flux not Ready: run `task kubernetes:bootstrap CLUSTER=<cluster>` if needed, then reconcile.

Control-Plane-Only Cluster Resource Considerations
This lab runs control-plane-only clusters (no dedicated worker nodes) due to hardware constraints. This section documents resource limits, monitoring requirements, and scaling considerations.

Resource Constraints
- Control plane nodes run both system and application workloads
- Limited CPU/Memory headroom compared to dedicated worker architecture
- Typical CP node allocation:
  - etcd: 2GB memory, 100m-1000m CPU (variable under load)
  - kube-apiserver: 2GB memory, 250m CPU
  - kube-controller-manager: 200m CPU, 512Mi memory
  - kube-scheduler: 100m CPU, 128Mi memory
  - Remaining capacity for workloads: ~50-60% of node resources

Monitoring and Pressure Guardrails
Monitor these metrics to detect resource pressure:
1. Node CPU/Memory utilization (target: <70% sustained)
   - Check: `kubectl top nodes`
   - Alert threshold: >80% for 10+ minutes
2. etcd health and latency
   - Check: `talosctl --nodes <cp-node> etcd status`
   - Alert threshold: >100ms commit latency
3. Pod evictions and OOMKills
   - Check: `kubectl get events -A --field-selector reason=Evicted`
   - Alert threshold: Any pod evictions

Resource Pressure Mitigation
If resource pressure detected:
1. Review pod resource requests/limits (may be over-provisioned)
2. Scale down non-critical workloads
3. Enable horizontal pod autoscaling with conservative limits
4. Consider adding worker nodes (see "Adding Worker Nodes" below)

Recommended Resource Limits (per namespace)
- System namespaces (kube-system, flux-system): No hard limits
- Platform services (cert-manager, external-secrets): 2Gi memory, 1 CPU total
- Observability (victoria-metrics, grafana): 4Gi memory, 2 CPU total
- Databases (cnpg-system): 8Gi memory, 4 CPU total (adjust per workload)
- Application namespaces: Set LimitRange to prevent runaway pods

Adding Worker Nodes (Future Extension)
When workload demands exceed CP capacity:
1. Create worker node configs in `talos/<cluster>/worker/`
2. Apply worker configs after CP bootstrap:
   ```bash
   task :talos:apply-node NODE=<worker-node> CLUSTER=<cluster> MACHINE_TYPE=worker
   ```
3. Update resource limits to take advantage of worker capacity
4. Migrate non-system workloads to workers using node selectors/taints

Reference Baseline (3-node CP cluster post-bootstrap)
- Total cluster capacity: ~12Gi memory, ~6 CPU (3 nodes × 4Gi/2CPU)
- System workload consumption: ~4-5Gi memory, ~2-3 CPU
- Available for applications: ~7-8Gi memory, ~3-4 CPU
- Safe concurrent workload count: 10-15 lightweight services

