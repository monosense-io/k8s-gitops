# Risk Profile — STORY-BOOT-CORE (Phase 1 Core Bootstrap)

Date: 2025-10-21
Story: docs/stories/STORY-BOOT-CORE.md
Epic: Greenfield Multi‑Cluster GitOps on Talos
Owner: QA (Quinn)

## Summary
- Scope: Core bootstrap via Helmfile (Cilium, CoreDNS, External Secrets, cert-manager [CRDs disabled], Flux operator/instance) on infra + apps clusters.
- Assumptions: STORY‑BOOT‑CRDS completed; kube contexts available; egress allowed to registries and 1Password Connect host.
- Overall Risk Rating: Moderate
- Overall Story Risk Score: 51/100 (see algorithm)
- Suggested Gate Decision: CONCERNS (due to multiple High=6 risks)

## Risk Matrix

| Risk ID   | Category | Description                                                                             | Probability | Impact   | Score | Priority |
|-----------|----------|-----------------------------------------------------------------------------------------|-------------|----------|-------|----------|
| TECH-001  | TECH     | Phase ordering broken: CRDs absent or inline CRDs slip into core phase                 | Medium (2)  | High (3) | 6     | High     |
| OPS-002   | OPS      | Flux postsync fails to apply gotk-sync/patch; GitOps handover doesn’t start           | Medium (2)  | High (3) | 6     | High     |
| SEC-001   | SEC      | 1Password Connect bootstrap token misconfigured/invalid; External Secrets can’t sync  | Medium (2)  | High (3) | 6     | High     |
| SEC-002   | SEC      | External Secrets webhook/components not Ready → secret provisioning stalled            | Medium (2)  | Medium(2)| 4     | Medium   |
| OPS-003   | OPS      | Network egress blocked to registries/1Password host                                    | Medium (2)  | Medium(2)| 4     | Medium   |
| PERF-001  | PERF     | Controller resource limits too low → restarts/latency                                  | Medium (2)  | Medium(2)| 4     | Medium   |
| SEC-003   | SEC      | cert-manager controller/webhook not Ready → issuers fail later                         | Low (1)     | High (3) | 3     | Low      |
| OPS-001   | OPS      | CoreDNS clusterIP conflict or Service CIDR mismatch                                    | Low (1)     | High (3) | 3     | Low      |
| TECH-003  | TECH     | Cilium rollout issues on Talos/kernel nuance (eBPF features gated)                     | Low (1)     | High (3) | 3     | Low      |
| BUS-001   | BUS      | Bootstrap overruns sprint due to retries/backoff                                       | Low (1)     | Medium(2)| 2     | Low      |

## Mitigations & Controls
- TECH-001: Enforce phase check in CI; run `helmfile -f 01-core.yaml.gotmpl template | yq ... CRD | wc -l == 0`. Keep CRDs only in 00‑crds.
- OPS-002: Pre-validate presence of `kubernetes/clusters/<ctx>/flux-system/gotk-sync.yaml`; verify postsync logs; fallback to applying gotk-sync manually if needed.
- SEC-001: Validate `onepassword-connect` Secret populated; can `kubectl -n external-secrets get secret onepassword-connect`; smoke-test an ExternalSecret after core.
- SEC-002: Add rollout waits for `external-secrets`, `webhook`, and cert controller; include health checks in Flux Kustomizations (day‑2).
- OPS-003: Preflight curl to registry hosts and `ONEPASSWORD_CONNECT_HOST`; add FQDN egress allowlists if policies apply.
- PERF-001: Start with documented resource requests; monitor pods for throttling/restarts; tune in day‑2 via Flux.
- SEC-003: Add `kubectl rollout status` for cert-manager/webhook (already in story AC); ensure CRDs came from Phase 0.
- OPS-001: Confirm Service CIDR/clusterIP from cluster-settings; ensure no collision with Talos defaults.
- TECH-003: Use known-good Cilium version (1.18.3); verify `cilium status` after rollout.

## Risk-Based Testing Strategy
- Priority 1 (High risks)
  - Phase-guard test: zero CRDs emitted by 01-core templating.
  - Handover test: `flux get sources git flux-system` and `flux get kustomizations -A` become Ready within timeout.
  - Secret store smoke: create a simple ExternalSecret in `external-secrets` namespace and verify pull.
- Priority 2 (Medium risks)
  - Egress checks: curl/HEAD against registry endpoints and `ONEPASSWORD_CONNECT_HOST`.
  - Resource pressure: watch pod restarts and latency; adjust limits if needed.
- Priority 3 (Low risks)
  - CoreDNS clusterIP verification; cert-manager webhook availability checks; `cilium status`.

## Monitoring Requirements
- Alerts: Flux (source/kustomization failures), cert-manager (webhook/controller), External Secrets sync failures.
- Metrics: pod restarts, CPU/memory for controllers; Cilium DS/Operator health.
- Logs: postsync hook output; External Secrets operator; cert-manager controller/webhook.

## Residual Risk & Acceptance
- Residual risk after mitigations: Moderate.
- Must-fix prior to calling story Done: Any High (score 6) that fails validation must be addressed or waived explicitly.

## Risk Scoring Algorithm Application
- Base Score: 100
- High (6): 3 × 10 = 30
- Medium (4): 3 × 5 = 15
- Low (2–3): 2 × 2 = 4
- Total Deduction: 49 → Overall Score: 51/100

## Suggested Gate Mapping
- Highest risk score present: 6 → Suggested Gate: CONCERNS (until high-risk validations pass).

---

Risk profile: docs/qa/assessments/STORY-BOOT-CORE-risk-20251021.md
