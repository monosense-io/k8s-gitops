# Talos Multi-Cluster Bootstrap Guide

**Purpose:** Convert single 6-node cluster into two 3-node clusters (infra + apps)
**Based on:** Existing Taskfile automation + ADR decisions
**Date:** 2025-10-14

---

## Current vs Target Architecture

### Current Setup (Single Cluster)
```yaml
Cluster: k8s
Endpoint: k8s.monosense.io:6443
PodCIDR: 10.244.0.0/16
ServiceCIDR: 10.245.0.0/16
Nodes: 6 controlplane nodes (10.25.11.11-16)
```

### Target Setup (Multi-Cluster)
```yaml
Infra Cluster:
  Name: infra
  Endpoint: infra.k8s.monosense.io:6443
  PodCIDR: 10.244.0.0/16
  ServiceCIDR: 10.245.0.0/16
  Nodes: 10.25.11.11-13 (3 controlplane)

Apps Cluster:
  Name: apps
  Endpoint: apps.k8s.monosense.io:6443
  PodCIDR: 10.246.0.0/16  # Different!
  ServiceCIDR: 10.247.0.0/16  # Different!
  Nodes: 10.25.11.14-16 (3 controlplane)
```

---

## Prerequisites

### 1. DNS Records
Create DNS records for both clusters:
```bash
# Add to your DNS (Cloudflare or internal)
infra.k8s.monosense.io → 10.25.11.11
apps.k8s.monosense.io → 10.25.11.14
```

### 2. 1Password Secrets
You'll need separate secrets for each cluster. Create in 1Password:

**Infra Cluster** (`infra-talos` item in "Prod" vault):
```
MACHINE_TOKEN: <generate new>
MACHINE_CA_CRT: <generate new>
MACHINE_CA_KEY: <generate new>
CLUSTER_ID: <generate new>
CLUSTER_SECRET: <generate new>
CLUSTER_TOKEN: <generate new>
CLUSTER_CA_CRT: <generate new>
CLUSTER_CA_KEY: <generate new>
CLUSTER_AGGREGATORCA_CRT: <generate new>
CLUSTER_AGGREGATORCA_KEY: <generate new>
CLUSTER_ETCD_CA_CRT: <generate new>
CLUSTER_ETCD_CA_KEY: <generate new>
CLUSTER_SERVICEACCOUNT_KEY: <generate new>
CLUSTER_SECRETBOXENCRYPTIONSECRET: <generate new>
```

**Apps Cluster** (`apps-talos` item in "Prod" vault):
```
[Same fields as above, all with different values]
```

**Generate secrets**:
```bash
# Machine token (for each cluster)
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml

# Extract and store in 1Password manually, or use:
task op:push-secrets
```

---

## Step 1: Update machineconfig.yaml.j2

Your current `machineconfig.yaml.j2` is hard-coded for single cluster. Create a multi-cluster version:

```bash
# Backup current config
cp talos/machineconfig.yaml.j2 talos/machineconfig.yaml.j2.backup
```

Update `talos/machineconfig.yaml.j2`:

