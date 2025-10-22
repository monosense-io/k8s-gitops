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
