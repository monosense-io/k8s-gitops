# 48 — STORY-VALIDATE-APPS-CLUSTER — Deploy & Validate CI/CD and Application Workloads

Sequence: 48/50 | Prev: STORY-VALIDATE-DATABASES-SECURITY.md | Next: STORY-VALIDATE-MESSAGING-TENANCY.md
Sprint: 8 | Lane: Deployment & Validation
Global Sequence: 48/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md; docs/SCHEDULE-V2-GREENFIELD.md; Stories 32-34, 36 (CI/CD & application manifests)

ID: STORY-VALIDATE-APPS-CLUSTER

## Story

As a Platform Engineer, I want to deploy and validate CI/CD and application workloads (stories 32-34, 36) on the apps cluster, so that I can verify GitLab, Harbor, and GitHub Actions Runner Controller are operational and the complete CI/CD pipeline is functional before deploying messaging and tenant applications.

This story focuses on **CI/CD and application workloads validation** as part of the phased deployment approach. Stories 45-47 completed networking, storage, observability, and databases. This story establishes the CI/CD foundation and container registry for application development.

## Why / Outcome

- **Deploy CI/CD manifests** (stories 32-34) to apps cluster
- **Deploy application manifests** (Harbor from story 36) to apps cluster
- **Validate GitLab** with PostgreSQL backend, object storage, CI/CD pipelines
- **Validate Harbor** as container registry with S3 backend, vulnerability scanning
- **Validate GitHub Actions runners** for CI/CD automation
- **Test end-to-end CI/CD workflow** (code → build → push to Harbor → deploy)
- **Establish developer platform** for application teams

## Scope

### v3.0 Phased Validation Approach

**Prerequisites** (completed in Stories 45-47):
- Networking operational (Cilium, DNS, certs, Gateway API)
- Storage operational (Rook-Ceph on apps cluster)
- Observability operational (metrics/logs forwarding to infra)
- Databases operational (PostgreSQL cluster with poolers, DragonflyDB)

**This Story Deploys & Validates**:
- CI/CD manifests (stories 32-34): GitHub ARC, GitLab
- Application manifests (story 36): Harbor registry
- Integration testing (end-to-end CI/CD workflow)

**Deferred to Story 49**:
- Messaging deployment (Kafka, Schema Registry)
- Tenant applications (Keycloak, Mattermost, etc.)

### CI/CD & Application Coverage (Stories 32-34, 36)

32. STORY-CICD-GITHUB-ARC — GitHub Actions Runner Controller (self-hosted runners)
33. STORY-CICD-GITLAB-APPS — GitLab (source control, CI/CD, container registry)
34. (Story 34 scope TBD - may be placeholder)
36. STORY-APP-HARBOR — Harbor container registry (S3 storage, external DB, Trivy scanning)

**Note**: Story numbering may have gaps; focusing on manifest stories that exist.

## Acceptance Criteria

### AC1 — GitHub Actions Runner Controller Operational

**ARC Controller Deployment**:
- [ ] ARC controller pod Running in `actions-runner` namespace (or similar)
- [ ] CRDs Established: `RunnerScaleSet`, `Runner`, etc.
- [ ] Controller logs show no errors
- [ ] Webhook endpoint configured (if using webhook-driven scaling)

**RunnerScaleSets Deployed**:
- [ ] `k8s-gitops` RunnerScaleSet deployed (for k8s-gitops repository)
- [ ] `pilar-apps` RunnerScaleSet deployed (for pilar-apps repository, if applicable)
- [ ] Runners registered with GitHub (check GitHub Actions settings)
- [ ] Min replicas running (e.g., 1 runner per scale set for immediate availability)

**Monitoring**:
- [ ] ServiceMonitor scraping ARC controller metrics
- [ ] Metrics visible in VictoriaMetrics: `arc_*` or similar

### AC2 — GitHub Actions Workflow Execution

**Workflow Validation**:
- [ ] Trigger test workflow in `k8s-gitops` repository
- [ ] Verify runner picks up job (check GitHub Actions UI)
- [ ] Workflow executes successfully (simple test: echo, date, environment info)
- [ ] Runner logs show job execution details

**Auto-Scaling Testing**:
- [ ] Trigger multiple concurrent workflows (3-5 jobs)
- [ ] Verify RunnerScaleSet scales up (creates additional runner pods)
- [ ] Verify scale down after jobs complete (idle runners terminate)
- [ ] Document scale-up time (job queued → runner ready → job started)

**Validation**:
- [ ] Capture GitHub Actions workflow run screenshots
- [ ] Capture runner pod scaling events
- [ ] Document runner availability and scaling metrics

### AC3 — GitLab Deployment & Core Services

**GitLab Pods Running**:
- [ ] `gitlab-webservice` pods Running (2 replicas expected)
- [ ] `gitlab-sidekiq` pods Running (background job processor)
- [ ] `gitlab-gitaly` pods Running (Git repository storage)
- [ ] `gitlab-shell` pod Running (SSH access)
- [ ] `gitlab-migrations` job completed successfully
- [ ] All pods healthy (no CrashLoopBackOff, no errors in logs)

**Database & Redis Connectivity**:
- [ ] GitLab connected to PostgreSQL via `gitlab-pooler-rw.cnpg-system.svc.cluster.local`
- [ ] GitLab connected to DragonflyDB for caching
- [ ] Verify database connection in logs:
  ```bash
  kubectl logs -n gitlab deploy/gitlab-webservice | grep -i "database\|postgres"
  ```
- [ ] Verify Redis connection in logs:
  ```bash
  kubectl logs -n gitlab deploy/gitlab-webservice | grep -i "redis"
  ```

**Object Storage Configuration**:
- [ ] Object storage configured for artifacts, LFS, uploads, packages
- [ ] S3-compatible backend (MinIO or cloud provider)
- [ ] Test upload to object storage (upload avatar or project file)
- [ ] Verify files stored in S3 bucket

### AC4 — GitLab Web UI & Authentication

