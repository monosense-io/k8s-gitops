# 45 — STORY-VALIDATE-NETWORKING — Deploy & Validate All Manifests (Full Stack)

Sequence: 45/50 | Prev: STORY-BOOT-CORE.md | Next: STORY-VALIDATE-STORAGE-OBSERVABILITY.md
Sprint: 8 | Lane: Deployment & Validation
Global Sequence: 45/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md; docs/SCHEDULE-V2-GREENFIELD.md; Stories 1-44 (all manifest creation stories)

ID: STORY-VALIDATE-NETWORKING

## Story

As a Platform Engineer, I want to deploy and validate ALL manifests created in stories 1-44 on both infra and apps clusters using a systematic, phase-based approach, so that I can verify the complete platform stack (bootstrap, networking, security, storage, databases, observability, messaging, CI/CD, tenancy, applications) is operational before declaring the greenfield deployment complete.

This is the **SINGLE deployment and validation story** in the v3.0 manifests-first approach. All prior stories (1-44) created manifests only. This story deploys them all and validates runtime behavior.

## Why / Outcome

- **Deploy ALL manifests** created in stories 1-44 to both infra and apps clusters
- **Validate runtime behavior** of complete platform stack end-to-end
- **Verify integration** between components (Flux, Cilium, Rook, CNPG, VictoriaMetrics, etc.)
- **Establish baseline** performance and health metrics
- **Document evidence** of successful deployment for QA gate and PO acceptance
- **Enable day-2 operations** by confirming GitOps reconciliation loop is healthy

## Scope

### v3.0 Manifests-First Approach

**Stories 1-44 Created Manifests (NO Deployment)**:
- All manifest creation stories produced YAML/Kustomizations/HelmReleases
- Local validation only (`flux build`, `kustomize build`, `kubectl --dry-run=client`)
- NO cluster access or runtime validation in stories 1-44

**This Story (45) Deploys & Validates EVERYTHING**:
- Apply ALL manifests from stories 1-44 to both clusters
- Runtime validation of all components
- Integration testing across the stack
- Performance baseline establishment
- QA gate evidence collection

### Full Stack Coverage (Stories 1-44)

**Bootstrap & GitOps (Stories 42-44)**:
- Talos cluster bootstrap (Phase -1)
- CRDs installation (Phase 0/1)
- Core components (Phase 2): Cilium, Flux, CoreDNS, cert-manager, External Secrets
- Flux self-management (flux-operator + flux-instance)

**Networking (Stories 1-13)**:
1. STORY-NET-CILIUM-CORE-GITOPS — Cilium CNI, Hubble, L7 policies
2. STORY-NET-CILIUM-IPAM — LoadBalancer IP pools for infra/apps
3. STORY-NET-CILIUM-GATEWAY — GatewayClass, Gateway, HTTPRoute
4. STORY-DNS-COREDNS-BASE — CoreDNS with custom clusterIP
5. STORY-SEC-EXTERNAL-SECRETS-BASE — 1Password integration
6. STORY-SEC-CERT-MANAGER-ISSUERS — ClusterIssuers (LE staging/prod)
7. STORY-OPS-RELOADER-ALL-CLUSTERS — ConfigMap/Secret auto-reload
8. STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL — Cloudflare DNS + Cloudflared tunnels
9. STORY-NET-CILIUM-BGP — BGP control plane for service advertisement
10. STORY-NET-CILIUM-BGP-CP-IMPLEMENT — BGP peering configuration
11. STORY-NET-SPEGEL-REGISTRY-MIRROR — Image mirror for faster pulls
12. STORY-NET-CILIUM-CLUSTERMESH — Cross-cluster service mesh
13. STORY-NET-CLUSTERMESH-DNS — Cross-cluster DNS resolution

**Security (Stories 14-17)**:
14. STORY-SEC-NP-BASELINE — NetworkPolicy baseline (deny-all + allow exceptions)
15. STORY-SEC-SPIRE-CILIUM-AUTH — SPIRE + Cilium mutual auth

**Storage (Stories 18-23)**:
16. STORY-STO-OPENEBS-BASE — OpenEBS hostpath storage (infra)
17. STORY-STO-ROOK-CEPH-OPERATOR — Rook-Ceph operator (infra)
18. STORY-STO-ROOK-CEPH-CLUSTER — Rook-Ceph cluster, pools, storage classes (infra)
19. STORY-STO-APPS-OPENEBS-BASE — OpenEBS hostpath (apps)
20. STORY-STO-APPS-ROOK-CEPH-OPERATOR — Rook-Ceph operator (apps)
21. STORY-STO-APPS-ROOK-CEPH-CLUSTER — Rook-Ceph cluster (apps)

**Databases (Stories 24-27)**:
22. STORY-DB-CNPG-OPERATOR — CloudNative-PG operator (both clusters)
23. STORY-DB-CNPG-SHARED-CLUSTER — Shared PostgreSQL cluster with multi-tenant poolers
24. STORY-DB-DRAGONFLY-OPERATOR-CLUSTER — DragonflyDB operator + cluster

**Observability (Stories 28-32)**:
25. STORY-OBS-VM-STACK — VictoriaMetrics stack (infra, global metrics)
26. STORY-OBS-VICTORIA-LOGS — VictoriaLogs (infra, global logs)
27. STORY-OBS-FLUENT-BIT — Fluent-bit log collectors (infra)
28. STORY-OBS-APPS-COLLECTORS — vmagent, kube-state-metrics, node-exporter, fluent-bit (apps → infra)

**Messaging (Stories 33-36)**:
29. STORY-MSG-STRIMZI-OPERATOR — Strimzi Kafka operator (apps)
30. STORY-MSG-KAFKA-CLUSTER-APPS — Kafka cluster (apps)
31. STORY-MSG-SCHEMA-REGISTRY — Confluent Schema Registry (apps)

**Backup (Story 37)**:
32. STORY-BACKUP-VOLSYNC-APPS — VolSync for PVC backup/replication (apps)

**CI/CD (Stories 38-39)**:
33. STORY-CICD-GITHUB-ARC — GitHub Actions Runner Controller (apps)
34. STORY-CICD-GITLAB-APPS — GitLab (apps cluster, Harbor registry, CNPG database)

**Tenancy & Applications (Stories 40-41)**:
35. STORY-TENANCY-BASELINE — Multi-tenant namespace structure
36. STORY-APP-HARBOR — Harbor registry (apps, S3 storage, external DB/Redis)

**GitOps Self-Management (Story 41)**:
37. STORY-GITOPS-SELF-MGMT-FLUX — flux-operator + flux-instance for self-managed Flux

### Deployment Phases (Ordered)

This story executes deployment in **dependency order** to avoid race conditions:

**Phase -1: Talos Bootstrap** (Story 42)
- `task bootstrap:talos CLUSTER=infra`
- `task bootstrap:talos CLUSTER=apps`
- Kubeconfig generation, API server reachability

**Phase 0/1: CRDs & Namespaces** (Story 43)
- `task :bootstrap:phase:0 CLUSTER=infra CONTEXT=infra`
- `task :bootstrap:phase:1 CLUSTER=infra CONTEXT=infra`
- `task :bootstrap:phase:0 CLUSTER=apps CONTEXT=apps`
- `task :bootstrap:phase:1 CLUSTER=apps CONTEXT=apps`
- All CRDs Established before proceeding

**Phase 2: Core Bootstrap** (Story 44)
- `task :bootstrap:phase:2 CLUSTER=infra CONTEXT=infra`
- `task :bootstrap:phase:2 CLUSTER=apps CONTEXT=apps`
- Cilium CNI operational, nodes Ready
- Flux reconciliation loop active

**Phase 3: GitOps Takeover** (Flux reconciles remaining)
- `flux reconcile kustomization cluster-infra-infrastructure --with-source`
- `flux reconcile kustomization cluster-infra-workloads --with-source`
- `flux reconcile kustomization cluster-apps-infrastructure --with-source`
- `flux reconcile kustomization cluster-apps-workloads --with-source`
- Flux deploys all remaining components from git

