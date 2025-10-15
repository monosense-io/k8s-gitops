# Priority Actions

## Critical Path (Next Steps)
1. **Story 1.3:** Bootstrap both Talos clusters (READY)
2. **Story 3.2 & 3.3:** Bootstrap Flux on both clusters (READY)
3. **Stories 10.1 & 10.3:** Implement VolSync + Velero (CRITICAL - ADR-004)
4. **Stories 8.1 & 8.2:** Deploy Keycloak (BLOCKER for apps)
5. **Story 2.4:** Deploy External-DNS (missing)

## Implementation Status Summary

**✅ Ready to Deploy (Config Complete):**
- Talos multi-cluster (1.1, 1.2)
- Cilium + BGP + ClusterMesh (2.1, 2.2, 2.3, 2.5)
- Flux structure (3.1)
- Rook Ceph (4.1, 4.2)
- OpenEBS (4.3)
- cert-manager (5.1)
- External Secrets (5.2)
- Victoria Metrics (6.1)
- Victoria Logs (6.2)
- Fluent-bit (6.3)
- CloudNativePG (7.1, 7.2)
- Dragonfly (7.4)
- GitLab (9.1)

**⚠️ Partially Complete:**
- Talos secrets (1.2 - may be in 1Password already)
- Remote Ceph access (4.5 - design unclear)

**❌ Critical Gaps:**
- **Backup & DR (EPIC-10)** - Violates ADR-004
- **Authentication (EPIC-8)** - Blocks applications
- **External-DNS (2.4)** - Missing from networking

**🔲 Not Started:**
- Cluster bootstrap deployment (1.3)
- Flux bootstrap (3.2, 3.3)
- Application databases (7.3)
- Harbor (9.2)
- Mattermost (9.3)
- All of EPIC-10

---