**Web UI Access**:
- [ ] GitLab accessible via HTTPRoute (e.g., `https://gitlab.monosense.io`)
- [ ] TLS certificate valid (from cert-manager)
- [ ] Login page loads successfully
- [ ] Get root password from ExternalSecret or initial secret
- [ ] Login as root user successful

**Initial Configuration**:
- [ ] Set custom root password (change from initial)
- [ ] Configure admin settings (email, instance name, etc.)
- [ ] Disable public registration (if not needed)
- [ ] Create test user account

**Validation**:
- [ ] Capture screenshot of GitLab UI
- [ ] Document root credentials location (1Password ExternalSecret)

### AC5 — GitLab Source Control Operations

**Repository Creation**:
- [ ] Create test project "test-project"
- [ ] Initialize with README
- [ ] Clone repository locally:
  ```bash
  git clone https://gitlab.monosense.io/root/test-project.git
  ```

**Git Operations**:
- [ ] Create test file and commit:
  ```bash
  echo "test content" > test.txt
  git add test.txt
  git commit -m "Add test file"
  git push origin main
  ```
- [ ] Verify commit appears in GitLab UI
- [ ] Create branch, make change, push
- [ ] Create merge request (optional)
- [ ] Test git pull/fetch operations

**Validation**:
- [ ] Capture repository screenshot
- [ ] Document git operation latency (clone time, push time)

### AC6 — GitLab CI/CD Pipeline Execution

**GitLab Runner Configuration**:
- [ ] GitLab Runner deployed (separate from GitLab webservice)
- [ ] Runner registered with GitLab instance
- [ ] Runner tags configured (e.g., `docker`, `kubernetes`)
- [ ] Runner executor type verified (Docker-in-Docker or Kaniko)

**Pipeline Creation**:
- [ ] Create `.gitlab-ci.yml` in test project:
  ```yaml
  stages:
    - build
    - test

  build-job:
    stage: build
    script:
      - echo "Building application..."
      - echo "Build timestamp: $(date)"
    tags:
      - docker

  test-job:
    stage: test
    script:
      - echo "Running tests..."
      - echo "Tests passed"
    tags:
      - docker
  ```
- [ ] Commit and push `.gitlab-ci.yml`

**Pipeline Execution**:
- [ ] Verify pipeline triggered automatically
- [ ] Check pipeline status in GitLab UI (Pipelines page)
- [ ] Verify runner picks up jobs
- [ ] Wait for pipeline completion (all jobs pass)
- [ ] Check job logs for expected output

**Docker Build Test** (if using Docker-in-Docker):
- [ ] Create Dockerfile in project
- [ ] Update `.gitlab-ci.yml` to build Docker image
- [ ] Verify image builds successfully
- [ ] (Optional) Push image to Harbor

**Validation**:
- [ ] Capture pipeline screenshot (success)
- [ ] Document pipeline execution time
- [ ] Capture job logs

### AC7 — Harbor Deployment & Core Services

**Harbor Pods Running**:
- [ ] `harbor-core` pod Running (API server, web UI)
- [ ] `harbor-portal` pod Running (UI frontend)
- [ ] `harbor-registry` pod Running (Docker registry)
- [ ] `harbor-jobservice` pod Running (async jobs, scanning, replication)
- [ ] `harbor-trivy` pod Running (vulnerability scanner)
- [ ] All pods healthy

**Database & Redis Connectivity**:
- [ ] Harbor connected to PostgreSQL via `harbor-pooler-rw.cnpg-system.svc.cluster.local`
- [ ] Harbor connected to DragonflyDB (if used for caching)
- [ ] Verify database connection in logs:
  ```bash
  kubectl logs -n harbor deploy/harbor-core | grep -i "database\|postgres"
  ```

**S3 Storage Configuration**:
- [ ] S3 backend configured for image storage (MinIO or cloud)
- [ ] Test image storage (push image, verify blob in S3)
- [ ] Verify storage class: `filesystem` or `s3` (check Harbor config)

### AC8 — Harbor Web UI & Authentication

**Web UI Access**:
- [ ] Harbor accessible via HTTPRoute (e.g., `https://harbor.monosense.io`)
- [ ] TLS certificate valid
- [ ] Login page loads
- [ ] Get admin password from ExternalSecret
- [ ] Login as admin successful

**Initial Configuration**:
- [ ] Create test project "test-project" (public or private)
- [ ] Configure registry settings (garbage collection, retention, etc.)
- [ ] Configure Trivy scanner (if not auto-configured)

**Validation**:
- [ ] Capture screenshot of Harbor UI
- [ ] Document admin credentials location

### AC9 — Harbor Registry Operations

**Docker Login**:
- [ ] Docker login to Harbor:
  ```bash
  docker login harbor.monosense.io -u admin -p <password>
  # Or use robot account credentials
  ```
- [ ] Verify login successful

**Image Push**:
- [ ] Pull test image:
  ```bash
  docker pull nginx:alpine
  ```
- [ ] Tag for Harbor:
  ```bash
  docker tag nginx:alpine harbor.monosense.io/test-project/nginx:test
  ```
- [ ] Push to Harbor:
  ```bash
  docker push harbor.monosense.io/test-project/nginx:test
  ```
- [ ] Verify image appears in Harbor UI (test-project → Repositories)

**Image Pull**:
- [ ] Delete local image:
  ```bash
  docker rmi harbor.monosense.io/test-project/nginx:test
  ```
- [ ] Pull from Harbor:
  ```bash
  docker pull harbor.monosense.io/test-project/nginx:test
  ```
- [ ] Verify pull successful

**Validation**:
- [ ] Capture screenshot of Harbor repository with test image
- [ ] Document push/pull latency

### AC10 — Harbor Vulnerability Scanning

**Scan Trigger**:
- [ ] Automatic scan on push enabled (check project settings)
- [ ] Manually trigger scan for test image (if auto-scan disabled)
- [ ] Wait for scan completion (Trivy scanner)

