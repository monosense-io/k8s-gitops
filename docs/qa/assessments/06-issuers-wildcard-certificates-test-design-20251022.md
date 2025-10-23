# Test Design: Story 06

Date: 2025-10-22
Designer: Quinn (Test Architect)

## Test Strategy Overview

- Total test scenarios: 18
- Unit tests: 2 (11%)
- Integration tests: 10 (56%)
- E2E tests: 6 (33%)
- Priority distribution: P0: 8, P1: 6, P2: 4

## Test Scenarios by Acceptance Criteria

### AC1: cert-manager controller/webhook Available on infra/apps

#### Scenarios

| ID           | Level       | Priority | Test                              | Justification            |
| ------------ | ----------- | -------- | --------------------------------- | ------------------------ |
| 06-UNIT-001  | Unit        | P1       | Validate YAML syntax              | Pure configuration validation |
| 06-UNIT-002  | Unit        | P1       | Validate Kustomize overlays       | Pure build validation    |
| 06-INT-001   | Integration | P0       | cert-manager deployment health    | Core component availability |
| 06-INT-002   | Integration | P0       | webhook connectivity validation   | Critical for cert issuance |
| 06-INT-003   | Integration | P0       | CRD availability validation       | Required for operation   |
| 06-INT-004   | Integration | P1       | Flux Kustomization reconciliation | GitOps integration       |
| 06-E2E-001   | E2E         | P0       | Multi-cluster deployment validation | Cross-cluster consistency |

### AC2: ClusterIssuer Ready; wildcard Certificate Ready with a valid Secret

#### Scenarios

| ID           | Level       | Priority | Test                              | Justification            |
| ------------ | ----------- | -------- | --------------------------------- | ------------------------ |
| 06-INT-005   | Integration | P0       | ExternalSecret Cloudflare token sync | Prerequisite for DNS-01 |
| 06-INT-006   | Integration | P0       | ClusterIssuer staging readiness   | DNS-01 challenge validation |
| 06-INT-007   | Integration | P0       | ClusterIssuer production readiness | Production certificate issuance |
| 06-INT-008   | Integration | P0       | Wildcard certificate staging issuance | End-to-end certificate flow |
| 06-INT-009   | Integration | P0       | Wildcard certificate production issuance | Production certificate validation |
| 06-INT-010   | Integration | P1       | Certificate secret validation     | Certificate content verification |
| 06-E2E-002   | E2E         | P0       | DNS-01 challenge completion       | Real DNS integration     |
| 06-E2E-003   | E2E         | P1       | Certificate browser trust validation | End-user experience      |

### AC3: Metrics rules present and healthy

#### Scenarios

| ID           | Level       | Priority | Test                              | Justification            |
| ------------ | ----------- | -------- | --------------------------------- | ------------------------ |
| 06-INT-011   | Integration | P0       | PrometheusRule deployment validation | Monitoring availability   |
| 06-INT-012   | Integration | P1       | cert-manager metrics collection    | Observability validation |
| 06-E2E-004   | E2E         | P1       | Alerting rule functionality       | Operational readiness    |
| 06-E2E-005   | E2E         | P2       | Metrics dashboard validation      | Visualization confirmation |
| 06-E2E-006   | E2E         | P2       | Certificate expiration monitoring | Renewal assurance        |

## Risk Coverage

### High-Risk Areas Addressed

1. **Certificate Issuance Failure** (INT-005, INT-006, INT-007, E2E-002)
   - ExternalSecret sync failures
   - DNS-01 challenge failures
   - ClusterIssuer misconfiguration

2. **Multi-Cluster Inconsistency** (E2E-001)
   - Different configurations between infra/apps clusters
   - Flux reconciliation failures

3. **Security Certificate Validity** (INT-010, E2E-003)
   - Invalid or expired certificates
   - Browser trust issues

## Recommended Execution Order

### Phase 1: Infrastructure Validation (P0 Critical Path)
1. **Unit Tests** (06-UNIT-001, 06-UNIT-002) - Validate configuration syntax
2. **Deployment Tests** (06-INT-001, 06-INT-002, 06-INT-003) - Verify cert-manager health
3. **Secret Sync Tests** (06-INT-005) - Validate ExternalSecret operation
4. **Issuer Tests** (06-INT-006, 06-INT-007) - Validate ClusterIssuer readiness

### Phase 2: Certificate Flow Validation (P0 Critical Path)
5. **Staging Certificate Tests** (06-INT-008, E2E-002) - Validate DNS-01 challenge
6. **Production Certificate Tests** (06-INT-009, 06-INT-010, E2E-003) - Validate production issuance
7. **Multi-Cluster Tests** (E2E-001) - Validate cross-cluster consistency

### Phase 3: Monitoring and Operations (P1/P2)
8. **Monitoring Tests** (06-INT-011, 06-INT-012, E2E-004) - Validate observability
9. **Advanced Tests** (E2E-005, E2E-006) - Validate operational scenarios
10. **GitOps Tests** (06-INT-004) - Validate Flux integration

## Detailed Test Scenarios

### Unit Tests

