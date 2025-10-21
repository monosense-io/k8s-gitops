Title: Align observability to single namespace `observability` (remove `monitoring` namespace)

Summary
- Replace any remaining namespace references of `monitoring` with `observability` across configs.
- Update VMAgent write_relabel_configs to drop only `kube-system|observability` (removed `monitoring`).
- Ensure security/compliance ConfigMaps live in `observability`.

Changes
- kubernetes/components/monitoring/multi-cluster/vmagent-remote-write.yaml
  - Drop rules updated: `namespace` value regex now `kube-system|observability`.
  - Fixed YAML indentation in `namespaces:` blocks and labeldrop vs drop usage.
- kubernetes/infrastructure/security/security-observability-architecture.yaml
  - `security-integrations` ConfigMap namespace → `observability`.
- kubernetes/infrastructure/security/compliance-monitoring.yaml
  - `compliance-automation` and `audit-trail-management` ConfigMaps namespace → `observability`.

Validation
- YAML parse: OK (376 files, 0 failures).
- Grep checks:
  - No `namespace: monitoring` remains.
  - No `.monitoring.svc` FQDNs remain.
  - CRD group `monitoring.coreos.com` untouched (intentional).

Impact
- All observability components now deploy to `observability`.
- No change to label keys using "monitoring" as a component descriptor.

Rollout Notes
- If a legacy `monitoring` namespace exists in clusters, it can be cleaned up after Flux applies the new state and no objects remain in that namespace.
- Validate dashboards and rules after apply; Grafana datasources already target `observability` endpoints.

Linked Story / Gate
- Story: docs/stories/STORY-BOOT-TALOS.md (context: observability stack readiness via CRDs/core)
- Gate: docs/qa/gates/EPIC-greenfield-multi-cluster-gitops.STORY-BOOT-TALOS-boot-talos.yml (PASS)