**Scan Results**:
- [ ] View scan results in Harbor UI (click on image → Vulnerabilities tab)
- [ ] Verify vulnerability count (CVEs detected)
- [ ] Check severity distribution (Critical, High, Medium, Low)
- [ ] Verify scan report downloadable

**Validation**:
- [ ] Capture screenshot of scan results
- [ ] Document scanning time (image push → scan complete)

### AC11 — End-to-End CI/CD Integration

**Full CI/CD Workflow**:
1. [ ] Create application with Dockerfile in GitLab
   ```dockerfile
   FROM nginx:alpine
   COPY index.html /usr/share/nginx/html/
   ```
2. [ ] Create `.gitlab-ci.yml` to build and push to Harbor:
   ```yaml
   stages:
     - build
     - deploy

   build-image:
     stage: build
     image: docker:latest
     services:
       - docker:dind
     script:
       - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD harbor.monosense.io
       - docker build -t harbor.monosense.io/test-project/my-app:$CI_COMMIT_SHA .
       - docker push harbor.monosense.io/test-project/my-app:$CI_COMMIT_SHA
     tags:
       - docker
   ```
3. [ ] Commit and push to GitLab
4. [ ] Verify pipeline triggers and executes
5. [ ] Verify image appears in Harbor
6. [ ] Verify vulnerability scan runs
7. [ ] Deploy image to apps cluster:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: default
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: my-app
     template:
       metadata:
         labels:
           app: my-app
       spec:
         containers:
           - name: my-app
             image: harbor.monosense.io/test-project/my-app:$CI_COMMIT_SHA
             ports:
               - containerPort: 80
   EOF
   ```
8. [ ] Verify deployment successful

**Validation**:
- [ ] Capture end-to-end workflow screenshots (GitLab pipeline → Harbor image → K8s deployment)
- [ ] Document total workflow time (commit → deployed)
- [ ] Verify all metrics/logs collected

### AC12 — Monitoring & Performance

**Metrics Collection**:
- [ ] GitLab metrics scraped by VMAgent:
  - `gitlab_*` (GitLab application metrics)
  - `sidekiq_*` (background job metrics)
  - `gitaly_*` (Git RPC metrics)
- [ ] Harbor metrics scraped:
  - `harbor_*` (registry operations, storage, etc.)
- [ ] GitHub ARC metrics scraped:
  - `arc_*` (runner scaling, job queue, etc.)

**Logs Collection**:
- [ ] GitLab logs forwarded to VictoriaLogs
- [ ] Harbor logs forwarded to VictoriaLogs
- [ ] ARC logs forwarded
- [ ] Query logs in VictoriaLogs:
  ```bash
  {cluster="apps",namespace="gitlab"}
  {cluster="apps",namespace="harbor"}
  ```

**Performance Baselines**:
- [ ] GitLab git clone time: <10s for small repo
- [ ] GitLab CI pipeline execution: <2 minutes for simple build
- [ ] Harbor image push: <30s for small image (<100MB)
- [ ] Harbor image pull: <15s for small image
- [ ] GitHub Actions workflow execution: <1 minute for simple test

### AC13 — Documentation & Evidence

**QA Evidence**:
- [ ] GitLab UI screenshots (dashboard, project, pipeline)
- [ ] Harbor UI screenshots (projects, repositories, vulnerability scan)
- [ ] GitHub Actions workflow run screenshots
- [ ] CI/CD pipeline logs
- [ ] Image push/pull logs
- [ ] Performance metrics (clone time, pipeline time, image operations)

**Dev Notes**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments (GitLab settings, Harbor settings)
- [ ] Known limitations (performance, features)

## Dependencies / Inputs

**Upstream Prerequisites**:
- **Story 47 Complete**: Databases (PostgreSQL poolers, DragonflyDB) operational
- **Story 46 Complete**: Storage (Rook-Ceph on apps), Observability (collectors forwarding to infra)
- **Story 45 Complete**: Networking (Cilium, DNS, certs, Gateway API)
- **Stories 32-34, 36 Complete**: CI/CD and application manifests committed to git

**External Dependencies**:
- **GitHub PAT**: Personal Access Token for ARC registration
- **S3 Bucket**: For GitLab object storage and Harbor image storage (MinIO or cloud)
- **Domain Names**: `gitlab.monosense.io`, `harbor.monosense.io` (DNS configured)
- **Secrets**: 1Password Connect for GitLab root password, Harbor admin password, GitHub PAT

**Tools Required**:
- `kubectl`, `flux`
- `git` (for GitLab operations)
- `docker` (for Harbor image push/pull)
- `curl` (for API testing)

**Cluster Access**:
- KUBECONFIG context: `apps`
- Network connectivity to apps cluster

## Tasks / Subtasks

### T0 — Pre-Deployment Validation (NO Cluster Changes)

**Manifest Quality Checks**:
- [ ] Verify CI/CD and application manifests (stories 32-34, 36) committed to git
- [ ] Run `flux build kustomization` for CI/CD components:
  ```bash
  flux build kustomization cluster-apps-cicd --path kubernetes/workloads/platform/cicd
  flux build kustomization cluster-apps-harbor --path kubernetes/workloads/platform/registry
  ```
- [ ] Validate with `kubeconform`:
  ```bash
  kustomize build kubernetes/workloads/platform/cicd | kubeconform -summary -strict
  kustomize build kubernetes/workloads/platform/registry | kubeconform -summary -strict
  ```

**Prerequisites Validation**:
- [ ] Verify Story 47 complete:
  - Databases: `kubectl --context=apps -n cnpg-system get cluster shared-postgres`
  - Poolers: `kubectl --context=apps -n cnpg-system get pooler`
  - DragonflyDB: `kubectl --context=apps -n dragonfly-system get dragonfly`
- [ ] Verify S3 buckets configured (GitLab, Harbor)
- [ ] Verify GitHub PAT available in 1Password/ExternalSecret
- [ ] Verify DNS records for `gitlab.monosense.io`, `harbor.monosense.io`

### T1 — Deploy GitHub Actions Runner Controller

**ARC Controller Deployment**:
- [ ] Trigger ARC controller reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-cicd-arc-controller --with-source
  ```