```jinja2
---
version: v1alpha1
machine:
  type: {{ machinetype }}
  token: op://Prod/{{ cluster }}-talos/MACHINE_TOKEN
  ca:
    crt: op://Prod/{{ cluster }}-talos/MACHINE_CA_CRT
    {% if machinetype == 'controlplane' %}
    key: op://Prod/{{ cluster }}-talos/MACHINE_CA_KEY
    {% endif %}
  features:
    rbac: true
    stableHostname: true
    {% if machinetype == 'controlplane' %}
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles: ["os:admin"]
      allowedKubernetesNamespaces: ["actions-runner-system", "system-upgrade"]
    {% endif %}
    apidCheckExtKeyUsage: true
    diskQuotaSupport: true
    kubePrism:
      enabled: true
      port: 7445
    hostDNS:
      enabled: true
      resolveMemberNames: true
      forwardKubeDNSToHost: false
  files:
    - op: create
      path: /etc/cri/conf.d/20-customization.part
      content: |
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
        [plugins."io.containerd.cri.v1.runtime"]
          device_ownership_from_security_context = true
    - op: overwrite
      path: /etc/nfsmount.conf
      permissions: 0o644
      content: |
        [ NFSMount_Global_Options ]
        nfsvers=4.1
        hard=True
        nconnect=8
        noatime=True
        rsize=1048576
        wsize=1048576
  install:
    image: factory.talos.dev/metal-installer/d60a9a96a6bbc418c786ee44fd5c01137d9a02497012cf080722ee79d3ee6d7e:v1.11.2
  kernel:
    modules:
      - name: nbd
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.34.1
    extraConfig:
      featureGates:
        ImageVolume: true
      serializeImagePulls: false
    defaultRuntimeSeccompProfileEnabled: true
    nodeIP:
      validSubnets: ["10.25.11.0/24"]
    disableManifestsDirectory: true
  network:
    interfaces:
      - interface: eno1
        ignore: true
    nameservers: ["10.25.10.30"]
    disableSearchDomain: true
  nodeLabels:
    topology.kubernetes.io/region: {{ cluster }}
    topology.kubernetes.io/zone: {{ 'm' if machinetype == 'controlplane' else 'w' }}
    cluster: {{ cluster }}
  sysctls:
    fs.inotify.max_user_watches: 1048576
    fs.inotify.max_user_instances: 8192
    net.core.default_qdisc: fq
    net.core.rmem_max: 67108864
    net.core.wmem_max: 67108864
    net.ipv4.tcp_congestion_control: bbr
    net.ipv4.tcp_fastopen: 3
    net.ipv4.tcp_mtu_probing: 1
    net.ipv4.tcp_rmem: 4096 87380 33554432
    net.ipv4.tcp_wmem: 4096 65536 33554432
    net.ipv4.tcp_window_scaling: 1
    sunrpc.tcp_slot_table_entries: 128
    sunrpc.tcp_max_slot_table_entries: 128
    user.max_user_namespaces: 11255
    vm.nr_hugepages: 1024
  time:
    disabled: false
    servers: ["time.cloudflare.com"]
cluster:
  ca:
    crt: op://Prod/{{ cluster }}-talos/CLUSTER_CA_CRT
    {% if machinetype == 'controlplane' %}
    key: op://Prod/{{ cluster }}-talos/CLUSTER_CA_KEY
    {% endif %}
  clusterName: {{ cluster }}
  controlPlane:
    endpoint: https://{{ cluster }}.k8s.monosense.io:6443
  discovery:
    enabled: true
    registries:
      kubernetes: { disabled: true }
      service: { disabled: false }
  id: op://Prod/{{ cluster }}-talos/CLUSTER_ID
  network:
    cni:
      name: none
    dnsDomain: cluster.local
    podSubnets: {{ pod_subnets }}
    serviceSubnets: {{ service_subnets }}
  secret: op://Prod/{{ cluster }}-talos/CLUSTER_SECRET
  token: op://Prod/{{ cluster }}-talos/CLUSTER_TOKEN
  {% if machinetype == 'controlplane' %}
  aggregatorCA:
    crt: op://Prod/{{ cluster }}-talos/CLUSTER_AGGREGATORCA_CRT
    key: op://Prod/{{ cluster }}-talos/CLUSTER_AGGREGATORCA_KEY
  allowSchedulingOnControlPlanes: true
  apiServer:
    image: registry.k8s.io/kube-apiserver:v1.34.1
    extraArgs:
      enable-aggregator-routing: true
      feature-gates: ImageVolume=true
    certSANs: ["{{ cluster }}.k8s.monosense.io"]
    disablePodSecurityPolicy: true
  controllerManager:
    image: registry.k8s.io/kube-controller-manager:v1.34.1
    extraArgs: { bind-address: 0.0.0.0 }
  coreDNS: { disabled: true }
  etcd:
    advertisedSubnets: ["10.25.11.0/24"]
    ca:
      crt: op://Prod/{{ cluster }}-talos/CLUSTER_ETCD_CA_CRT
      key: op://Prod/{{ cluster }}-talos/CLUSTER_ETCD_CA_KEY
    extraArgs: { listen-metrics-urls: http://0.0.0.0:2381 }
  proxy:
    disabled: true
    image: registry.k8s.io/kube-proxy:v1.34.1
  secretboxEncryptionSecret: op://Prod/{{ cluster }}-talos/CLUSTER_SECRETBOXENCRYPTIONSECRET
  scheduler:
    image: registry.k8s.io/kube-scheduler:v1.34.1
    extraArgs: { bind-address: 0.0.0.0 }
    config:
      apiVersion: kubescheduler.config.k8s.io/v1
      kind: KubeSchedulerConfiguration
      profiles:
        - schedulerName: default-scheduler
          plugins:
            score:
              disabled: [{ name: ImageLocality }]
          pluginConfig:
            - name: PodTopologySpread
              args:
                defaultingType: List
                defaultConstraints:
                  - maxSkew: 1
                    topologyKey: kubernetes.io/hostname
                    whenUnsatisfiable: ScheduleAnyway
  serviceAccount:
    key: op://Prod/{{ cluster }}-talos/CLUSTER_SERVICEACCOUNT_KEY
  {% endif %}
---
apiVersion: v1alpha1
kind: UserVolumeConfig
name: openebs
provisioning:
  diskSelector:
    match: disk.model == "TEAM TM8FP6512G" && !system_disk
  minSize: 500GiB
---
apiVersion: v1alpha1
kind: WatchdogTimerConfig
device: /dev/watchdog0
timeout: 5m
```

