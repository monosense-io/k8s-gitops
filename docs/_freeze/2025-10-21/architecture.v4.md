<!-- Frozen snapshot: 2025-10-21 → mirrors docs/architecture.md at commit time -->

# 🏗️ Multi-Cluster GitOps Architecture (v4)

<div align="center">

![Status](https://img.shields.io/badge/Status-Implementing-blue)
![Owner](https://img.shields.io/badge/Owner-Platform_Engineering-orange)
![Last Updated](https://img.shields.io/badge/Updated-2025--10--21-green)
![Version](https://img.shields.io/badge/Version-4.0-purple)

**Modern cloud-native platform built on Talos Linux • GitOps-powered • Multi-cluster**

</div>

---

<!--
NOTE: This frozen file intentionally inlines the same content as docs/architecture.md
at the time of freeze (2025-10-21) so historical references remain stable.
-->

{{
  /* The snapshot is a verbatim copy of docs/architecture.md on 2025-10-21. */
}}

> Refer to `docs/architecture.md` for the live document. This frozen version is retained for auditability of decisions and version tables as of 2025-10-21, including the DragonflyDB operator & cluster additions (Appendix B.9) and Workloads & Versions updates.

> Note (CNPG Cron Format): CloudNativePG `ScheduledBackup` expects a six-field cron expression (seconds first). Use values like `"0 0 2 * * *"` for 02:00:00 UTC. This clarifies earlier examples that used five-field crons for generic contexts.

---

## Addendum — DNS, ExternalDNS, and Cloudflare Tunnel (Recorded 2025-10-22)

This addendum records research and the selected pattern as of 2025-10-22 without altering the original 2025-10-21 snapshot:

- Two ExternalDNS controllers: Cloudflare for public zone under `SECRET_DOMAIN`; RFC2136 to BIND for private LAN zone.
- Cloudflared named tunnel with ≥2 replicas, QUIC transport, readiness/metrics endpoints, and minimal wildcard ingress.
- One-time Cloudflare DNS anchor `external.${SECRET_DOMAIN}` CNAME to `<TUNNEL-UUID>.cfargotunnel.com` (proxied). Per-app hostnames are CNAMEs to this anchor via ExternalDNS and Gateway annotations.
- TXT registry with distinct owner IDs and optional `--txt-prefix=k8s.` to prevent record contention across controllers.

Implementation details are maintained in the live document at docs/architecture.md §23.