- [ ] Monitor controller deployment:
  ```bash
  kubectl --context=apps -n actions-runner get pods -l app=arc-controller -w
  ```
- [ ] Wait for controller Ready:
  ```bash
  kubectl --context=apps -n actions-runner rollout status deploy/arc-controller
  ```

**Validation**:
- [ ] Verify CRDs installed:
  ```bash
  kubectl --context=apps get crd | grep actions.summerwind.dev
  # Or actions.github.com depending on ARC version
  ```
- [ ] Check controller logs:
  ```bash
  kubectl --context=apps -n actions-runner logs deploy/arc-controller --tail=50
  ```

### T2 — Deploy RunnerScaleSets

**RunnerScaleSet Deployment**:
- [ ] Trigger RunnerScaleSet reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-cicd-arc-runners --with-source
  ```
- [ ] Monitor RunnerScaleSet deployment:
  ```bash
  kubectl --context=apps -n actions-runner get runnerscalesets
  ```
- [ ] Verify runner pods created (min replicas):
  ```bash
  kubectl --context=apps -n actions-runner get pods -l app=github-runner
  ```

**GitHub Registration Validation**:
- [ ] Check GitHub repository Settings → Actions → Runners
- [ ] Verify runners registered (should show as "Idle" when no jobs running)
- [ ] Note runner labels/tags

**Validation**:
- [ ] Capture RunnerScaleSet status
- [ ] Capture screenshot of GitHub runners page

### T3 — Test GitHub Actions Workflow Execution

**Create Test Workflow**:
- [ ] In `k8s-gitops` repository, create `.github/workflows/test-runner.yml`:
  ```yaml
  name: Test Self-Hosted Runner
  on: [workflow_dispatch]

  jobs:
    test-job:
      runs-on: self-hosted
      steps:
        - name: Echo test
          run: |
            echo "Running on self-hosted runner"
            date
            hostname
            kubectl version --client
  ```
- [ ] Commit and push

**Trigger Workflow**:
- [ ] Go to GitHub Actions tab
- [ ] Select "Test Self-Hosted Runner" workflow
- [ ] Click "Run workflow"
- [ ] Monitor workflow execution

**Validation**:
- [ ] Verify runner picks up job (check runner logs in K8s)
- [ ] Verify workflow completes successfully
- [ ] Capture workflow run screenshot
- [ ] Document execution time

### T4 — Test Runner Auto-Scaling

**Concurrent Jobs Test**:
- [ ] Trigger 3-5 concurrent workflows (or use matrix strategy)
- [ ] Monitor runner scaling:
  ```bash
  watch kubectl --context=apps -n actions-runner get pods -l app=github-runner
  ```
- [ ] Verify RunnerScaleSet scales up (creates additional runner pods)
- [ ] Wait for jobs to complete
- [ ] Verify scale down (idle runners terminated after cooldown period)

**Validation**:
- [ ] Document scaling behavior (time to scale up, scale down cooldown)
- [ ] Capture pod scaling events

### T5 — Deploy GitLab

**GitLab HelmRelease Deployment**:
- [ ] Trigger GitLab reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-cicd-gitlab --with-source
  ```
- [ ] Monitor GitLab deployment (can take 5-10 minutes):
  ```bash
  kubectl --context=apps -n gitlab get pods -w
  ```
- [ ] Wait for migrations job to complete:
  ```bash
  kubectl --context=apps -n gitlab wait --for=condition=complete job/gitlab-migrations --timeout=10m
  ```
- [ ] Wait for all pods Running:
  ```bash
  kubectl --context=apps -n gitlab get pods
  # gitlab-webservice, gitlab-sidekiq, gitlab-gitaly, gitlab-shell should be Running
  ```

**Validation**:
- [ ] Check database connection:
  ```bash
  kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i "database connection"
  ```
- [ ] Check Redis connection:
  ```bash
  kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i "redis"
  ```
- [ ] Check object storage connection:
  ```bash
  kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i "s3\|object storage"
  ```

### T6 — Access GitLab Web UI

**Get Root Password**:
- [ ] Retrieve root password from ExternalSecret or initial secret:
  ```bash
  kubectl --context=apps -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d
  ```

**Access UI**:
- [ ] Option 1: Via HTTPRoute (if configured):
  - Open browser to `https://gitlab.monosense.io`
- [ ] Option 2: Via port-forward:
  ```bash
  kubectl --context=apps -n gitlab port-forward svc/gitlab-webservice 8080:8181
  # Open browser to http://localhost:8080
  ```

**Initial Login**:
- [ ] Login as `root` with password
- [ ] Change root password (admin → Settings → Password)
- [ ] Configure admin settings (instance name, email, etc.)

**Validation**:
- [ ] Capture screenshot of GitLab dashboard
- [ ] Document new root credentials in 1Password

### T7 — GitLab Source Control Operations

**Create Project**:
- [ ] Click "New Project" → "Create blank project"
- [ ] Project name: `test-project`
- [ ] Initialize with README: Yes
- [ ] Create project

**Git Clone**:
- [ ] Clone project locally:
  ```bash
  git clone https://gitlab.monosense.io/root/test-project.git
  cd test-project
  ```

**Git Operations**:
- [ ] Create test file:
  ```bash
  echo "Test content" > test.txt
  git add test.txt
  git commit -m "Add test file"
  git push origin main
  ```
- [ ] Verify commit in GitLab UI (Repository → Commits)
- [ ] Create branch:
  ```bash
  git checkout -b feature/test-branch
  echo "Feature content" > feature.txt
  git add feature.txt
  git commit -m "Add feature file"
  git push origin feature/test-branch
  ```

**Validation**:
- [ ] Capture screenshot of repository page
- [ ] Document git operation latency (clone time, push time)

### T8 — GitLab CI/CD Pipeline