**Key changes:**
- `cluster` variable for cluster name
- `pod_subnets` and `service_subnets` as lists
- Dynamic 1Password paths: `op://Prod/{{ cluster }}-talos/...`
- Cluster-specific labels

---

## Step 2: Update .taskfiles/talos/Taskfile.yaml

Update the `apply-node` and `re-apply-node` tasks to support cluster-specific configs:

```yaml
---
version: '3'

tasks:

  apply-node:
    desc: Apply Talos config to a node [NODE=required] [MODE=auto] [MACHINE_TYPE=controlplane] [CLUSTER=required]
    cmd: |
      minijinja-cli \
        --define "machinetype={{.MACHINE_TYPE}}" \
        --define "cluster={{.CLUSTER}}" \
        --define "pod_subnets={{.POD_SUBNETS}}" \
        --define "service_subnets={{.SERVICE_SUBNETS}}" \
        {{.TALOS_DIR}}/machineconfig.yaml.j2 \
        | op inject \
        | talosctl --nodes {{.NODE}} apply-config \
          --mode {{.MODE}} \
          --config-patch @{{.TALOS_DIR}}/{{.CLUSTER}}/{{.NODE}}.yaml \
          --file /dev/stdin {{if .INSECURE}}--insecure{{end}}
    vars:
      MODE: '{{.MODE | default "auto"}}'
      MACHINE_TYPE: '{{.MACHINE_TYPE}}'
      CLUSTER: '{{.CLUSTER}}'
      POD_SUBNETS: '{{ if eq .CLUSTER "infra" }}["10.244.0.0/16"]{{ else }}["10.246.0.0/16"]{{ end }}'
      SERVICE_SUBNETS: '{{ if eq .CLUSTER "infra" }}["10.245.0.0/16"]{{ else }}["10.247.0.0/16"]{{ end }}'
      INSECURE:
        sh: talosctl --nodes {{.NODE}} get machineconfig &> /dev/null || echo true
    requires:
      vars: [NODE, CLUSTER]
    preconditions:
      - op user get --me
      - talosctl config info
      - test -f {{.TALOS_DIR}}/machineconfig.yaml.j2
      - test -f {{.TALOS_DIR}}/{{.CLUSTER}}/{{.NODE}}.yaml
      - which curl jq minijinja-cli op talosctl

  re-apply-node:
    desc: Re-apply Talos config to a node [NODE=required] [MODE=auto] [CLUSTER=required]
    cmd: |
      minijinja-cli \
        --define "machinetype={{.MACHINE_TYPE}}" \
        --define "cluster={{.CLUSTER}}" \
        --define "pod_subnets={{.POD_SUBNETS}}" \
        --define "service_subnets={{.SERVICE_SUBNETS}}" \
        {{.TALOS_DIR}}/machineconfig.yaml.j2 \
        | op inject \
        | talosctl --nodes {{.NODE}} apply-config \
          --mode {{.MODE}} \
          --config-patch @{{.TALOS_DIR}}/{{.CLUSTER}}/{{.NODE}}.yaml \
          --file /dev/stdin {{if .INSECURE}}--insecure{{end}}
    vars:
      MODE: '{{.MODE | default "auto"}}'
      CLUSTER: '{{.CLUSTER}}'
      POD_SUBNETS: '{{ if eq .CLUSTER "infra" }}["10.244.0.0/16"]{{ else }}["10.246.0.0/16"]{{ end }}'
      SERVICE_SUBNETS: '{{ if eq .CLUSTER "infra" }}["10.245.0.0/16"]{{ else }}["10.247.0.0/16"]{{ end }}'
      INSECURE:
        sh: talosctl --nodes {{.NODE}} get machineconfig &> /dev/null || echo true
      MACHINE_TYPE:
        sh: |-
          talosctl --nodes {{.NODE}} get machinetypes --output=jsonpath='{.spec}' 2> /dev/null \
            || basename $(find '{{.TALOS_DIR}}' -name '{{.NODE}}.yaml' -printf '%h')
    requires:
      vars: [NODE, CLUSTER]
    preconditions:
      - op user get --me
      - talosctl config info
      - test -f {{.TALOS_DIR}}/machineconfig.yaml.j2
      - test -f {{.TALOS_DIR}}/{{.CLUSTER}}/{{.NODE}}.yaml
      - which minijinja-cli op talosctl

  # Other tasks (upgrade-node, reboot-node, etc.) remain unchanged
  # They use talosctl context, so they're cluster-aware automatically
```