**Phase 4: Validation & Evidence Collection** (This story's focus)
- Runtime validation of all components
- Integration testing
- Performance baselines
- QA evidence collection

## Acceptance Criteria

### AC1 — Bootstrap Phases Complete (Stories 42-44)

**Phase -1: Talos (Story 42)**:
- [ ] Infra cluster: 3 control plane nodes registered, kubeconfig exported
- [ ] Apps cluster: 3 control plane nodes registered, kubeconfig exported
- [ ] Kubernetes API reachable on both clusters
- [ ] etcd cluster healthy with 3 voting members (both clusters)

**Phase 0/1: CRDs (Story 43)**:
- [ ] 77 CRDs Established on infra cluster
- [ ] 77 CRDs Established on apps cluster
- [ ] Namespaces Active: external-secrets, cert-manager, flux-system, cnpg-system, observability

**Phase 2: Core (Story 44)**:
- [ ] Cilium agent/operator Running on all nodes (both clusters)
- [ ] Nodes Ready status (CNI operational)
- [ ] Flux controllers Running: source, kustomize, helm, notification
- [ ] CoreDNS pods Running
- [ ] cert-manager controllers Running
- [ ] External Secrets operator Running
- [ ] 1Password ClusterSecretStore Ready

### AC2 — Networking Stack Operational (Stories 1-13)

**Cilium CNI & IPAM**:
- [ ] `cilium status` reports healthy on both clusters
- [ ] Pod-to-pod connectivity verified within and across nodes
- [ ] LoadBalancer IPs assigned from IP pools (infra: 10.245.10.0/24, apps: 10.247.10.0/24)
- [ ] Hubble observability operational (flows visible)

**Gateway API**:
- [ ] GatewayClass Ready (both clusters)
- [ ] Gateway Ready with assigned LoadBalancer IP (both clusters)
- [ ] HTTPRoute routing traffic to test service

**BGP Peering**:
- [ ] BGP sessions established with upstream routers (infra + apps)
- [ ] Service IPs advertised via BGP
- [ ] Routes visible in router BGP table
- [ ] Failover tested (node down scenario)

**ClusterMesh**:
- [ ] ClusterMesh control plane deployed (both clusters)
- [ ] Bidirectional connectivity between infra and apps
- [ ] Cross-cluster service discovery working
- [ ] Global services reachable from both clusters

**DNS**:
- [ ] CoreDNS resolving `*.cluster.local` domains
- [ ] ExternalDNS creating Cloudflare records
- [ ] Cross-cluster DNS via ClusterMesh
- [ ] Cloudflared tunnel exposing services

**Security**:
- [ ] Wildcard certificate issued (`*.monosense.io`)
- [ ] External Secrets syncing from 1Password (no sync failures)
- [ ] NetworkPolicy deny-all + allow exceptions enforcing
- [ ] SPIRE agents Running, Cilium mTLS enabled (if implemented)

**Operations**:
- [ ] Reloader watching ConfigMaps/Secrets, triggering restarts
- [ ] Spegel registry mirror accelerating image pulls

### AC3 — Storage Operational (Stories 16-21)

**OpenEBS**:
- [ ] OpenEBS hostpath storage class available (both clusters)
- [ ] Test PVC provisioned and bound

**Rook-Ceph (infra)**:
- [ ] Rook-Ceph operator Running
- [ ] Ceph cluster HEALTH_OK (MONs, OSDs, MGRs)
- [ ] `rook-ceph-block` storage class available
- [ ] Test PVC provisioned from Ceph block pool

**Rook-Ceph (apps)**:
- [ ] Rook-Ceph operator Running (apps)
- [ ] Ceph cluster HEALTH_OK (apps)
- [ ] Storage class available
- [ ] Test PVC provisioned (apps)

### AC4 — Databases Operational (Stories 22-24)

**CloudNative-PG**:
- [ ] CloudNative-PG operator Running (both clusters)
- [ ] Shared PostgreSQL cluster Ready (3 replicas, synchronous replication)
- [ ] All PgBouncer poolers Running:
  - [ ] gitlab-pooler (apps)
  - [ ] harbor-pooler (apps)
  - [ ] keycloak-pooler (apps)
  - [ ] synergyflow-pooler (apps)
- [ ] Databases provisioned for each application
- [ ] Backup ScheduledBackup running (daily)
- [ ] Test database connection via pooler

**DragonflyDB**:
- [ ] DragonflyDB operator Running
- [ ] DragonflyDB cluster Ready (3 replicas)
- [ ] Test Redis connection (SET/GET operations)

### AC5 — Observability Operational (Stories 25-28)

**VictoriaMetrics (infra)**:
- [ ] VMAgent, VMInsert, VMSelect, VMStorage Running
- [ ] VMAuth reverse proxy operational
- [ ] ServiceMonitors scraping targets (Cilium, Rook, CNPG, Flux, etc.)
- [ ] PrometheusRules loaded (alerts defined)
- [ ] Grafana accessible (admin credentials from ExternalSecret)
- [ ] Test metrics query (e.g., `up{cluster="infra"}`)

**VictoriaLogs (infra)**:
- [ ] VictoriaLogs cluster Running (insert, select, storage)
- [ ] Fluent-bit forwarding logs to VictoriaLogs (infra)
- [ ] Test log query (e.g., `{cluster="infra"}`)

**Apps Collectors**:
- [ ] vmagent forwarding metrics to infra VictoriaMetrics
- [ ] kube-state-metrics Running (apps)
- [ ] node-exporter DaemonSet Running (apps, Talos-compatible)
- [ ] fluent-bit forwarding logs to infra VictoriaLogs (apps)
- [ ] Metrics visible in infra Grafana with `cluster=apps` label

### AC6 — Messaging Operational (Stories 29-31)

**Strimzi Kafka (apps)**:
- [ ] Strimzi operator Running
- [ ] Kafka cluster Ready (3 brokers, ZooKeeper or KRaft)
- [ ] Kafka topics created (`_schemas`, test topics)
- [ ] Test message produce/consume

**Schema Registry (apps)**:
- [ ] Schema Registry pods Running (2 replicas)
- [ ] Connected to Kafka `_schemas` topic
- [ ] Test schema registration (Avro schema upload)
- [ ] Schema compatibility check working

### AC7 — Backup Operational (Story 37)

**VolSync (apps)**:
- [ ] snapshot-controller Running
- [ ] VolSync operator Running
- [ ] Test ReplicationSource configured
- [ ] Test ReplicationDestination configured
- [ ] Snapshot created successfully

### AC8 — CI/CD Operational (Stories 38-39)

**GitHub Actions Runner (apps)**:
- [ ] ARC controller Running
- [ ] RunnerScaleSets deployed (`k8s-gitops`, `pilar-apps`)
- [ ] Runners registered with GitHub
- [ ] Test job execution on ephemeral runner

**GitLab (apps)**:
- [ ] GitLab pods Running (webservice, sidekiq, gitaly, shell, migrations)
- [ ] GitLab accessible via HTTPRoute
- [ ] GitLab connected to external PostgreSQL (via gitlab-pooler)
- [ ] GitLab connected to external Redis (DragonflyDB)
- [ ] GitLab using Harbor as container registry
- [ ] Test git clone/push operation
- [ ] Test CI/CD pipeline execution

### AC9 — Tenancy & Applications (Stories 40-41)

**Harbor (apps)**:
- [ ] Harbor pods Running (core, registry, jobservice, portal, etc.)
- [ ] Harbor accessible via HTTPRoute
- [ ] Harbor using MinIO S3 for image storage
- [ ] Harbor using external PostgreSQL (harbor-pooler)
- [ ] Harbor using external Redis (DragonflyDB)
- [ ] Test image push/pull to Harbor

**Keycloak** (if implemented):
- [ ] Keycloak pods Running
- [ ] Keycloak connected to database (keycloak-pooler)
- [ ] Keycloak accessible via HTTPRoute

### AC10 — Flux Self-Management (Story 41)

**flux-operator**:
- [ ] flux-operator Running
- [ ] FluxInstance CRD Established

**flux-instance**:
- [ ] flux-instance HelmRelease Ready (both clusters)
- [ ] Flux controllers managed by operator (reconciling)
- [ ] GitRepository connected
- [ ] All Kustomizations Ready

### AC11 — Integration & End-to-End

**Cross-Component Integration**:
- [ ] GitLab pipeline builds image → pushes to Harbor → triggers deployment
- [ ] Application deployed via Flux → gets LoadBalancer IP from Cilium → advertised via BGP
- [ ] Application uses ExternalSecret (1Password) for credentials
- [ ] Application logs forwarded to VictoriaLogs, metrics scraped by VMAgent
- [ ] Application stores data in PostgreSQL (via pooler) and Redis (DragonflyDB)
- [ ] Application publishes Kafka messages, Schema Registry validates schema

**Performance Baselines**:
- [ ] Pod start time < 30s (average)
- [ ] DNS query latency < 10ms (average)
- [ ] HTTP request latency < 100ms (p95, via Gateway API)
- [ ] Storage I/O latency < 10ms (p95, Rook-Ceph)
- [ ] Kafka message produce latency < 50ms (p95)

**Health & Monitoring**:
- [ ] All Flux Kustomizations Ready=True
- [ ] All HelmReleases Ready=True
- [ ] No CrashLoopBackOff pods
- [ ] No PodDisruptionBudget violations
- [ ] PrometheusRule alerts not firing (except expected)

### AC12 — Documentation & Evidence

**QA Evidence**:
- [ ] Bootstrap phase logs captured (Phases -1, 0, 1, 2)
- [ ] Flux reconciliation logs captured
- [ ] Component health checks captured (`cilium status`, `ceph status`, `kubectl get all -A`)
- [ ] Integration test results captured
- [ ] Performance baseline metrics captured
- [ ] Screenshots of Grafana dashboards, Harbor UI, GitLab UI

**Dev Notes**:
- [ ] All issues encountered documented with resolutions
- [ ] Deviations from manifests documented
- [ ] Runtime configuration changes noted
- [ ] Known limitations documented

## Dependencies / Inputs

**Upstream Prerequisites**:
- **Stories 1-44 Complete**: All manifest creation stories committed to git
- **Hardware**: 6 nodes total (3 infra control planes, 3 apps control planes)
- **Network**: Upstream BGP router configured, Cloudflare API token available
- **Secrets**: 1Password Connect token, GitLab root password, Harbor admin password

**Tools Required**:
- `kubectl`, `flux`, `cilium`, `talosctl`, `helmfile`
- `yq`, `jq`, `curl`, `dig`, `nslookup`
- `op` (1Password CLI)

**Cluster Access**:
- KUBECONFIG contexts: `infra`, `apps`
- Network connectivity to both clusters
- SSH/console access to nodes (for troubleshooting)

## Tasks / Subtasks

### T0 — Pre-Deployment Validation (NO Cluster Changes)

**Manifest Quality Checks**:
- [ ] Verify all stories 1-44 manifests committed to git
- [ ] Run `flux build kustomization` for each cluster entrypoint:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path kubernetes/clusters/infra
  flux build kustomization cluster-apps-infrastructure --path kubernetes/clusters/apps
  ```
- [ ] Validate with `kubeconform` (schema compliance):
  ```bash
  kustomize build kubernetes/clusters/infra | kubeconform -summary -strict
  kustomize build kubernetes/clusters/apps | kubeconform -summary -strict
  ```
- [ ] Check all Flux health checks defined in Kustomizations
- [ ] Verify cluster-settings ConfigMaps have all required substitutions

**Infrastructure Readiness**:
- [ ] Verify 6 nodes powered on and network-accessible
- [ ] Verify upstream BGP router configured and reachable
- [ ] Verify Cloudflare API token valid
- [ ] Verify 1Password Connect URL and token available

### T1 — Phase -1: Talos Bootstrap (Story 42)

**Infra Cluster**:
- [ ] Run `task bootstrap:talos CLUSTER=infra`
- [ ] Verify 3 control plane nodes registered: `kubectl --context=infra get nodes`
- [ ] Verify etcd healthy: `talosctl --context=infra --nodes <bootstrap-node> etcd status`
- [ ] Verify kubeconfig exported: `kubernetes/kubeconfig`
- [ ] Verify API reachable: `kubectl --context=infra cluster-info`
- [ ] **Expected**: Nodes NotReady (CNI not installed yet)

**Apps Cluster**:
- [ ] Run `task bootstrap:talos CLUSTER=apps`
- [ ] Verify 3 control plane nodes registered: `kubectl --context=apps get nodes`
- [ ] Verify etcd healthy: `talosctl --context=apps --nodes <bootstrap-node> etcd status`
- [ ] Verify kubeconfig exported
- [ ] Verify API reachable: `kubectl --context=apps cluster-info`
- [ ] **Expected**: Nodes NotReady (CNI not installed yet)

**Validation**:
- [ ] Capture Talos health output: `talosctl --context=infra health --wait-timeout 2m`
- [ ] Capture etcd member list: `talosctl --context=infra --nodes <bootstrap> etcd members`
- [ ] Document in Dev Notes

### T2 — Phase 0/1: CRDs & Namespaces (Story 43)

**Infra Cluster**:
- [ ] Run Phase 0: `task :bootstrap:phase:0 CLUSTER=infra CONTEXT=infra`
- [ ] Run Phase 1: `task :bootstrap:phase:1 CLUSTER=infra CONTEXT=infra`
- [ ] Verify CRDs Established:
  ```bash
  kubectl --context=infra get crd | wc -l  # expect 77
  kubectl --context=infra wait --for=condition=Established crd --all --timeout=5m
  ```
- [ ] Verify namespaces Active:
  ```bash
  kubectl --context=infra get ns | grep -E 'external-secrets|cert-manager|flux-system|cnpg-system|observability'
  ```

**Apps Cluster**:
- [ ] Run Phase 0: `task :bootstrap:phase:0 CLUSTER=apps CONTEXT=apps`
- [ ] Run Phase 1: `task :bootstrap:phase:1 CLUSTER=apps CONTEXT=apps`
- [ ] Verify CRDs Established (77 total)
- [ ] Verify namespaces Active

**Validation**:
- [ ] Run CRD validation script: `scripts/validate-crd-waitset.sh`
- [ ] Capture CRD list: `kubectl --context=infra get crd -o name > /tmp/crds-infra.txt`
- [ ] Document in Dev Notes

### T3 — Phase 2: Core Bootstrap (Story 44)

**Infra Cluster**:
- [ ] Run Phase 2: `task :bootstrap:phase:2 CLUSTER=infra CONTEXT=infra`
- [ ] Monitor deployment:
  ```bash
  watch kubectl --context=infra get pods -A
  ```
- [ ] Wait for Cilium operational:
  ```bash
  cilium --context=infra status --wait
  ```
- [ ] Verify nodes Ready:
  ```bash
  kubectl --context=infra get nodes
  # All nodes should be Ready now (CNI operational)
  ```
- [ ] Verify Flux controllers Running:
  ```bash
  kubectl --context=infra -n flux-system get pods
  # source-controller, kustomize-controller, helm-controller, notification-controller
  ```
- [ ] Verify CoreDNS Running:
  ```bash
  kubectl --context=infra -n kube-system get pods -l k8s-app=coredns
  ```
- [ ] Verify cert-manager Running:
  ```bash
  kubectl --context=infra -n cert-manager get pods
  ```
- [ ] Verify External Secrets Running:
  ```bash
  kubectl --context=infra -n external-secrets get pods
  kubectl --context=infra get clustersecretstore
  # ClusterSecretStore should be Ready=True
  ```

**Apps Cluster**:
- [ ] Run Phase 2: `task :bootstrap:phase:2 CLUSTER=apps CONTEXT=apps`
- [ ] Verify Cilium operational, nodes Ready
- [ ] Verify Flux controllers Running
- [ ] Verify CoreDNS, cert-manager, External Secrets Running

**Validation**:
- [ ] Capture `cilium status` output (both clusters)
- [ ] Capture `flux get all -A` (both clusters)
- [ ] Test DNS resolution:
  ```bash
  kubectl --context=infra run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
  ```
- [ ] Test External Secrets sync (create test ExternalSecret)
- [ ] Document in Dev Notes

### T4 — Phase 3: GitOps Takeover (Flux Deploys Remaining)

**Infra Cluster - Infrastructure Kustomization**:
- [ ] Trigger reconciliation:
  ```bash
  flux --context=infra reconcile kustomization cluster-infra-infrastructure --with-source
  ```
- [ ] Monitor reconciliation:
  ```bash
  flux --context=infra get kustomizations -A --watch
  ```
- [ ] Wait for all Kustomizations Ready:
  ```bash
  kubectl --context=infra get kustomizations -A
  # All should be Ready=True
  ```
- [ ] Check for errors:
  ```bash
  flux --context=infra events --for kustomization/cluster-infra-infrastructure
  ```

**Infra Cluster - Workloads Kustomization**:
- [ ] Trigger reconciliation:
  ```bash
  flux --context=infra reconcile kustomization cluster-infra-workloads --with-source
  ```
- [ ] Monitor deployment (databases, observability, messaging)
- [ ] Wait for all Kustomizations Ready

**Apps Cluster - Infrastructure Kustomization**:
- [ ] Trigger reconciliation:
  ```bash
  flux --context=apps reconcile kustomization cluster-apps-infrastructure --with-source
  ```
- [ ] Monitor deployment (Cilium, storage, databases, collectors)
- [ ] Wait for all Kustomizations Ready

**Apps Cluster - Workloads Kustomization**:
- [ ] Trigger reconciliation:
  ```bash
  flux --context=apps reconcile kustomization cluster-apps-workloads --with-source
  ```
- [ ] Monitor deployment (GitLab, Harbor, CI/CD, applications)
- [ ] Wait for all Kustomizations Ready

**Validation**:
- [ ] Capture full Kustomization status:
  ```bash
  flux --context=infra get kustomizations -A > /tmp/flux-ks-infra.txt
  flux --context=apps get kustomizations -A > /tmp/flux-ks-apps.txt
  ```
- [ ] Capture HelmRelease status:
  ```bash
  flux --context=infra get helmreleases -A > /tmp/flux-hr-infra.txt
  flux --context=apps get helmreleases -A > /tmp/flux-hr-apps.txt
  ```
- [ ] Document deployment timeline (start to all Ready)

### T5 — Networking Validation (Stories 1-13)

**Cilium Core**:
- [ ] Run Cilium status check:
  ```bash
  cilium --context=infra status
  cilium --context=apps status
  # All components should be healthy
  ```
- [ ] Run Cilium connectivity test:
  ```bash
  cilium --context=infra connectivity test --test pod-to-pod,pod-to-service
  ```
- [ ] Verify Hubble:
  ```bash
  cilium --context=infra hubble port-forward &
  hubble observe --last 100
  ```

**IPAM & LoadBalancer**:
- [ ] Verify IP pools configured:
  ```bash
  kubectl --context=infra get ciliumpodippools
  kubectl --context=infra get ciliumloadbalancerippool
  ```
- [ ] Create test LoadBalancer Service:
  ```bash
  kubectl --context=infra create deploy nginx --image=nginx
  kubectl --context=infra expose deploy nginx --type=LoadBalancer --port=80
  kubectl --context=infra get svc nginx -w
  # Wait for EXTERNAL-IP from pool
  ```
- [ ] Test LoadBalancer IP reachable:
  ```bash
  curl http://<EXTERNAL-IP>
  ```

**Gateway API**:
- [ ] Verify GatewayClass Ready:
  ```bash
  kubectl --context=infra get gatewayclass
  kubectl --context=apps get gatewayclass
  ```
- [ ] Verify Gateway Ready:
  ```bash
  kubectl --context=infra get gateway -A
  # Status: Programmed=True, Address assigned
  ```
- [ ] Deploy test HTTPRoute:
  ```bash
  kubectl --context=infra apply -f test-httproute.yaml
  kubectl --context=infra get httproute -A
  ```
- [ ] Test HTTP routing:
  ```bash
  curl -H "Host: test.monosense.io" http://<GATEWAY-IP>/
  ```

**BGP Peering**:
- [ ] Verify BGP sessions established:
  ```bash
  kubectl --context=infra get ciliumbgppeeringpolicy
  kubectl --context=infra get ciliumbgpnodeconfig
  # Check status for session state
  ```
- [ ] Check upstream router BGP table:
  ```bash
  # SSH to router, check for advertised service IPs
  show ip bgp summary
  show ip bgp neighbors <cilium-node-ip> advertised-routes
  ```
- [ ] Test failover (drain node, verify route update):
  ```bash
  kubectl --context=infra drain <node> --ignore-daemonsets
  # Check router for route withdrawal
  kubectl --context=infra uncordon <node>
  ```

**ClusterMesh**:
- [ ] Verify ClusterMesh status:
  ```bash
  cilium --context=infra clustermesh status
  cilium --context=apps clustermesh status
  # Should show connected to remote cluster
  ```
- [ ] Deploy test service in infra, verify reachable from apps:
  ```bash
  kubectl --context=infra create deploy cm-test --image=nginx
  kubectl --context=infra expose deploy cm-test --port=80
  kubectl --context=infra annotate svc cm-test service.cilium.io/global="true"

  kubectl --context=apps run -it --rm debug --image=busybox --restart=Never -- wget -O- cm-test.default.svc.clusterset.local
  ```

**DNS**:
- [ ] Test CoreDNS resolution:
  ```bash
  kubectl --context=infra run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local
  ```
- [ ] Verify ExternalDNS creating records:
  ```bash
  kubectl --context=infra logs -n external-dns deploy/external-dns
  # Check Cloudflare dashboard for DNS records
  ```
- [ ] Test cross-cluster DNS (via ClusterMesh):
  ```bash
  kubectl --context=apps run -it --rm debug --image=busybox --restart=Never -- nslookup test-service.default.svc.clusterset.local
  ```

**Certificates & Secrets**:
- [ ] Verify ClusterIssuer Ready:
  ```bash
  kubectl --context=infra get clusterissuer
  # letsencrypt-staging, letsencrypt-prod should be Ready=True
  ```
- [ ] Verify wildcard certificate issued:
  ```bash
  kubectl --context=infra get certificate -A
  # *.monosense.io should be Ready=True
  kubectl --context=infra describe certificate -n cert-manager wildcard-cert
  ```
- [ ] Verify External Secrets syncing:
  ```bash
  kubectl --context=infra get externalsecret -A
  # All should be SecretSynced=True
  kubectl --context=infra get clustersecretstore
  # onepassword should be Ready=True
  ```
- [ ] Test secret rotation (wait 1 hour, verify secret updated)

**Spegel**:
- [ ] Verify Spegel DaemonSet Running:
  ```bash
  kubectl --context=infra get ds -n spegel-system
  kubectl --context=apps get ds -n spegel-system
  ```
- [ ] Check Spegel metrics:
  ```bash
  kubectl --context=infra port-forward -n spegel-system svc/spegel-metrics 8080:8080
  curl localhost:8080/metrics | grep spegel_
  ```
- [ ] Test image pull acceleration (pull large image, check cache hit rate)

**Validation**:
- [ ] Document all test outputs in Dev Notes
- [ ] Capture screenshots of Hubble UI, Cloudflare DNS records
- [ ] Record BGP router session state

### T6 — Storage Validation (Stories 16-21)

**OpenEBS (Infra)**:
- [ ] Verify OpenEBS pods Running:
  ```bash
  kubectl --context=infra get pods -n openebs
  ```
- [ ] Verify storage class:
  ```bash
  kubectl --context=infra get sc openebs-hostpath
  ```
- [ ] Test PVC provisioning:
  ```bash
  kubectl --context=infra apply -f test-pvc-openebs.yaml
  kubectl --context=infra get pvc test-pvc-openebs
  # Status: Bound
  ```

**Rook-Ceph (Infra)**:
- [ ] Verify Rook operator Running:
  ```bash
  kubectl --context=infra -n rook-ceph get pods -l app=rook-ceph-operator
  ```
- [ ] Verify Ceph cluster health:
  ```bash
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
  # HEALTH_OK expected
  ```
- [ ] Verify Ceph components Running:
  ```bash
  kubectl --context=infra -n rook-ceph get pods
  # rook-ceph-mon-*, rook-ceph-osd-*, rook-ceph-mgr-*
  ```
- [ ] Verify storage class:
  ```bash
  kubectl --context=infra get sc rook-ceph-block
  ```
- [ ] Test PVC provisioning:
  ```bash
  kubectl --context=infra apply -f test-pvc-ceph.yaml
  kubectl --context=infra get pvc test-pvc-ceph
  # Status: Bound
  ```
- [ ] Check Ceph usage:
  ```bash
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
  ```

**Rook-Ceph (Apps)**:
- [ ] Repeat above checks for apps cluster
- [ ] Verify independent Ceph cluster (not clustered with infra)

**Validation**:
- [ ] Capture `ceph status` output (both clusters)
- [ ] Capture PVC test results
- [ ] Document in Dev Notes

### T7 — Database Validation (Stories 22-24)

**CloudNative-PG Operator**:
- [ ] Verify operator Running:
  ```bash
  kubectl --context=infra -n cnpg-system get pods
  kubectl --context=apps -n cnpg-system get pods
  ```

**Shared PostgreSQL Cluster (Apps)**:
- [ ] Verify cluster Ready:
  ```bash
  kubectl --context=apps -n cnpg-system get cluster shared-postgres
  # Status: Cluster in healthy state (3 instances)
  ```
- [ ] Verify replicas Running:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/cluster=shared-postgres
  # 3 pods Running
  ```
- [ ] Verify synchronous replication:
  ```bash
  kubectl --context=apps -n cnpg-system exec shared-postgres-1 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
  # sync_state should show 'sync' for at least 1 replica
  ```
- [ ] Verify backup schedule:
  ```bash
  kubectl --context=apps -n cnpg-system get scheduledbackup
  ```

**PgBouncer Poolers**:
- [ ] Verify poolers Running:
  ```bash
  kubectl --context=apps -n cnpg-system get pods -l cnpg.io/poolerName
  # gitlab-pooler, harbor-pooler, keycloak-pooler, synergyflow-pooler
  ```
- [ ] Test database connection via pooler:
  ```bash
  kubectl --context=apps -n cnpg-system run -it --rm psql-test --image=postgres:16 --restart=Never -- \
    psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production -c "SELECT version();"
  ```

**DragonflyDB**:
- [ ] Verify DragonflyDB operator Running:
  ```bash
  kubectl --context=apps -n dragonfly-system get pods
  ```
- [ ] Verify DragonflyDB cluster Ready:
  ```bash
  kubectl --context=apps -n dragonfly-system get dragonfly
  ```
- [ ] Test Redis connection:
  ```bash
  kubectl --context=apps -n dragonfly-system run -it --rm redis-test --image=redis:7 --restart=Never -- \
    redis-cli -h dragonfly.dragonfly-system.svc.cluster.local PING
  # Should return PONG
  ```
- [ ] Test SET/GET:
  ```bash
  kubectl --context=apps -n dragonfly-system run -it --rm redis-test --image=redis:7 --restart=Never -- \
    redis-cli -h dragonfly.dragonfly-system.svc.cluster.local SET test-key test-value
  kubectl --context=apps -n dragonfly-system run -it --rm redis-test --image=redis:7 --restart=Never -- \
    redis-cli -h dragonfly.dragonfly-system.svc.cluster.local GET test-key
  # Should return test-value
  ```

**Validation**:
- [ ] Capture PostgreSQL cluster status
- [ ] Capture pooler connection test results
- [ ] Capture DragonflyDB connection test results
- [ ] Document in Dev Notes

### T8 — Observability Validation (Stories 25-28)

**VictoriaMetrics (Infra)**:
- [ ] Verify VM components Running:
  ```bash
  kubectl --context=infra -n observability get pods
  # vmagent, vminsert, vmselect, vmstorage, vmauth
  ```
- [ ] Verify ServiceMonitors:
  ```bash
  kubectl --context=infra get servicemonitor -A
  ```
- [ ] Verify PrometheusRules:
  ```bash
  kubectl --context=infra get prometheusrule -A
  ```
- [ ] Test metrics query:
  ```bash
  kubectl --context=infra port-forward -n observability svc/vmselect 8481:8481
  curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster="infra"}'
  ```
- [ ] Verify Grafana accessible:
  ```bash
  kubectl --context=infra -n observability get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d
  # Access Grafana via HTTPRoute or port-forward
  ```

**VictoriaLogs (Infra)**:
- [ ] Verify VL components Running:
  ```bash
  kubectl --context=infra -n observability get pods -l app=victorialogs
  ```
- [ ] Test log query:
  ```bash
  kubectl --context=infra port-forward -n observability svc/victorialogs 9428:9428
  curl 'http://localhost:9428/select/logsql/query?query={cluster="infra"}'
  ```

**Fluent-bit (Infra)**:
- [ ] Verify fluent-bit DaemonSet Running:
  ```bash
  kubectl --context=infra -n observability get ds fluent-bit
  ```
- [ ] Check logs forwarding:
  ```bash
  kubectl --context=infra -n observability logs ds/fluent-bit | tail -20
  ```

**Apps Collectors**:
- [ ] Verify vmagent Running (apps):
  ```bash
  kubectl --context=apps -n observability get pods -l app=vmagent
  ```
- [ ] Verify kube-state-metrics Running (apps):
  ```bash
  kubectl --context=apps -n observability get pods -l app.kubernetes.io/name=kube-state-metrics
  ```
- [ ] Verify node-exporter DaemonSet Running (apps):
  ```bash
  kubectl --context=apps -n observability get ds node-exporter
  ```
- [ ] Verify fluent-bit DaemonSet Running (apps):
  ```bash
  kubectl --context=apps -n observability get ds fluent-bit
  ```
- [ ] Test metrics forwarding (query infra Grafana for apps metrics):
  ```bash
  curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster="apps"}'
  # Should return metrics from apps cluster
  ```
- [ ] Test logs forwarding (query infra VictoriaLogs for apps logs):
  ```bash
  curl 'http://localhost:9428/select/logsql/query?query={cluster="apps"}'
  # Should return logs from apps cluster
  ```

**Validation**:
- [ ] Capture metrics query results
- [ ] Capture log query results
- [ ] Take screenshots of Grafana dashboards
- [ ] Document retention settings (metrics 30d, logs 14d)

### T9 — Messaging Validation (Stories 29-31)

**Strimzi Kafka (Apps)**:
- [ ] Verify Strimzi operator Running:
  ```bash
  kubectl --context=apps -n messaging get pods -l app=strimzi
  ```
- [ ] Verify Kafka cluster Ready:
  ```bash
  kubectl --context=apps -n messaging get kafka
  # Status: Ready
  ```
- [ ] Verify Kafka brokers Running:
  ```bash
  kubectl --context=apps -n messaging get pods -l strimzi.io/cluster=kafka-cluster
  # 3 broker pods Running
  ```
- [ ] Verify Kafka topics:
  ```bash
  kubectl --context=apps -n messaging get kafkatopic
  # _schemas, test topics
  ```
- [ ] Test message produce/consume:
  ```bash
  kubectl --context=apps -n messaging run kafka-producer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-3.6.0 --restart=Never -- \
    bin/kafka-console-producer.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092 --topic test-topic
  # Type message, Ctrl+D

  kubectl --context=apps -n messaging run kafka-consumer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-3.6.0 --restart=Never -- \
    bin/kafka-console-consumer.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092 --topic test-topic --from-beginning
  # Should see message
  ```

**Schema Registry (Apps)**:
- [ ] Verify Schema Registry pods Running:
  ```bash
  kubectl --context=apps -n messaging get pods -l app=schema-registry
  # 2 pods Running
  ```
- [ ] Test schema registration:
  ```bash
  kubectl --context=apps port-forward -n messaging svc/schema-registry 8081:8081
  curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\":\"record\",\"name\":\"Test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"}]}"}' \
    http://localhost:8081/subjects/test-value/versions
  # Should return schema ID
  ```
- [ ] Test schema retrieval:
  ```bash
  curl http://localhost:8081/subjects/test-value/versions/latest
  ```
- [ ] Test compatibility check:
  ```bash
  curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\":\"record\",\"name\":\"Test\",\"fields\":[{\"name\":\"field1\",\"type\":\"string\"},{\"name\":\"field2\",\"type\":\"int\"}]}"}' \
    http://localhost:8081/compatibility/subjects/test-value/versions/latest
  # Should return compatibility result
  ```

**Validation**:
- [ ] Capture Kafka cluster status
- [ ] Capture Schema Registry API responses
- [ ] Document in Dev Notes

### T10 — Backup Validation (Story 37)

**VolSync (Apps)**:
- [ ] Verify snapshot-controller Running:
  ```bash
  kubectl --context=apps -n volsync-system get pods
  ```
- [ ] Verify VolSync operator Running:
  ```bash
  kubectl --context=apps -n volsync-system get pods -l app=volsync
  ```
- [ ] Test ReplicationSource:
  ```bash
  kubectl --context=apps -n test-app get replicationsource
  # Status: Snapshot created
  ```
- [ ] Test ReplicationDestination:
  ```bash
  kubectl --context=apps -n test-app get replicationdestination
  # Status: Ready
  ```
- [ ] Verify VolumeSnapshot created:
  ```bash
  kubectl --context=apps get volumesnapshot -A
  ```

**Validation**:
- [ ] Capture VolSync status
- [ ] Capture VolumeSnapshot details
- [ ] Document in Dev Notes

### T11 — CI/CD Validation (Stories 38-39)

**GitHub Actions Runner (Apps)**:
- [ ] Verify ARC controller Running:
  ```bash
  kubectl --context=apps -n actions-runner get pods -l app=controller
  ```
- [ ] Verify RunnerScaleSets deployed:
  ```bash
  kubectl --context=apps -n actions-runner get runnerscalesets
  # k8s-gitops, pilar-apps
  ```
- [ ] Verify runners registered:
  ```bash
  # Check GitHub repository settings for active runners
  ```
- [ ] Test job execution:
  ```bash
  # Trigger test workflow in GitHub Actions
  # Verify runner picks up job and executes successfully
  ```

**GitLab (Apps)**:
- [ ] Verify GitLab pods Running:
  ```bash
  kubectl --context=apps -n gitlab get pods
  # webservice, sidekiq, gitaly, shell, migrations
  ```
- [ ] Verify GitLab accessible:
  ```bash
  # Access via HTTPRoute or port-forward
  # Login with root password from ExternalSecret
  ```
- [ ] Verify database connection:
  ```bash
  kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i "database"
  # Should show connection to gitlab-pooler
  ```
- [ ] Verify Redis connection:
  ```bash
  kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i "redis"
  # Should show connection to DragonflyDB
  ```
- [ ] Verify Harbor integration:
  ```bash
  # GitLab Admin > Settings > CI/CD > Container Registry
  # Should show Harbor as registry
  ```
- [ ] Test git operations:
  ```bash
  git clone http://<gitlab-url>/root/test-project.git
  echo "test" > test.txt
  git add test.txt
  git commit -m "test commit"
  git push origin main
  ```
- [ ] Test CI/CD pipeline:
  ```bash
  # Create .gitlab-ci.yml in test project
  # Trigger pipeline
  # Verify pipeline executes and builds Docker image
  # Verify image pushed to Harbor
  ```

**Validation**:
- [ ] Capture GitLab pod status
- [ ] Capture GitLab UI screenshots
- [ ] Capture CI/CD pipeline execution logs
- [ ] Document in Dev Notes

### T12 — Tenancy & Applications (Stories 40-41)

**Harbor (Apps)**:
- [ ] Verify Harbor pods Running:
  ```bash
  kubectl --context=apps -n harbor get pods
  # core, registry, jobservice, portal, trivy
  ```
- [ ] Verify Harbor accessible:
  ```bash
  # Access via HTTPRoute or port-forward
  # Login with admin password from ExternalSecret
  ```
- [ ] Verify MinIO S3 storage:
  ```bash
  kubectl --context=apps -n harbor logs deploy/harbor-core | grep -i "s3\|minio"
  # Should show S3/MinIO storage backend
  ```
- [ ] Verify database connection:
  ```bash
  kubectl --context=apps -n harbor logs deploy/harbor-core | grep -i "database"
  # Should show connection to harbor-pooler
  ```
- [ ] Verify Redis connection:
  ```bash
  kubectl --context=apps -n harbor logs deploy/harbor-core | grep -i "redis"
  # Should show connection to DragonflyDB
  ```
- [ ] Test image push/pull:
  ```bash
  docker login <harbor-url>
  docker pull nginx:latest
  docker tag nginx:latest <harbor-url>/library/nginx:test
  docker push <harbor-url>/library/nginx:test
  docker pull <harbor-url>/library/nginx:test
  ```

**Validation**:
- [ ] Capture Harbor pod status
- [ ] Capture Harbor UI screenshots
- [ ] Capture image push/pull logs
- [ ] Document in Dev Notes

### T13 — Flux Self-Management Validation (Story 41)

**flux-operator**:
- [ ] Verify flux-operator Running:
  ```bash
  kubectl --context=infra -n flux-system get pods -l app=flux-operator
  kubectl --context=apps -n flux-system get pods -l app=flux-operator
  ```
- [ ] Verify FluxInstance CRD:
  ```bash
  kubectl --context=infra get crd fluxinstances.fluxcd.controlplane.io
  ```

**flux-instance**:
- [ ] Verify flux-instance HelmRelease Ready:
  ```bash
  kubectl --context=infra -n flux-system get hr flux-instance
  kubectl --context=apps -n flux-system get hr flux-instance
  # Status: Ready=True
  ```
- [ ] Verify Flux controllers managed by operator:
  ```bash
  kubectl --context=infra -n flux-system get pods
  # source-controller, kustomize-controller, helm-controller, notification-controller
  # Labels should indicate managed by flux-operator
  ```
- [ ] Verify GitRepository connected:
  ```bash
  flux --context=infra get sources git -A
  # Status: Artifact ready
  ```

**Test Flux Upgrade** (optional, high-risk):
- [ ] Update flux-instance version in git (e.g., v2.4.0 → v2.4.1)
- [ ] Commit and push
- [ ] Monitor operator performing rolling upgrade:
  ```bash
  watch kubectl --context=infra -n flux-system get pods
  ```
- [ ] Verify new version deployed:
  ```bash
  flux --context=infra version
  ```

**Validation**:
- [ ] Capture flux-operator logs
- [ ] Capture flux-instance status
- [ ] Capture Flux controller versions
- [ ] Document in Dev Notes

### T14 — Integration & End-to-End Testing

**Cross-Component Integration**:
- [ ] **Full CI/CD Flow**:
  1. Create test application with Dockerfile
  2. Commit to GitLab
  3. GitLab CI/CD pipeline builds Docker image
  4. Pipeline pushes image to Harbor
  5. Pipeline triggers Flux ImageUpdateAutomation (or manual update)
  6. Flux deploys application to apps cluster
  7. Application gets LoadBalancer IP from Cilium IPAM
  8. Cilium BGP advertises LoadBalancer IP to upstream router
  9. Application accessible externally via BGP route

- [ ] **Secrets & Database Integration**:
  1. Application uses ExternalSecret to fetch database credentials from 1Password
  2. ExternalSecret syncs and creates Kubernetes Secret
  3. Application connects to PostgreSQL via PgBouncer pooler (harbor-pooler or gitlab-pooler)
  4. Application connects to Redis via DragonflyDB

- [ ] **Observability Integration**:
  1. Application exposes Prometheus metrics endpoint
  2. ServiceMonitor scrapes metrics
  3. vmagent forwards metrics to infra VictoriaMetrics
  4. Metrics visible in Grafana dashboard
  5. Application logs forwarded to VictoriaLogs via fluent-bit
  6. Logs queryable in Grafana/VictoriaLogs UI

- [ ] **Messaging Integration**:
  1. Application publishes messages to Kafka topic
  2. Messages validated against Avro schema in Schema Registry
  3. Consumer application reads messages from Kafka
  4. End-to-end message flow verified

**Performance Baseline Tests**:
- [ ] Pod start time:
  ```bash
  kubectl --context=apps -n test-app get events --sort-by='.metadata.creationTimestamp' | grep "Started container"
  # Record time from Scheduled to Started
  # Target: < 30s average
  ```
- [ ] DNS query latency:
  ```bash
  kubectl --context=infra run -it --rm dnsperf --image=appropriate/dnsperf --restart=Never -- \
    dnsperf -s 10.245.0.10 -d test-queries.txt -Q 1000
  # Target: < 10ms average
  ```
- [ ] HTTP request latency (via Gateway API):
  ```bash
  kubectl --context=apps run -it --rm hey --image=williamyeh/hey --restart=Never -- \
    hey -n 1000 -c 10 http://<gateway-ip>/
  # Target: p95 < 100ms
  ```
- [ ] Storage I/O latency:
  ```bash
  kubectl --context=infra run -it --rm fio --image=nixery.dev/fio --restart=Never -- \
    fio --name=randread --ioengine=libaio --rw=randread --bs=4k --numjobs=1 --size=1G --runtime=60
  # Target: p95 < 10ms (Rook-Ceph)
  ```
- [ ] Kafka message produce latency:
  ```bash
  # Use kafka-producer-perf-test
  kubectl --context=apps -n messaging exec kafka-cluster-kafka-0 -- \
    bin/kafka-producer-perf-test.sh --topic perf-test --num-records 10000 --record-size 1000 \
    --throughput -1 --producer-props bootstrap.servers=localhost:9092
  # Target: p95 < 50ms
  ```

**Health & Monitoring Checks**:
- [ ] All Flux Kustomizations Ready:
  ```bash
  kubectl --context=infra get kustomizations -A -o json | jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True")) | .metadata.name'
  # Should return empty
  ```
- [ ] All HelmReleases Ready:
  ```bash
  kubectl --context=infra get hr -A -o json | jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True")) | .metadata.name'
  # Should return empty
  ```
- [ ] No CrashLoopBackOff pods:
  ```bash
  kubectl --context=infra get pods -A | grep CrashLoopBackOff
  # Should return empty
  ```
- [ ] No PodDisruptionBudget violations:
  ```bash
  kubectl --context=infra get pdb -A
  # Check ALLOWED DISRUPTIONS > 0
  ```
- [ ] PrometheusRule alerts status:
  ```bash
  # Query VictoriaMetrics for firing alerts
  curl 'http://localhost:8481/select/0/prometheus/api/v1/alerts' | jq '.data.alerts[] | select(.state=="firing")'
  # Review firing alerts (expected vs unexpected)
  ```

**Validation**:
- [ ] Document all integration test results
- [ ] Record performance baseline metrics
- [ ] Capture health check outputs
- [ ] Take screenshots of end-to-end flow (Grafana, GitLab, Harbor)

### T15 — Documentation & Evidence Collection

**QA Evidence Artifacts**:
- [ ] Bootstrap phase logs:
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-minus1-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-minus1-apps.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-0-1-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-0-1-apps.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-2-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-phase-2-apps.txt`

- [ ] Flux reconciliation logs:
  - [ ] `docs/qa/evidence/VALIDATE-NET-flux-reconcile-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-flux-reconcile-apps.txt`

- [ ] Component health checks:
  - [ ] `docs/qa/evidence/VALIDATE-NET-cilium-status-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-cilium-status-apps.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-ceph-status-infra.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-ceph-status-apps.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-cnpg-status.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-kafka-status.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-gitlab-status.txt`
  - [ ] `docs/qa/evidence/VALIDATE-NET-harbor-status.txt`

- [ ] Integration test results:
  - [ ] `docs/qa/evidence/VALIDATE-NET-integration-tests.txt`

- [ ] Performance baselines:
  - [ ] `docs/qa/evidence/VALIDATE-NET-performance-baselines.txt`

- [ ] Screenshots:
  - [ ] Grafana dashboards (VictoriaMetrics, VictoriaLogs, Ceph, CNPG)
  - [ ] GitLab UI (repository, pipeline, container registry)
  - [ ] Harbor UI (projects, repositories, vulnerability scanning)
  - [ ] Cilium Hubble UI (network flows)

**Dev Notes Documentation**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration changes (if any)
- [ ] Known limitations
- [ ] Recommendations for day-2 operations

**Architecture/PRD Updates**:
- [ ] Update architecture.md with any runtime adjustments
- [ ] Document performance baselines in PRD
- [ ] Note any security findings

## Validation Steps

### Pre-Deployment Validation (NO Cluster)
```bash
# Validate all manifests can build
flux build kustomization cluster-infra-infrastructure --path kubernetes/clusters/infra
flux build kustomization cluster-apps-infrastructure --path kubernetes/clusters/apps

# Schema validation
kustomize build kubernetes/clusters/infra | kubeconform -summary -strict
kustomize build kubernetes/clusters/apps | kubeconform -summary -strict
```

### Runtime Validation Commands (Summary)

**Bootstrap Phases**:
```bash
# Phase -1: Talos
task bootstrap:talos CLUSTER=infra
task bootstrap:talos CLUSTER=apps

# Phase 0/1: CRDs
task :bootstrap:phase:0 CLUSTER=infra CONTEXT=infra
task :bootstrap:phase:1 CLUSTER=infra CONTEXT=infra
task :bootstrap:phase:0 CLUSTER=apps CONTEXT=apps
task :bootstrap:phase:1 CLUSTER=apps CONTEXT=apps

# Phase 2: Core
task :bootstrap:phase:2 CLUSTER=infra CONTEXT=infra
task :bootstrap:phase:2 CLUSTER=apps CONTEXT=apps
```

**Flux Reconciliation**:
```bash
# Trigger reconciliation
flux --context=infra reconcile kustomization cluster-infra-infrastructure --with-source
flux --context=apps reconcile kustomization cluster-apps-infrastructure --with-source

# Monitor status
flux --context=infra get kustomizations -A --watch
flux --context=apps get kustomizations -A --watch
```

**Component Health Checks**:
```bash
# Cilium
cilium --context=infra status
cilium --context=apps status

# Ceph
kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# PostgreSQL
kubectl --context=apps -n cnpg-system get cluster

# Kafka
kubectl --context=apps -n messaging get kafka

# GitLab
kubectl --context=apps -n gitlab get pods

# Harbor
kubectl --context=apps -n harbor get pods
```

**Integration Tests**:
```bash
# Cilium connectivity
cilium --context=infra connectivity test

# ClusterMesh
cilium --context=infra clustermesh status

# DNS resolution
kubectl --context=infra run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local

# Database connection
kubectl --context=apps -n cnpg-system run -it --rm psql-test --image=postgres:16 --restart=Never -- \
  psql -h gitlab-pooler-rw.cnpg-system.svc.cluster.local -U gitlab -d gitlabhq_production -c "SELECT version();"

# Kafka produce/consume
kubectl --context=apps -n messaging exec kafka-cluster-kafka-0 -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test-topic

# Image push to Harbor
docker push <harbor-url>/library/nginx:test
```

## Rollback Procedures

**Component-Level Rollback**:
```bash
# Rollback specific HelmRelease
flux --context=infra suspend helmrelease <name> -n <namespace>
flux --context=infra resume helmrelease <name> -n <namespace> --patch '{"spec":{"chart":{"spec":{"version":"<previous-version>"}}}}'

# Rollback specific Kustomization
flux --context=infra suspend kustomization <name>
# Revert git commit
flux --context=infra resume kustomization <name> --with-source
```

**Full Cluster Rollback**:
```bash
# Phase 2 rollback (core components)
helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e infra destroy
# Re-run Phase 2 with previous configuration

# Phase 1 rollback (CRDs) - HIGH RISK, avoid if possible
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra destroy
# WARNING: Destroys all CRDs and dependent resources!
```

**Emergency Recovery**:
```bash
# Full cluster rebuild
task cluster:destroy CLUSTER=infra
task cluster:create-infra
# Re-run all bootstrap phases
```

## Risks / Mitigations

**Deployment Risks**:

**R1 — Bootstrap Phase Failure** (Prob=Medium, Impact=High):
- Risk: Phase -1, 0, 1, or 2 fails, blocking entire deployment
- Mitigation: Phase isolation; validate each phase before proceeding; capture logs; retry with `--force-reconcile`
- Recovery: Re-run failed phase with fixes

**R2 — Network Egress Blocked** (Prob=Low, Impact=High):
- Risk: Cannot pull images from registries, blocking pod starts
- Mitigation: Pre-cache critical images with Spegel; verify network connectivity before deployment
- Recovery: Fix network egress; use local registry mirror

**R3 — CRD Establishment Timeout** (Prob=Low, Impact=Medium):
- Risk: CRDs not Established within timeout, blocking dependent resources
- Mitigation: Explicit CRD wait with `kubectl wait --for=condition=Established`; increase timeout in Flux
- Recovery: Wait longer; check for CRD conflicts; re-apply CRDs

**R4 — Flux Reconciliation Loop** (Prob=Medium, Impact=Medium):
- Risk: Kustomization repeatedly fails reconciliation due to dependency issues
- Mitigation: Explicit `dependsOn` in Kustomizations; health checks; prune carefully
- Recovery: Suspend failing Kustomization; fix manifests; resume with `--with-source`

**R5 — Storage Provisioning Failure** (Prob=Medium, Impact=High):
- Risk: Rook-Ceph or OpenEBS fails to provision storage, blocking databases/applications
- Mitigation: Pre-validate node storage devices; check CSI drivers; verify storage class settings
- Recovery: Fix storage backend (Ceph cluster health, node labels); delete failed PVCs; retry

**R6 — Database Connection Failures** (Prob=Medium, Impact=High):
- Risk: Applications cannot connect to PostgreSQL or DragonflyDB
- Mitigation: Validate pooler endpoints; test connections before deploying apps; check network policies
- Recovery: Verify pooler Running; check credentials in ExternalSecrets; test connection manually

**R7 — BGP Peering Failure** (Prob=Medium, Impact=Medium):
- Risk: BGP sessions not established, services unreachable externally
- Mitigation: Pre-validate BGP router configuration; test peering manually; check firewall rules
- Recovery: Fix BGP configuration (peer IPs, AS numbers); restart Cilium agent; check router logs

**R8 — ClusterMesh Connectivity Failure** (Prob=Medium, Impact=Medium):
- Risk: Cross-cluster service mesh not working
- Mitigation: Validate clustermesh-apiserver reachable; check firewall rules; verify clustermesh secrets
- Recovery: Re-enable ClusterMesh; verify clustermesh-apiserver service; check mutual TLS certificates

**R9 — Secret Sync Failures** (Prob=Medium, Impact=High):
- Risk: ExternalSecrets cannot sync from 1Password, blocking applications
- Mitigation: Validate 1Password Connect token before deployment; test ClusterSecretStore Ready
- Recovery: Fix 1Password Connect URL/token; verify network connectivity; check ClusterSecretStore status

**R10 — Performance Degradation** (Prob=Low, Impact=Medium):
- Risk: Platform performance worse than baselines (latency, throughput)
- Mitigation: Establish baselines early; monitor resource usage; scale components as needed
- Recovery: Identify bottleneck (CPU, memory, I/O); scale up resources; optimize configuration

## Definition of Done

**All Acceptance Criteria Met**:
- [ ] AC1: Bootstrap phases complete (Talos, CRDs, Core)
- [ ] AC2: Networking stack operational
- [ ] AC3: Storage operational
- [ ] AC4: Databases operational
- [ ] AC5: Observability operational
- [ ] AC6: Messaging operational
- [ ] AC7: Backup operational
- [ ] AC8: CI/CD operational
- [ ] AC9: Tenancy & applications operational
- [ ] AC10: Flux self-management operational
- [ ] AC11: Integration & end-to-end tests passing
- [ ] AC12: Documentation & evidence complete

**QA Gate**:
- [ ] QA evidence artifacts collected and reviewed
- [ ] Risk assessment updated with deployment findings
- [ ] Test design execution complete (all P0 tests passing)
- [ ] QA gate decision: PASS (or waivers documented)

**PO Acceptance**:
- [ ] All stories 1-44 manifests deployed successfully
- [ ] Full platform stack operational on both clusters
- [ ] Integration tests demonstrate cross-component functionality
- [ ] Performance baselines established and acceptable
- [ ] Day-2 operations enabled (GitOps reconciliation healthy)
- [ ] Known limitations documented and accepted

**Handoff to Operations**:
- [ ] Runbooks updated with deployment lessons learned
- [ ] Monitoring dashboards configured and accessible
- [ ] Alerting configured for critical components
- [ ] Backup validation complete
- [ ] Disaster recovery procedures tested (optional)

## Architect Handoff

**Architecture (docs/architecture.md)**:
- Validate deployed architecture matches documented design
- Document any runtime adjustments or deviations
- Update network topology diagrams (BGP, ClusterMesh)
- Document performance baselines and capacity planning

**PRD (docs/prd.md)**:
- Confirm NFRs met:
  - Performance (latency, throughput, startup time)
  - Reliability (HA, failover, recovery)
  - Security (mTLS, network policies, secret management)
  - Scalability (resource limits, auto-scaling)
- Document baseline metrics for future comparison
- Note any NFR violations with mitigations

**Runbooks**:
- Update `docs/runbooks/bootstrapping-from-zero.md` with deployment findings
- Create `docs/runbooks/day-2-operations.md` with operational procedures
- Document troubleshooting procedures for common issues

## Change Log

| Date       | Version | Description                              | Author  |
|------------|---------|------------------------------------------|---------|
| 2025-10-26 | 0.1     | Initial validation story creation (draft)| Winston |
| 2025-10-26 | 1.0     | **v3.0 Refinement**: Comprehensive deployment/validation consolidation story. Added 15 tasks (T0-T15) covering all stories 1-44. Created 12 acceptance criteria with detailed validation. Added evidence collection, integration tests, performance baselines, QA artifacts. | Winston |

## Dev Agent Record

### Agent Model Used
<to be filled by dev>

### Debug Log References
<to be filled by dev>

### Completion Notes List
<to be filled by dev>

### File List
<to be filled by dev>

## QA Results — Risk Profile

**Reviewer**: Quinn (Test Architect & Quality Advisor)

**Summary**:
- Total Risks Identified: 10
- Critical: 0 | High: 5 | Medium: 5 | Low: 0
- Overall Story Risk Score: 68/100 (Medium-High)

**Top Risks**:
1. **R5 — Storage Provisioning Failure** (High): Rook-Ceph/OpenEBS failures block databases
2. **R6 — Database Connection Failures** (High): Applications cannot connect to PostgreSQL/Redis
3. **R1 — Bootstrap Phase Failure** (High): Early phase failure blocks entire deployment
4. **R9 — Secret Sync Failures** (High): ExternalSecrets cannot sync from 1Password
5. **R4 — Flux Reconciliation Loop** (Medium): Kustomization repeatedly fails

**Mitigations**:
- All risks have documented mitigation strategies
- Recovery procedures defined for each risk
- Phase-based approach allows early failure detection
- Comprehensive validation at each phase

**Risk-Based Testing Focus**:
- Priority 1: Bootstrap phases, storage provisioning, database connectivity
- Priority 2: Flux reconciliation, BGP peering, ClusterMesh
- Priority 3: Integration tests, performance baselines

**Artifacts**:
- Full assessment: `docs/qa/assessments/STORY-VALIDATE-NETWORKING-risk-20251026.md` (to be created)

## QA Results — Test Design

**Designer**: Quinn (Test Architect)

**Test Strategy Overview**:
- **Emphasis**: Runtime validation and integration testing
- **Approach**: Phase-based deployment with validation gates between phases
- **Coverage**: All 12 acceptance criteria mapped to test cases
- **Priority Distribution**: P0 (critical path, bootstrap phases), P1 (core components), P2 (optional features)

**Test Environments**:
- **Infra Cluster**: 3 control plane nodes (bare metal or VMs)
- **Apps Cluster**: 3 control plane nodes (bare metal or VMs)
- **Upstream Infrastructure**: BGP router, Cloudflare DNS, 1Password Connect

**Test Phases**:

**Phase 1: Pre-Deployment Validation** (T0):
- Manifest build validation (`flux build`, `kustomize build`)
- Schema validation (`kubeconform`)
- Infrastructure readiness (nodes, network, secrets)

**Phase 2: Bootstrap Validation** (T1-T3):
- Talos cluster bootstrap (Phase -1)
- CRD installation (Phase 0/1)
- Core components (Phase 2): Cilium, Flux, CoreDNS, cert-manager, External Secrets

**Phase 3: Component Validation** (T4-T13):
- Networking (T5): Cilium, BGP, ClusterMesh, DNS, certificates, Spegel
- Storage (T6): OpenEBS, Rook-Ceph
- Databases (T7): CloudNative-PG, DragonflyDB
- Observability (T8): VictoriaMetrics, VictoriaLogs, collectors
- Messaging (T9): Kafka, Schema Registry
- Backup (T10): VolSync
- CI/CD (T11): GitHub ARC, GitLab
- Applications (T12): Harbor
- Flux Self-Management (T13): flux-operator, flux-instance

**Phase 4: Integration Validation** (T14):
- Cross-component integration tests
- End-to-end workflows (CI/CD → deployment → observability)
- Performance baseline tests
- Health & monitoring checks

**Phase 5: Evidence Collection** (T15):
- QA artifacts capture
- Documentation updates
- Architecture/PRD alignment

**Test Cases** (High-Level Summary):

**P0 Tests (Critical Path)** (~20 tests):
- Bootstrap phases complete successfully
- Cilium CNI operational, nodes Ready
- Flux reconciliation loop healthy
- Storage provisioning working (Ceph HEALTH_OK)
- Database connectivity verified (PostgreSQL, DragonflyDB)
- ExternalSecrets syncing from 1Password

**P1 Tests (Core Components)** (~30 tests):
- BGP peering established, routes advertised
- ClusterMesh cross-cluster connectivity
- DNS resolution (CoreDNS, ExternalDNS, cross-cluster)
- Certificate issuance (wildcard cert)
- Observability stack operational (metrics, logs)
- Kafka cluster Ready, message produce/consume
- GitLab operational, CI/CD pipelines
- Harbor operational, image push/pull

**P2 Tests (Integration & Performance)** (~15 tests):
- End-to-end CI/CD workflow
- Cross-cluster service discovery
- Performance baselines (latency, throughput, startup time)
- Flux self-management (operator + instance)
- Advanced features (SPIRE, Spegel, VolSync)

**Total Test Cases**: ~65 tests

**Traceability** (Acceptance Criteria → Test Coverage):
- AC1 (Bootstrap) → Phase 2 tests (T1-T3)
- AC2 (Networking) → T5 tests
- AC3 (Storage) → T6 tests
- AC4 (Databases) → T7 tests
- AC5 (Observability) → T8 tests
- AC6 (Messaging) → T9 tests
- AC7 (Backup) → T10 tests
- AC8 (CI/CD) → T11 tests
- AC9 (Applications) → T12 tests
- AC10 (Flux Self-Mgmt) → T13 tests
- AC11 (Integration) → T14 tests
- AC12 (Documentation) → T15 tasks

**Go/No-Go Criteria**:
- **GO**: All P0 tests pass, P1 tests >90% pass, QA evidence collected
- **NO-GO**: Any P0 test fails, critical risks not mitigated, insufficient evidence

**Artifacts**:
- Full test design: `docs/qa/assessments/STORY-VALIDATE-NETWORKING-test-design-20251026.md` (to be created)
- Test execution results: `docs/qa/evidence/VALIDATE-NET-*.txt` (created during execution)

## *** End of Story ***