**Create Pipeline Configuration**:
- [ ] Create `.gitlab-ci.yml` in `test-project`:
  ```yaml
  stages:
    - build
    - test

  build-job:
    stage: build
    image: alpine:latest
    script:
      - echo "Building application..."
      - echo "Build timestamp: $(date)"
      - echo "Commit SHA: $CI_COMMIT_SHA"
    artifacts:
      paths:
        - build-output.txt
      expire_in: 1 week

  test-job:
    stage: test
    image: alpine:latest
    script:
      - echo "Running tests..."
      - echo "Tests passed"
    dependencies:
      - build-job
  ```
- [ ] Commit and push:
  ```bash
  git add .gitlab-ci.yml
  git commit -m "Add CI pipeline"
  git push origin main
  ```

**Monitor Pipeline**:
- [ ] Go to GitLab UI → CI/CD → Pipelines
- [ ] Verify pipeline triggered automatically
- [ ] Click on pipeline to view jobs
- [ ] Wait for pipeline completion

**Validation**:
- [ ] Verify both jobs pass (green checkmark)
- [ ] Click on job logs, verify expected output
- [ ] Check artifacts downloaded
- [ ] Capture screenshot of successful pipeline
- [ ] Document pipeline execution time

### T9 — Deploy Harbor

**Harbor HelmRelease Deployment**:
- [ ] Trigger Harbor reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-registry-harbor --with-source
  ```
- [ ] Monitor Harbor deployment (can take 3-5 minutes):
  ```bash
  kubectl --context=apps -n harbor get pods -w
  ```
- [ ] Wait for all pods Running:
  ```bash
  kubectl --context=apps -n harbor get pods
  # harbor-core, harbor-portal, harbor-registry, harbor-jobservice, harbor-trivy
  ```

**Validation**:
- [ ] Check database connection:
  ```bash
  kubectl --context=apps -n harbor logs deploy/harbor-core | grep -i "database\|postgres"
  ```
- [ ] Check Redis connection (if used):
  ```bash
  kubectl --context=apps -n harbor logs deploy/harbor-core | grep -i "redis"
  ```
- [ ] Check S3 storage configuration:
  ```bash
  kubectl --context=apps -n harbor describe cm harbor-core-config | grep -i s3
  ```

### T10 — Access Harbor Web UI

**Get Admin Password**:
- [ ] Retrieve admin password from ExternalSecret:
  ```bash
  kubectl --context=apps -n harbor get secret harbor-core -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d
  ```

**Access UI**:
- [ ] Option 1: Via HTTPRoute:
  - Open browser to `https://harbor.monosense.io`
- [ ] Option 2: Via port-forward:
  ```bash
  kubectl --context=apps -n harbor port-forward svc/harbor-portal 8080:80
  # Open browser to http://localhost:8080
  ```

**Initial Login**:
- [ ] Login as `admin` with password
- [ ] Change admin password (admin → Change Password)
- [ ] Configure system settings (email, registry settings, etc.)

**Create Test Project**:
- [ ] Click "New Project"
- [ ] Project name: `test-project`
- [ ] Access level: Public or Private
- [ ] Create project

**Validation**:
- [ ] Capture screenshot of Harbor dashboard
- [ ] Document new admin credentials in 1Password

### T11 — Harbor Image Operations

**Docker Login**:
- [ ] Login to Harbor:
  ```bash
  docker login harbor.monosense.io -u admin -p <password>
  # Login Succeeded
  ```

**Push Test Image**:
- [ ] Pull test image:
  ```bash
  docker pull nginx:alpine
  ```
- [ ] Tag for Harbor:
  ```bash
  docker tag nginx:alpine harbor.monosense.io/test-project/nginx:test
  ```
- [ ] Push to Harbor:
  ```bash
  docker push harbor.monosense.io/test-project/nginx:test
  # Should show push progress and success
  ```
- [ ] Verify image in Harbor UI (Projects → test-project → Repositories)

**Pull Test Image**:
- [ ] Delete local image:
  ```bash
  docker rmi harbor.monosense.io/test-project/nginx:test
  docker rmi nginx:alpine
  ```
- [ ] Pull from Harbor:
  ```bash
  docker pull harbor.monosense.io/test-project/nginx:test
  # Should pull successfully
  ```

**Validation**:
- [ ] Capture screenshot of Harbor repository with image
- [ ] Document push time and pull time
- [ ] Verify image stored in S3 backend (check S3 bucket)

### T12 — Harbor Vulnerability Scanning

**Trigger Scan**:
- [ ] In Harbor UI, go to test-project → nginx repository
- [ ] Click on `test` tag
- [ ] Click "Scan" button (if not auto-scanned)
- [ ] Wait for scan completion (Trivy scanner)

**Review Scan Results**:
- [ ] Click on "Vulnerabilities" tab
- [ ] Review vulnerability count
- [ ] Check severity distribution (Critical, High, Medium, Low)
- [ ] Expand a few CVEs to see details
- [ ] Download scan report (if available)

**Validation**:
- [ ] Capture screenshot of scan results
- [ ] Document scanning time (image push → scan complete)
- [ ] Note any critical vulnerabilities (expected for nginx:alpine)

### T13 — End-to-End CI/CD Integration

**Create Application with Dockerfile**:
- [ ] In `test-project` (GitLab), create `Dockerfile`:
  ```dockerfile
  FROM nginx:alpine
  COPY index.html /usr/share/nginx/html/
  EXPOSE 80
  ```
- [ ] Create `index.html`:
  ```html
  <!DOCTYPE html>
  <html>
  <body>
    <h1>Hello from GitLab CI/CD!</h1>
    <p>Built and pushed to Harbor</p>
  </body>
  </html>
  ```