---

## Step 3: Reorganize Node Configs

Move node configs into cluster-specific directories:

```bash
# Create cluster directories
mkdir -p talos/infra talos/apps

# Move infra nodes (10.25.11.11-13)
mv talos/controlplane/10.25.11.11.yaml talos/infra/
mv talos/controlplane/10.25.11.12.yaml talos/infra/
mv talos/controlplane/10.25.11.13.yaml talos/infra/

# Move apps nodes (10.25.11.14-16)
mv talos/controlplane/10.25.11.14.yaml talos/apps/
mv talos/controlplane/10.25.11.15.yaml talos/apps/
mv talos/controlplane/10.25.11.16.yaml talos/apps/

# Remove old controlplane directory
rmdir talos/controlplane
```

**Update node hostnames** in each file:

`talos/infra/10.25.11.11.yaml`:
```yaml
---
machine:
  network:
    hostname: infra-01  # Changed from prod-01
    # ... rest of config
```

`talos/infra/10.25.11.12.yaml`:
```yaml
machine:
  network:
    hostname: infra-02
```

`talos/infra/10.25.11.13.yaml`:
```yaml
machine:
  network:
    hostname: infra-03
```

`talos/apps/10.25.11.14.yaml`:
```yaml
machine:
  network:
    hostname: apps-01  # Changed from prod-04
```

`talos/apps/10.25.11.15.yaml`:
```yaml
machine:
  network:
    hostname: apps-02
```

`talos/apps/10.25.11.16.yaml`:
```yaml
machine:
  network:
    hostname: apps-03
```

---

## Step 4: Deploy Infra Cluster

### 4.1 Generate and Validate Config

```bash
# Test config generation for infra node
minijinja-cli \
  --define "machinetype=controlplane" \
  --define "cluster=infra" \
  --define "pod_subnets=[\"10.244.0.0/16\"]" \
  --define "service_subnets=[\"10.245.0.0/16\"]" \
  talos/machineconfig.yaml.j2 \
  | op inject \
  > /tmp/infra-test.yaml

# Validate
talosctl validate --config /tmp/infra-test.yaml
```

### 4.2 Apply Configs to Infra Nodes

```bash
# Apply to all infra nodes
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.12 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.13 CLUSTER=infra MACHINE_TYPE=controlplane
```

### 4.3 Bootstrap Infra Cluster

```bash
# Update talosconfig context
talosctl config endpoint 10.25.11.11 10.25.11.12 10.25.11.13
talosctl config node 10.25.11.11

# Bootstrap
talosctl bootstrap --nodes 10.25.11.11

# Wait for cluster ready
talosctl health --nodes 10.25.11.11

# Generate kubeconfig
talosctl kubeconfig --nodes 10.25.11.11 --force kubernetes/infra-kubeconfig

# Verify
export KUBECONFIG=kubernetes/infra-kubeconfig
kubectl get nodes
```