#### 06-UNIT-001: Validate YAML syntax
```yaml
test_files:
  - kubernetes/infrastructure/security/cert-manager/*.yaml
validation:
  - kubectl --dry-run=client apply -f
  - yamllint validation
expected: All YAML files syntactically valid
```

#### 06-UNIT-002: Validate Kustomize overlays
```yaml
test_files:
  - kubernetes/infrastructure/security/cert-manager/kustomization.yaml
validation:
  - kustomize build --dry-run=client
  - overlay validation for cluster-specific configs
expected: Kustomize builds successfully
```

### Integration Tests

#### 06-INT-001: cert-manager deployment health
```yaml
test_scope: Both infra and apps clusters
validation:
  - kubectl -n cert-manager get deployment cert-manager
  - kubectl -n cert-manager get deployment cert-manager-webhook
  - kubectl -n cert-manager get deployment cert-manager-cainjector
  - Verify all deployments have Ready replicas
expected: All cert-manager components Ready
```

#### 06-INT-002: webhook connectivity validation
```yaml
test_scope: Both clusters
validation:
  - kubectl -n cert-manager get pods -l app.kubernetes.io/component=webhook
  - Port forward and test webhook endpoint
  - Validate webhook TLS certificate
expected: Webhook accessible and serving valid TLS
```

#### 06-INT-005: ExternalSecret Cloudflare token sync
```yaml
test_scope: Both clusters
validation:
  - kubectl -n cert-manager get externalsecret cloudflare-api-token
  - Verify Secret is created and contains API token
  - Validate token format and permissions
expected: Cloudflare API token successfully synced
```

#### 06-INT-006: ClusterIssuer staging readiness
```yaml
test_scope: Both clusters
validation:
  - kubectl get clusterissuer letsencrypt-staging
  - Verify status: Ready=True
  - Check ACME server registration
  - Validate DNS-01 solver configuration
expected: Staging ClusterIssuer Ready for DNS-01 challenges
```

#### 06-INT-008: Wildcard certificate staging issuance
```yaml
test_scope: Both clusters
validation:
  - kubectl -n kube-system get certificate wildcard-domain
  - Verify certificate status: Ready=True
  - Check certificate contains staging Let's Encrypt issuer
  - Validate DNS names include *.${SECRET_DOMAIN}
expected: Staging wildcard certificate successfully issued
```

### End-to-End Tests

#### 06-E2E-001: Multi-cluster deployment validation
```yaml
test_scope: Cross-cluster consistency
validation:
  - Compare cert-manager versions between clusters
  - Verify identical ClusterIssuer configurations
  - Validate wildcard certificates match across clusters
  - Test failover scenarios
expected: Consistent certificate management across clusters
```

#### 06-E2E-002: DNS-01 challenge completion
```yaml
test_scope: Real DNS integration
validation:
  - Trigger certificate issuance
  - Monitor Cloudflare DNS for _acme-challenge records
  - Verify challenge completion
  - Validate record cleanup after issuance
expected: DNS-01 challenges complete successfully
```

#### 06-E2E-003: Certificate browser trust validation
```yaml
test_scope: Production certificate validation
validation:
  - Extract certificate from secret
  - Validate certificate chain
  - Check against browser trust stores
  - Test with curl/openssl validation
expected: Production certificates trusted by browsers
```

## Test Data Requirements

### Cloudflare Integration
- Valid Cloudflare API token with DNS edit permissions
- Test domain configured in Cloudflare
- 1Password Connect integration for secret management

### Certificate Testing
- Staging ACME server (https://acme-staging-v02.api.letsencrypt.org)
- Production ACME server (https://acme-v02.api.letsencrypt.org)
- Test wildcard domain: *.${SECRET_DOMAIN}

### Monitoring Setup
- Prometheus instance configured to scrape cert-manager metrics
- AlertManager for certificate expiration alerts
- Grafana dashboard for certificate status visualization

## Mock/Stub Strategies

### DNS Challenge Testing
- Use staging Let's Environment for rate limit avoidance
- Mock DNS responses for isolated testing (if needed)
- Test with actual Cloudflare integration in staging

### ExternalSecret Testing
- Mock 1Password Connect for unit tests
- Use test secrets for integration validation
- Validate secret rotation scenarios

## Quality Indicators

### Success Criteria
- All P0 tests pass
- Certificate issuance time < 5 minutes
- DNS-01 challenge success rate > 95%
- Monitoring metrics collection healthy

### Performance Metrics
- Certificate renewal processing time
- DNS challenge propagation time
- cert-manager controller resource usage
- webhook response latency

### Security Validation
- Certificate key strength (2048-bit minimum)
- Proper certificate chain validation
- No hardcoded secrets in configurations
- ExternalSecret encryption at rest

## Test Environment Requirements

### Cluster Setup
- Two Kubernetes clusters (infra, apps)
- Flux CD installed and configured
- External Secrets Operator deployed
- Network connectivity to Cloudflare API

### Tooling
- kubectl configured for both clusters
- Flux CLI for reconciliation testing
- OpenSSL for certificate validation
- Cloudflare CLI for DNS validation

### Monitoring Stack
- Prometheus deployed and configured
- AlertManager for alert routing
- Grafana for visualization (optional)