**Update CI Pipeline**:
- [ ] Update `.gitlab-ci.yml`:
  ```yaml
  stages:
    - build
    - push

  build-image:
    stage: build
    image: docker:latest
    services:
      - docker:dind
    variables:
      DOCKER_TLS_CERTDIR: "/certs"
    before_script:
      - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD harbor.monosense.io
    script:
      - docker build -t harbor.monosense.io/test-project/my-app:$CI_COMMIT_SHORT_SHA .
      - docker build -t harbor.monosense.io/test-project/my-app:latest .
      - docker push harbor.monosense.io/test-project/my-app:$CI_COMMIT_SHORT_SHA
      - docker push harbor.monosense.io/test-project/my-app:latest
    tags:
      - docker
  ```
- [ ] Add CI/CD variables in GitLab (Settings → CI/CD → Variables):
  - `HARBOR_USER`: admin
  - `HARBOR_PASSWORD`: <password> (masked)

**Trigger Pipeline**:
- [ ] Commit and push:
  ```bash
  git add Dockerfile index.html .gitlab-ci.yml
  git commit -m "Add Dockerfile and CI pipeline for Harbor"
  git push origin main
  ```
- [ ] Monitor pipeline in GitLab UI
- [ ] Wait for pipeline completion

**Verify Image in Harbor**:
- [ ] Check Harbor UI → test-project → my-app repository
- [ ] Verify tags: `latest`, `<commit-sha>`
- [ ] Check vulnerability scan results

**Deploy to Kubernetes**:
- [ ] Create deployment manifest:
  ```bash
  kubectl --context=apps apply -f - <<EOF
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: my-app
    namespace: default
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: my-app
    template:
      metadata:
        labels:
          app: my-app
      spec:
        containers:
          - name: my-app
            image: harbor.monosense.io/test-project/my-app:latest
            ports:
              - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: my-app
    namespace: default
  spec:
    selector:
      app: my-app
    ports:
      - port: 80
        targetPort: 80
    type: LoadBalancer
  EOF
  ```
- [ ] Verify deployment:
  ```bash
  kubectl --context=apps get pods -l app=my-app
  kubectl --context=apps get svc my-app
  ```
- [ ] Access application:
  ```bash
  curl http://<EXTERNAL-IP>
  # Should return HTML with "Hello from GitLab CI/CD!"
  ```

**Validation**:
- [ ] Capture end-to-end screenshots (GitLab pipeline → Harbor image → K8s deployment → app access)
- [ ] Document total workflow time (commit → deployed and accessible)
- [ ] Verify all logs/metrics collected

### T14 — Monitoring & Performance Validation

**Metrics Validation**:
- [ ] Port-forward to VictoriaMetrics (infra cluster):
  ```bash
  kubectl --context=infra port-forward -n observability svc/vmselect 8481:8481
  ```
- [ ] Query GitLab metrics:
  ```promql
  # GitLab application metrics
  gitlab_transaction_duration_seconds{cluster="apps"}

  # Sidekiq job metrics
  sidekiq_queue_size{cluster="apps"}

  # Gitaly RPC metrics
  gitaly_service_client_requests_total{cluster="apps"}
  ```
- [ ] Query Harbor metrics:
  ```promql
  # Harbor registry operations
  harbor_registry_pulls{cluster="apps"}
  harbor_registry_pushes{cluster="apps"}
  ```
- [ ] Query ARC metrics (if available):
  ```promql
  # Runner metrics
  arc_runner_count{cluster="apps"}
  ```

**Logs Validation**:
- [ ] Query GitLab logs in VictoriaLogs:
  ```bash
  kubectl --context=infra port-forward -n observability svc/victorialogs 9428:9428
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps",namespace="gitlab"}'
  ```
- [ ] Query Harbor logs:
  ```bash
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps",namespace="harbor"}'
  ```

**Performance Baselines**:
- [ ] Measure GitLab git clone time:
  ```bash
  time git clone https://gitlab.monosense.io/root/test-project.git
  # Target: <10s for small repo
  ```
- [ ] Measure GitLab CI pipeline execution (from T8):
  - Target: <2 minutes for simple build
- [ ] Measure Harbor image push (from T11):
  - Target: <30s for small image (<100MB)
- [ ] Measure Harbor image pull (from T11):
  - Target: <15s for small image

**Validation**:
- [ ] Capture metrics query results
- [ ] Capture logs query results
- [ ] Document performance baselines

### T15 — Documentation & Evidence Collection

**QA Evidence Artifacts**:
- [ ] CI/CD validation:
  - `docs/qa/evidence/VALIDATE-APPS-gitlab-ui.png`
  - `docs/qa/evidence/VALIDATE-APPS-gitlab-pipeline.png`
  - `docs/qa/evidence/VALIDATE-APPS-harbor-ui.png`
  - `docs/qa/evidence/VALIDATE-APPS-harbor-scan.png`
  - `docs/qa/evidence/VALIDATE-APPS-github-actions.png`
  - `docs/qa/evidence/VALIDATE-APPS-e2e-workflow.png`
  - `docs/qa/evidence/VALIDATE-APPS-performance-metrics.txt`

**Dev Notes Documentation**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments (GitLab settings, Harbor settings, ARC config)
- [ ] Known limitations (performance, features, scaling)
- [ ] Recommendations for messaging/tenant deployment (Story 49)

**Architecture/PRD Updates**:
- [ ] Update architecture.md with CI/CD topology
- [ ] Document GitLab/Harbor integration patterns
- [ ] Document performance baselines in PRD
- [ ] Note resource sizing for GitLab/Harbor

## Validation Steps

### Pre-Deployment Validation (NO Cluster)
```bash
# Validate manifests can build
flux build kustomization cluster-apps-cicd --path kubernetes/workloads/platform/cicd
flux build kustomization cluster-apps-harbor --path kubernetes/workloads/platform/registry

# Schema validation
kustomize build kubernetes/workloads/platform/cicd | kubeconform -summary -strict
kustomize build kubernetes/workloads/platform/registry | kubeconform -summary -strict
```

### Runtime Validation Commands (Summary)