Expected output:
```
NAME       STATUS     ROLES           AGE   VERSION
infra-01   NotReady   control-plane   1m    v1.34.1
infra-02   NotReady   control-plane   1m    v1.34.1
infra-03   NotReady   control-plane   1m    v1.34.1
```

(NotReady is expected - no CNI yet)

---

## Step 5: Deploy Apps Cluster

### 5.1 Apply Configs to Apps Nodes

```bash
# Apply to all apps nodes
task talos:apply-node NODE=10.25.11.14 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.15 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.16 CLUSTER=apps MACHINE_TYPE=controlplane
```

### 5.2 Bootstrap Apps Cluster

```bash
# Update talosconfig for apps cluster
talosctl config context apps --nodes 10.25.11.14,10.25.11.15,10.25.11.16 --endpoints 10.25.11.14
talosctl config context infra --nodes 10.25.11.11,10.25.11.12,10.25.11.13 --endpoints 10.25.11.11

# Switch to apps context
talosctl config context apps

# Bootstrap
talosctl bootstrap --nodes 10.25.11.14

# Wait for cluster ready
talosctl health --nodes 10.25.11.14

# Generate kubeconfig
talosctl kubeconfig --nodes 10.25.11.14 --force kubernetes/apps-kubeconfig

# Verify
export KUBECONFIG=kubernetes/apps-kubeconfig
kubectl get nodes
```

Expected output:
```
NAME      STATUS     ROLES           AGE   VERSION
apps-01   NotReady   control-plane   1m    v1.34.1
apps-02   NotReady   control-plane   1m    v1.34.1
apps-03   NotReady   control-plane   1m    v1.34.1
```

---

## Step 6: Configure Multi-Context kubectl

Merge kubeconfigs for easy switching:

```bash
# Set cluster names in kubeconfigs
kubectl config rename-context admin@infra infra --kubeconfig kubernetes/infra-kubeconfig
kubectl config rename-context admin@apps apps --kubeconfig kubernetes/apps-kubeconfig

# Merge configs
KUBECONFIG=kubernetes/infra-kubeconfig:kubernetes/apps-kubeconfig \
  kubectl config view --flatten > kubernetes/kubeconfig

# Set default context
kubectl config use-context infra --kubeconfig kubernetes/kubeconfig

# Test switching
kubectl config use-context infra && kubectl get nodes
kubectl config use-context apps && kubectl get nodes
```

Update `Taskfile.yaml` to use merged config:
```yaml
env:
  KUBECONFIG: '{{.KUBERNETES_DIR}}/kubeconfig'  # Already correct!
```

---

## Step 7: Verify Multi-Cluster Setup

### 7.1 Check Both Clusters

```bash
# Infra cluster
kubectl --context infra get nodes -o wide

# Apps cluster
kubectl --context apps get nodes -o wide

# Verify Pod/Service CIDRs are different
kubectl --context infra cluster-info dump | grep -E "service-cluster-ip-range|cluster-cidr"
kubectl --context apps cluster-info dump | grep -E "service-cluster-ip-range|cluster-cidr"
```

### 7.2 Verify Network Configuration

```bash
# Infra cluster
kubectl --context infra get nodes -o jsonpath='{.items[*].spec.podCIDR}'
# Should show: 10.244.0.0/24 10.244.1.0/24 10.244.2.0/24

# Apps cluster
kubectl --context apps get nodes -o jsonpath='{.items[*].spec.podCIDR}'
# Should show: 10.246.0.0/24 10.246.1.0/24 10.246.2.0/24
```

---

## Step 8: Update .taskfiles/bootstrap/Taskfile.yaml

Create separate bootstrap tasks for each cluster:

