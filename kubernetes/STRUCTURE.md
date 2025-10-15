## Kubernetes GitOps Layout

```
kubernetes/
├── bases/                     # Reusable primitives (HelmReleases, CRDs)
│   ├── cilium/
│   ├── cert-manager/
│   ├── coredns/
│   ├── fluent-bit/
│   ├── flux/
│   ├── openebs/
│   ├── rook-ceph-cluster/
│   ├── rook-ceph-operator/
│   ├── spegel/
│   ├── victoria-logs/
│   └── victoria-metrics-stack/
│
├── infrastructure/            # Platform capabilities promoted to clusters
│   ├── gitops/
│   │   └── flux/
│   ├── networking/
│   │   ├── cilium/            # Cilium w/ BGP, Gateway API (Envoy), ClusterMesh
│   │   ├── coredns/
│   │   └── spegel/
│   ├── security/
│   │   ├── external-secrets/
│   │   └── cert-manager/
│   └── storage/
│       ├── openebs/
│       └── rook-ceph/
│
├── workloads/                 # Platform & tenant application overlays
│   ├── platform/
│   │   ├── databases/
│   │   │   ├── cloudnative-pg/
│   │   │   └── dragonfly/
│   │   └── observability/
│   └── tenants/
│
└── clusters/                  # Flux entry-points per cluster
    ├── infra/
    │   ├── flux-system/       # Bootstrap (GitRepository + sync)
    │   ├── infrastructure.yaml
    │   └── workloads.yaml
    └── apps/
        ├── flux-system/
        ├── infrastructure.yaml
        └── workloads.yaml
```

### Key Concepts

- **bases/** contains the minimal building blocks. Nothing is cluster-aware.
- **infrastructure/** composes the bases into functional stacks (networking, security, etc.).
- **storage/** bundles Rook-Ceph and OpenEBS so every cluster gets NVMe-backed block and hostpath classes.
- **workloads/** is where platform services and tenant apps live. `platform/databases` exposes CloudNativePG and Dragonfly (annotated with `service.cilium.io/global: "true"`) for cross-cluster access, while `platform/observability` ships the VictoriaMetrics + VictoriaLogs stack and Fluent Bit only to the infra cluster.
- **clusters/** contains every Flux reconciliation surface. Each cluster renders variables through
  `postBuild.substitute` to apply CIDRs, BGP ASN, ClusterMesh secrets, and domain-specific values.
- **Flux controllers** are managed via the `gitops/flux` HelmRelease once bootstrapped with
  `task bootstrap:<cluster>`.

### Cilium Enhancements

- **BGP Control Plane**: `CiliumBGPPeeringPolicy` advertises PodCIDRs and LoadBalancers to upstream routers.
- **Gateway API (Envoy)**: Enabled through Helm values and a shared `GatewayClass`.
- **ClusterMesh**: Helm values expose the mesh API, and `ExternalSecret` pulls the mesh secret from your secret store.

Extend the structure by adding new stacks under `infrastructure/` or onboarding apps under
`workloads/tenants/` with dedicated Flux `Kustomization` objects.