**GitLab Validation**:
```bash
# GitLab pods status
kubectl --context=apps -n gitlab get pods

# Database connection check
kubectl --context=apps -n gitlab logs deploy/gitlab-webservice | grep -i database

# Access GitLab
kubectl --context=apps -n gitlab port-forward svc/gitlab-webservice 8080:8181
# Open http://localhost:8080

# Git operations
git clone https://gitlab.monosense.io/root/test-project.git
```

**Harbor Validation**:
```bash
# Harbor pods status
kubectl --context=apps -n harbor get pods

# Access Harbor
kubectl --context=apps -n harbor port-forward svc/harbor-portal 8080:80
# Open http://localhost:8080

# Docker operations
docker login harbor.monosense.io
docker push harbor.monosense.io/test-project/nginx:test
docker pull harbor.monosense.io/test-project/nginx:test
```

**GitHub Actions Runner Validation**:
```bash
# ARC controller status
kubectl --context=apps -n actions-runner get pods

# RunnerScaleSets status
kubectl --context=apps -n actions-runner get runnerscalesets

# Runner pods
kubectl --context=apps -n actions-runner get pods -l app=github-runner
```

## Rollback Procedures

**GitLab Rollback**:
```bash
# Suspend GitLab
flux --context=apps suspend kustomization apps-cicd-gitlab

# Delete GitLab resources
kubectl --context=apps -n gitlab delete all -l app=gitlab

# Re-deploy with fixes
flux --context=apps resume kustomization apps-cicd-gitlab --with-source
```

**Harbor Rollback**:
```bash
# Suspend Harbor
flux --context=apps suspend kustomization apps-registry-harbor

# Delete Harbor resources
kubectl --context=apps -n harbor delete all -l app=harbor

# Re-deploy with fixes
flux --context=apps resume kustomization apps-registry-harbor --with-source
```

## Risks / Mitigations

**CI/CD Risks**:

**R1 — GitLab Initialization Failure** (Prob=Medium, Impact=High):
- Risk: GitLab migrations fail, webservice crashloop
- Mitigation: Pre-validate database connectivity, check migration logs, verify sufficient resources
- Recovery: Check migration job logs; verify PostgreSQL pooler accessible; increase migration timeout; re-run migrations

**R2 — Database Connection Issues** (Prob=Medium, Impact=High):
- Risk: GitLab/Harbor cannot connect to PostgreSQL poolers
- Mitigation: Validate poolers operational (from Story 47), test connectivity before deployment, check NetworkPolicy
- Recovery: Verify pooler endpoints; check NetworkPolicy rules; verify credentials in ExternalSecrets; restart affected pods

**R3 — Object Storage Failures** (Prob=Medium, Impact=High):
- Risk: GitLab cannot upload artifacts/LFS to S3, Harbor cannot store images
- Mitigation: Pre-validate S3 bucket access, test credentials, verify network connectivity
- Recovery: Fix S3 credentials; verify bucket exists; check S3 endpoint reachable; check NetworkPolicy egress

**R4 — Harbor Image Push/Pull Failures** (Prob=Low, Impact=Medium):
- Risk: Docker push/pull fails (authentication, network, storage)
- Mitigation: Test Docker login first, verify S3 backend functional, check network connectivity
- Recovery: Check Harbor logs; verify registry pod healthy; test S3 connectivity; check Docker daemon config

**R5 — GitHub Actions Runner Registration Failure** (Prob=Medium, Impact=Medium):
- Risk: Runners fail to register with GitHub
- Mitigation: Validate GitHub PAT, verify network egress to GitHub, check ARC controller logs
- Recovery: Verify PAT valid and has correct permissions; check NetworkPolicy egress to github.com; restart ARC controller

**R6 — GitLab CI Pipeline Failures** (Prob=Medium, Impact=Medium):
- Risk: GitLab Runner cannot execute jobs (Docker-in-Docker issues, resource limits)
- Mitigation: Validate runner configuration (DinD, privileged mode if needed), verify resource requests/limits
- Recovery: Check runner logs; verify Docker socket accessible; increase resource limits; use Kaniko instead of DinD if security concern

## Definition of Done

**All Acceptance Criteria Met**:
- [ ] AC1: GitHub Actions Runner Controller operational
- [ ] AC2: GitHub Actions workflows executing successfully
- [ ] AC3: GitLab deployed with core services Running
- [ ] AC4: GitLab web UI accessible and authenticated
- [ ] AC5: GitLab source control operations working
- [ ] AC6: GitLab CI/CD pipelines executing successfully
- [ ] AC7: Harbor deployed with core services Running
- [ ] AC8: Harbor web UI accessible and authenticated
- [ ] AC9: Harbor registry operations working (push/pull)
- [ ] AC10: Harbor vulnerability scanning operational
- [ ] AC11: End-to-end CI/CD integration validated
- [ ] AC12: Monitoring and performance baselines established
- [ ] AC13: Documentation & evidence complete

**QA Gate**:
- [ ] QA evidence artifacts collected and reviewed
- [ ] Risk assessment updated with deployment findings
- [ ] Test design execution complete (all P0 tests passing)
- [ ] QA gate decision: PASS (or waivers documented)

**PO Acceptance**:
- [ ] GitLab operational for source control and CI/CD
- [ ] Harbor operational as container registry
- [ ] GitHub Actions runners executing workflows
- [ ] End-to-end CI/CD workflow functional (code → build → Harbor → deploy)
- [ ] Performance baselines acceptable
- [ ] Ready for messaging and tenant application deployment (Story 49)

**Handoff to Story 49**:
- [ ] CI/CD platform ready for tenant applications
- [ ] Container registry available for application images
- [ ] GitLab available for application source control
- [ ] GitHub Actions available for automation

## Architect Handoff

**Architecture (docs/architecture.md)**:
- Validate CI/CD architecture matches deployment
- Document GitLab/Harbor integration with databases via poolers
- Document GitHub Actions Runner auto-scaling behavior
- Update developer workflow diagrams (code → CI/CD → registry → deploy)