```yaml
---
version: '3'

tasks:

  talos-infra:
    desc: Bootstrap Talos Infra Cluster
    prompt: Bootstrap Talos Infra Cluster ...?
    cmds:
      - talosctl --context infra --nodes {{.RANDOM_CONTROLLER}} bootstrap
      - talosctl --context infra kubeconfig --nodes {{.RANDOM_CONTROLLER}} --force {{.KUBERNETES_DIR}}/infra-kubeconfig
    vars:
      RANDOM_CONTROLLER:
        sh: echo "10.25.11.11"  # Or random selection
    preconditions:
      - talosctl config get-contexts | grep infra
      - which talosctl

  talos-apps:
    desc: Bootstrap Talos Apps Cluster
    prompt: Bootstrap Talos Apps Cluster ...?
    cmds:
      - talosctl --context apps --nodes {{.RANDOM_CONTROLLER}} bootstrap
      - talosctl --context apps kubeconfig --nodes {{.RANDOM_CONTROLLER}} --force {{.KUBERNETES_DIR}}/apps-kubeconfig
    vars:
      RANDOM_CONTROLLER:
        sh: echo "10.25.11.14"
    preconditions:
      - talosctl config get-contexts | grep apps
      - which talosctl

  merge-kubeconfigs:
    desc: Merge infra and apps kubeconfigs
    cmds:
      - kubectl config rename-context admin@infra infra --kubeconfig {{.KUBERNETES_DIR}}/infra-kubeconfig
      - kubectl config rename-context admin@apps apps --kubeconfig {{.KUBERNETES_DIR}}/apps-kubeconfig
      - KUBECONFIG={{.KUBERNETES_DIR}}/infra-kubeconfig:{{.KUBERNETES_DIR}}/apps-kubeconfig kubectl config view --flatten > {{.KUBERNETES_DIR}}/kubeconfig
      - kubectl config use-context infra --kubeconfig {{.KUBERNETES_DIR}}/kubeconfig
    preconditions:
      - test -f {{.KUBERNETES_DIR}}/infra-kubeconfig
      - test -f {{.KUBERNETES_DIR}}/apps-kubeconfig

  apps-infra:
    desc: Bootstrap Kubernetes Apps on Infra Cluster
    prompt: Bootstrap Infra Cluster Apps ...?
    cmds:
      - kubectl --context infra config set-cluster infra --server https://10.25.11.11:6443
      - defer: task talos:generate-kubeconfig
      - until kubectl --context infra wait nodes --for=condition=Ready=False --all --timeout=10m; do sleep 5; done
      - op inject --in-file {{.BOOTSTRAP_DIR}}/infra/secrets.yaml.tpl | kubectl --context infra apply --server-side --filename -
      - helmfile --file {{.BOOTSTRAP_DIR}}/infra/helmfile.d/00-crds.yaml --kube-context infra template --quiet | kubectl --context infra apply --server-side --filename -
      - helmfile --file {{.BOOTSTRAP_DIR}}/infra/helmfile.d/01-apps.yaml --kube-context infra sync --hide-notes

  apps-apps:
    desc: Bootstrap Kubernetes Apps on Apps Cluster
    prompt: Bootstrap Apps Cluster Apps ...?
    cmds:
      - kubectl --context apps config set-cluster apps --server https://10.25.11.14:6443
      - defer: task talos:generate-kubeconfig
      - until kubectl --context apps wait nodes --for=condition=Ready=False --all --timeout=10m; do sleep 5; done
      - op inject --in-file {{.BOOTSTRAP_DIR}}/apps/secrets.yaml.tpl | kubectl --context apps apply --server-side --filename -
      - helmfile --file {{.BOOTSTRAP_DIR}}/apps/helmfile.d/00-crds.yaml --kube-context apps template --quiet | kubectl --context apps apply --server-side --filename -
      - helmfile --file {{.BOOTSTRAP_DIR}}/apps/helmfile.d/01-apps.yaml --kube-context apps sync --hide-notes
```

---

## Step 9: Next Steps (FluxCD Bootstrap)

Now that both Talos clusters are ready, proceed with FluxCD:

```bash
# Bootstrap Flux on infra cluster
flux bootstrap github \
  --owner=<your-org> \
  --repository=k8s-gitops \
  --branch=main \
  --path=clusters/infra \
  --context=infra \
  --personal

# Bootstrap Flux on apps cluster
flux bootstrap github \
  --owner=<your-org> \
  --repository=k8s-gitops \
  --branch=main \
  --path=clusters/apps \
  --context=apps \
  --personal
```

