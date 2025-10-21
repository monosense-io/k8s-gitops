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

