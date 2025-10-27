# DNS Runbook — Kubernetes API via BIND (DNS Round‑Robin)

This runbook shows how to expose your Kubernetes API endpoints using DNS round‑robin (no external load balancer). It matches Option A in the story: clients connect to `infra-k8s.monosense.io:6443` and `apps-k8s.monosense.io:6443`.

Assumptions
- Authoritative internal DNS: BIND at `10.25.10.30`
- Zone: `monosense.io`
- Control‑plane node IPs:
  - Infra: `10.25.11.11`, `10.25.11.12`, `10.25.11.13`
  - Apps: `10.25.11.14`, `10.25.11.15`, `10.25.11.16`
- Talos apiserver SAN includes `<cluster>-k8s.monosense.io`

Zone declaration (named.conf.local)
```
zone "monosense.io" IN {
    type master;
    file "/etc/bind/zones/db.monosense.io";
    allow-update { none; };
};
```

Zone file (`/etc/bind/zones/db.monosense.io`)
```
$TTL 300
@   IN  SOA ns1.monosense.io. dns-admin.monosense.io. (
        2025102701 ; serial (YYYYMMDDnn)
        3600       ; refresh
        900        ; retry
        1209600    ; expire
        300 )      ; minimum
    IN  NS  ns1.monosense.io.

ns1          IN  A    10.25.10.30

; Kubernetes API — DNS round‑robin per cluster
infra-k8s    IN  A    10.25.11.11
infra-k8s    IN  A    10.25.11.12
infra-k8s    IN  A    10.25.11.13

apps-k8s     IN  A    10.25.11.14
apps-k8s     IN  A    10.25.11.15
apps-k8s     IN  A    10.25.11.16
```

Optional: randomize answer order
```
rrset-order { order random; }
```

Reload and verify
```
named-checkzone monosense.io /etc/bind/zones/db.monosense.io
rndc reload monosense.io

dig +short infra-k8s.monosense.io @10.25.10.30
dig +short apps-k8s.monosense.io @10.25.10.30
```

Maintenance with nsupdate (drain/return a control‑plane node)
```
nsupdate
server 10.25.10.30
zone monosense.io
update delete infra-k8s.monosense.io A 10.25.11.12
send
```
Bring it back after maintenance (short TTL during bring‑up suggested):
```
nsupdate
server 10.25.10.30
zone monosense.io
update add infra-k8s.monosense.io 300 A 10.25.11.12
send
```

Split‑horizon (internal only)
```
view "internal" {
  match-clients { 10.25.0.0/16; 127.0.0.1; };
  recursion yes;
  zone "monosense.io" { type master; file "/etc/bind/zones/db.monosense.io"; };
};
view "external" {
  match-clients { any; };
  recursion no;
};
```

Operational guardrails
- DNS RR is not health‑aware. Remove a node’s A record before planned apiserver maintenance; add it back when healthy.
- Keep TTLs low during changes (e.g., 300s), raise later (e.g., 3600s).
- Allow TCP/6443 from all nodes to all control‑plane IPs.
- Add a hostNetwork DaemonSet check to curl `https://infra-k8s.monosense.io:6443/version` and `https://apps-k8s.monosense.io:6443/version`.

Cilium alignment
- In cluster settings, set:
  - Infra: `K8S_SERVICE_HOST=infra-k8s.monosense.io`
  - Apps: `K8S_SERVICE_HOST=apps-k8s.monosense.io`
  - Both: `K8S_SERVICE_PORT="6443"`
- Ensure Helm values include `k8sServiceHost` and `k8sServicePort` (templated).

Notes
- You can migrate to a real VIP later (kube‑vip or HAProxy+Keepalived) without changing manifests; only the A records change.
