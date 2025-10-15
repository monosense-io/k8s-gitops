# Definition of Done

A story is complete when:
- [ ] All acceptance criteria met
- [ ] All tasks completed
- [ ] Configuration files created and committed to git
- [ ] Manifests deployed to cluster (via Flux or kubectl)
- [ ] Services healthy and running (pods, health checks)
- [ ] Tests passed (manual or automated)
- [ ] Cross-cluster connectivity verified (if applicable)
- [ ] Documentation updated (inline comments, README)
- [ ] Peer reviewed (if applicable)
- [ ] No known bugs or issues

**Additional for Shared-Base Pattern:**
- [ ] Variables defined in `clusters/*/infrastructure.yaml`
- [ ] Kustomization references correct base paths
- [ ] Deployed to both clusters (if applicable)
- [ ] Cluster-specific behavior verified

---

*Implementation Epics & Stories - v2.0*
*Updated for Flux Multi-Cluster Shared-Base Pattern*
*41 Stories, 10 Epics, 10 Weeks*
*58% Config Complete | 0% Deployed*

---