---

## Troubleshooting

### Issue: Nodes won't bootstrap
```bash
# Check Talos logs
talosctl --context infra logs --nodes 10.25.11.11 --follow

# Check etcd
talosctl --context infra etcd members --nodes 10.25.11.11
```

### Issue: PodCIDR overlap
```bash
# Verify CIDRs are different
kubectl --context infra get nodes -o jsonpath='{.items[*].spec.podCIDR}'
kubectl --context apps get nodes -o jsonpath='{.items[*].spec.podCIDR}'

# If same, re-apply configs with correct pod_subnets/service_subnets
```

### Issue: Certificate errors
```bash
# Regenerate secrets in 1Password
# Re-apply configs
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane MODE=staged-no-reboot
talosctl --context infra --nodes 10.25.11.11 reboot
```

---

## Summary Checklist

- [ ] DNS records created (infra.k8s.monosense.io, apps.k8s.monosense.io)
- [ ] 1Password secrets created (infra-talos, apps-talos)
- [ ] machineconfig.yaml.j2 updated with cluster variables
- [ ] Taskfile updated with CLUSTER parameter
- [ ] Node configs reorganized (talos/infra/, talos/apps/)
- [ ] Infra cluster deployed (10.25.11.11-13)
- [ ] Apps cluster deployed (10.25.11.14-16)
- [ ] Both clusters bootstrapped
- [ ] Kubeconfigs merged
- [ ] PodCIDRs verified as non-overlapping
- [ ] Ready for FluxCD + Cilium ClusterMesh!

---

## Quick Start Command Reference

Complete command sequence for converting single cluster to multi-cluster:

### Phase 1: Preparation (10 minutes)

```bash
# 1. Backup current config
cp talos/machineconfig.yaml.j2 talos/machineconfig.yaml.j2.backup

# 2. Create cluster directories
mkdir -p talos/infra talos/apps

# 3. Move infra nodes (10.25.11.11-13)
mv talos/controlplane/10.25.11.11.yaml talos/infra/
mv talos/controlplane/10.25.11.12.yaml talos/infra/
mv talos/controlplane/10.25.11.13.yaml talos/infra/

# 4. Move apps nodes (10.25.11.14-16)
mv talos/controlplane/10.25.11.14.yaml talos/apps/
mv talos/controlplane/10.25.11.15.yaml talos/apps/
mv talos/controlplane/10.25.11.16.yaml talos/apps/
rmdir talos/controlplane

# 5. Update hostnames in each node config (use editor)
# talos/infra/10.25.11.11.yaml → hostname: infra-01
# talos/infra/10.25.11.12.yaml → hostname: infra-02
# talos/infra/10.25.11.13.yaml → hostname: infra-03
# talos/apps/10.25.11.14.yaml → hostname: apps-01
# talos/apps/10.25.11.15.yaml → hostname: apps-02
# talos/apps/10.25.11.16.yaml → hostname: apps-03

# 6. Update machineconfig.yaml.j2 (see Step 1 in guide)
# 7. Update .taskfiles/talos/Taskfile.yaml (see Step 2 in guide)
# 8. Update .taskfiles/bootstrap/Taskfile.yaml (see Step 8 in guide)
```

### Phase 2: DNS and Secrets (15 minutes)

```bash
# 9. Add DNS records in Cloudflare/your DNS provider
# infra.k8s.monosense.io → 10.25.11.11
# apps.k8s.monosense.io → 10.25.11.14

# 10. Generate secrets for both clusters
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml

# 11. Create 1Password items (manual or script)
# Create "infra-talos" item in Prod vault with secrets from /tmp/infra-secrets.yaml
# Create "apps-talos" item in Prod vault with secrets from /tmp/apps-secrets.yaml

# 12. Test config generation
minijinja-cli \
  --define "machinetype=controlplane" \
  --define "cluster=infra" \
  --define "pod_subnets=[\"10.244.0.0/16\"]" \
  --define "service_subnets=[\"10.245.0.0/16\"]" \
  talos/machineconfig.yaml.j2 | op inject | talosctl validate --config -
```