**PRD (docs/prd.md)**:
- Confirm CI/CD NFRs met (pipeline execution time, runner availability, registry push/pull latency)
- Document performance baselines (git operations, pipeline time, image operations)
- Note resource sizing for GitLab/Harbor/ARC
- Document scaling strategy for runners and registry

**Runbooks**:
- Create `docs/runbooks/gitlab-operations.md` for GitLab administration
- Create `docs/runbooks/harbor-operations.md` for Harbor registry management
- Document CI/CD troubleshooting procedures (pipeline failures, runner issues)

## Change Log

| Date       | Version | Description                              | Author  |
|------------|---------|------------------------------------------|---------|
| 2025-10-26 | 0.1     | Initial validation story creation (draft)| Winston |
| 2025-10-26 | 1.0     | **v3.0 Refinement**: CI/CD & application workloads deployment/validation story. Added 15 tasks (T0-T15) covering GitHub Actions Runner Controller, GitLab (source control, CI/CD), Harbor (container registry, scanning). Created 13 acceptance criteria with detailed validation. Added end-to-end CI/CD workflow, image operations, vulnerability scanning, monitoring integration, QA artifacts. | Winston |

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
- Total Risks Identified: 6
- Critical: 0 | High: 3 | Medium: 3 | Low: 0
- Overall Story Risk Score: 62/100 (Medium-High)

**Top Risks**:
1. **R1 — GitLab Initialization Failure** (High): Migrations fail, webservice crashes
2. **R2 — Database Connection Issues** (High): Cannot connect to PostgreSQL poolers
3. **R3 — Object Storage Failures** (High): Cannot upload artifacts/images to S3
4. **R5 — GitHub Actions Runner Registration Failure** (Medium): Runners fail to register

**Mitigations**:
- All risks have documented mitigation and recovery procedures
- Pre-validation of database, storage, and network connectivity
- Phased deployment with validation gates
- Comprehensive logging and monitoring

**Risk-Based Testing Focus**:
- Priority 1: GitLab/Harbor database connectivity, S3 storage, image push/pull
- Priority 2: CI/CD pipeline execution, GitHub Actions runners
- Priority 3: End-to-end workflow, performance benchmarks

**Artifacts**:
- Full assessment: `docs/qa/assessments/STORY-VALIDATE-APPS-CLUSTER-risk-20251026.md` (to be created)

## QA Results — Test Design

**Designer**: Quinn (Test Architect)

**Test Strategy Overview**:
- **Emphasis**: CI/CD reliability, end-to-end workflow validation
- **Approach**: Component deployment → functional testing → integration testing → performance validation
- **Coverage**: All 13 acceptance criteria mapped to test cases
- **Priority Distribution**: P0 (GitLab/Harbor core, database connectivity), P1 (CI/CD pipelines, image operations), P2 (scanning, monitoring)

**Test Environments**:
- **Apps Cluster**: 3 control plane nodes with databases and storage operational (from Stories 46-47)

**Test Phases**:

**Phase 1: Pre-Deployment** (T0):
- Manifest validation
- Prerequisites check (databases, storage, S3)

**Phase 2: GitHub Actions** (T1-T4):
- ARC controller deployment
- RunnerScaleSet deployment
- Workflow execution testing
- Auto-scaling validation

**Phase 3: GitLab Deployment** (T5-T8):
- GitLab HelmRelease deployment
- Web UI access and configuration
- Source control operations (git clone, push, pull)
- CI/CD pipeline execution

**Phase 4: Harbor Deployment** (T9-T12):
- Harbor HelmRelease deployment
- Web UI access and configuration
- Image push/pull operations
- Vulnerability scanning

**Phase 5: Integration & Performance** (T13-T15):
- End-to-end CI/CD workflow (code → build → Harbor → deploy)
- Monitoring and performance baselines
- Evidence collection

**Test Cases** (High-Level Summary):

**P0 Tests (Critical Path)** (~15 tests):
- GitLab pods Running
- GitLab database connection successful
- Harbor pods Running
- Harbor database connection successful
- Harbor image push successful
- Harbor image pull successful
- GitHub ARC runners registered

**P1 Tests (Core Functionality)** (~20 tests):
- GitLab git operations working (clone, push)
- GitLab CI pipeline executes successfully
- Harbor vulnerability scan completes
- GitHub Actions workflow executes
- Runner auto-scaling working
- S3 storage operational (GitLab + Harbor)

**P2 Tests (Integration & Performance)** (~10 tests):
- End-to-end CI/CD workflow (GitLab → Harbor → K8s)
- Performance baselines (git clone <10s, pipeline <2min, image push <30s)
- Monitoring metrics collected
- Logs forwarded to VictoriaLogs
- Cross-cluster database connectivity stable

**Total Test Cases**: ~45 tests

**Traceability** (Acceptance Criteria → Test Coverage):
- AC1 (ARC operational) → T1-T2 tests
- AC2 (GitHub workflows) → T3-T4 tests
- AC3 (GitLab deployment) → T5 tests
- AC4 (GitLab UI) → T6 tests
- AC5 (GitLab git ops) → T7 tests
- AC6 (GitLab CI/CD) → T8 tests
- AC7 (Harbor deployment) → T9 tests
- AC8 (Harbor UI) → T10 tests
- AC9 (Harbor registry ops) → T11 tests
- AC10 (Harbor scanning) → T12 tests
- AC11 (E2E integration) → T13 tests
- AC12 (Monitoring) → T14 tests
- AC13 (Documentation) → T15 tasks

**Go/No-Go Criteria**:
- **GO**: All P0 tests pass, GitLab operational, Harbor operational, database connectivity stable, P1 tests >90% pass
- **NO-GO**: GitLab/Harbor not accessible, database connection failures, image push/pull broken, critical risks not mitigated

**Artifacts**:
- Full test design: `docs/qa/assessments/STORY-VALIDATE-APPS-CLUSTER-test-design-20251026.md` (to be created)
- Test execution results: `docs/qa/evidence/VALIDATE-APPS-*.png`, `docs/qa/evidence/VALIDATE-APPS-*.txt`

## *** End of Story ***