### Phase 3: Deploy Infra Cluster (20 minutes)

```bash
# 13. Apply configs to infra nodes
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.12 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.13 CLUSTER=infra MACHINE_TYPE=controlplane

# 14. Create talosconfig context for infra
talosctl config endpoint 10.25.11.11 10.25.11.12 10.25.11.13
talosctl config node 10.25.11.11

# 15. Bootstrap infra cluster
talosctl bootstrap --nodes 10.25.11.11

# 16. Wait for health check (2-5 minutes)
talosctl health --wait-timeout 10m

# 17. Generate kubeconfig
talosctl kubeconfig --nodes 10.25.11.11 --force kubernetes/infra-kubeconfig

# 18. Verify infra cluster
export KUBECONFIG=kubernetes/infra-kubeconfig
kubectl get nodes -o wide
# Expected: infra-01, infra-02, infra-03 (NotReady - no CNI yet)
```

### Phase 4: Deploy Apps Cluster (20 minutes)

```bash
# 19. Apply configs to apps nodes
task talos:apply-node NODE=10.25.11.14 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.15 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.16 CLUSTER=apps MACHINE_TYPE=controlplane

# 20. Create talosconfig context for apps
talosctl config context apps \
  --nodes 10.25.11.14,10.25.11.15,10.25.11.16 \
  --endpoints 10.25.11.14

talosctl config context infra \
  --nodes 10.25.11.11,10.25.11.12,10.25.11.13 \
  --endpoints 10.25.11.11

# 21. Switch to apps context and bootstrap
talosctl config context apps
talosctl bootstrap --nodes 10.25.11.14

# 22. Wait for health check
talosctl health --wait-timeout 10m

# 23. Generate kubeconfig
talosctl kubeconfig --nodes 10.25.11.14 --force kubernetes/apps-kubeconfig

# 24. Verify apps cluster
export KUBECONFIG=kubernetes/apps-kubeconfig
kubectl get nodes -o wide
# Expected: apps-01, apps-02, apps-03 (NotReady - no CNI yet)
```

### Phase 5: Multi-Context Setup (5 minutes)

```bash
# 25. Merge kubeconfigs
kubectl config rename-context admin@infra infra --kubeconfig kubernetes/infra-kubeconfig
kubectl config rename-context admin@apps apps --kubeconfig kubernetes/apps-kubeconfig

KUBECONFIG=kubernetes/infra-kubeconfig:kubernetes/apps-kubeconfig \
  kubectl config view --flatten > kubernetes/kubeconfig

kubectl config use-context infra --kubeconfig kubernetes/kubeconfig

# 26. Test context switching
export KUBECONFIG=kubernetes/kubeconfig
kubectl config use-context infra && kubectl get nodes
kubectl config use-context apps && kubectl get nodes

# 27. Verify PodCIDRs are different
kubectl --context infra get nodes -o jsonpath='{.items[*].spec.podCIDR}{"\n"}'
# Expected: 10.244.0.0/24 10.244.1.0/24 10.244.2.0/24

kubectl --context apps get nodes -o jsonpath='{.items[*].spec.podCIDR}{"\n"}'
# Expected: 10.246.0.0/24 10.246.1.0/24 10.246.2.0/24
```

### Phase 6: Bootstrap Directories (Optional - for Helmfile bootstrap)

```bash
# 28. Create cluster-specific bootstrap directories
mkdir -p bootstrap/infra/helmfile.d bootstrap/apps/helmfile.d

# 29. Copy or create bootstrap configs for each cluster
# See Step 8 in guide for task updates
# See implementation-timeline.md for FluxCD structure
```

### Total Time: ~70 minutes + testing

### Next Steps After Bootstrap

1. **Deploy Cilium on both clusters** (Week 1 - Day 1 in implementation-timeline.md)
2. **Configure Cilium ClusterMesh** (Week 1 - Day 2)
3. **Bootstrap FluxCD** (Week 1 - Day 3)
4. **Deploy Rook Ceph on infra cluster** (Week 3 - Day 1)
5. **Follow 10-week implementation timeline** (implementation-timeline.md)

---

*Talos Multi-Cluster Bootstrap Guide - v1.1*
*Based on existing Taskfile automation*
