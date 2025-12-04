<!-- @format -->

# CI/CD Pipeline Documentation

## Overview

The Plot Listing platform uses GitHub Actions for continuous integration and continuous deployment (CI/CD) with a Blue-Green deployment strategy to ensure zero-downtime deployments.

## Architecture

### CI/CD Pipeline Flow

```
┌─────────────┐
│  Git Push   │
│  to main    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Stage 1: TEST                                          │
│  ├─ Install dependencies                                │
│  ├─ Run unit tests (listing-service)                    │
│  └─ Run unit tests (inquiry-service)                    │
│                                                          │
│  Stage 2: BUILD                                         │
│  ├─ Build Docker image (listing-service)                │
│  ├─ Build Docker image (inquiry-service)                │
│  ├─ Tag images with commit SHA                          │
│  └─ Push to GitHub Container Registry                   │
│                                                          │
│  Stage 3: DEPLOY BLUE                                   │
│  ├─ Update blue deployment with new images              │
│  ├─ Wait for rollout completion                         │
│  └─ Run integration tests on blue                       │
│                                                          │
│  Stage 4: SWITCH TRAFFIC                                │
│  ├─ Update service selector to blue                     │
│  ├─ Verify traffic switch                               │
│  └─ Monitor for errors                                  │
│                                                          │
│  Stage 5: DEPLOY GREEN                                  │
│  ├─ Update green deployment with new images             │
│  ├─ Wait for rollout completion                         │
│  └─ Green ready for next deployment                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│  Production │
│   Running   │
└─────────────┘
```

## Blue-Green Deployment Strategy

### Concept

Blue-Green deployment is a release management strategy that reduces downtime and risk by running two identical production environments:

- **Blue Environment**: Currently serving production traffic
- **Green Environment**: Idle environment ready for new deployment

### Benefits

1. **Zero Downtime**: Instant traffic switch between environments
2. **Easy Rollback**: Switch back to previous version immediately
3. **Testing in Production**: Test new version before switching traffic
4. **Risk Mitigation**: Issues in new deployment don't affect users

### Deployment Process

```
Initial State:
┌──────────┐         ┌──────────┐
│   Blue   │ ◄────── │ Traffic  │
│  (v1.0)  │         │          │
└──────────┘         └──────────┘
┌──────────┐
│  Green   │
│  (idle)  │
└──────────┘

Step 1: Deploy to Green
┌──────────┐         ┌──────────┐
│   Blue   │ ◄────── │ Traffic  │
│  (v1.0)  │         │          │
└──────────┘         └──────────┘
┌──────────┐
│  Green   │ ◄────── Deploying v1.1
│  (v1.1)  │
└──────────┘

Step 2: Test Green
┌──────────┐         ┌──────────┐
│   Blue   │ ◄────── │ Traffic  │
│  (v1.0)  │         │          │
└──────────┘         └──────────┘
┌──────────┐
│  Green   │ ◄────── Running tests
│  (v1.1)  │         ✓ Tests passed
└──────────┘

Step 3: Switch Traffic
┌──────────┐         ┌──────────┐
│   Blue   │         │ Traffic  │
│  (v1.0)  │         │          │
└──────────┘         └─────┬────┘
┌──────────┐               │
│  Green   │ ◄─────────────┘
│  (v1.1)  │
└──────────┘

Step 4: Update Blue
┌──────────┐
│   Blue   │ ◄────── Updating to v1.1
│  (v1.1)  │
└──────────┘         ┌──────────┐
┌──────────┐         │ Traffic  │
│  Green   │ ◄────── │          │
│  (v1.1)  │         └──────────┘
└──────────┘

Final State: Both environments on v1.1
┌──────────┐
│   Blue   │
│  (v1.1)  │
└──────────┘         ┌──────────┐
┌──────────┐         │ Traffic  │
│  Green   │ ◄────── │          │
│  (v1.1)  │         └──────────┘
└──────────┘
```

## GitHub Actions Workflow

### File Location

`.github/workflows/ci-cd-pipeline.yaml`

### Triggers

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch: # Manual trigger
  schedule:
    - cron: "0 */6 * * *" # Periodic tests every 6 hours
```

### Jobs

#### 1. Test Job

**Purpose**: Validate code quality and functionality

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Set up Python 3.11
      - Install dependencies
      - Run pytest for listing-service
      - Run pytest for inquiry-service
```

**Exit Criteria**: All tests must pass

#### 2. Build Job

**Purpose**: Create Docker images and push to registry

```yaml
jobs:
  build:
    needs: test
    steps:
      - Checkout code
      - Login to GitHub Container Registry
      - Build listing-service image
      - Tag with commit SHA and branch name
      - Push to ghcr.io
      - Build inquiry-service image
      - Tag with commit SHA and branch name
      - Push to ghcr.io
```

**Artifacts**:

- `ghcr.io/username/listing-service:main-<sha>`
- `ghcr.io/username/inquiry-service:main-<sha>`

#### 3. Deploy Blue Job

**Purpose**: Deploy new version to blue environment

```yaml
jobs:
  deploy-blue:
    needs: build
    environment: production-blue
    steps:
      - Configure kubectl
      - Update blue deployment images
      - Wait for rollout (timeout: 5 minutes)
      - Run integration tests
```

**Exit Criteria**:

- Deployment successful
- All pods healthy
- Integration tests pass

#### 4. Switch Traffic Job

**Purpose**: Route production traffic to blue environment

```yaml
jobs:
  switch-to-blue:
    needs: deploy-blue
    environment: production-switch
    steps:
      - Patch service selectors to blue
      - Verify traffic switch
      - Monitor for errors
```

**Manual Approval**: Required (configured in GitHub environment)

#### 5. Deploy Green Job

**Purpose**: Update green environment for next deployment

```yaml
jobs:
  deploy-green:
    needs: switch-to-blue
    environment: production-green
    steps:
      - Update green deployment images
      - Wait for rollout
      - Verify green is ready
```

### Periodic Tests Job

**Purpose**: Continuous monitoring of production

```yaml
jobs:
  periodic-tests:
    schedule: "0 */6 * * *"
    steps:
      - Run integration tests
      - Notify on failure
```

## Setup Instructions

### 1. Prerequisites

- GitHub repository
- Kubernetes cluster (K3s, EKS, GKE, AKS)
- kubectl configured
- Docker installed

### 2. Configure GitHub Secrets

Navigate to: **Repository → Settings → Secrets and variables → Actions**

Add the following secret:

| Secret Name  | Description               | How to Get                          |
| ------------ | ------------------------- | ----------------------------------- |
| `KUBECONFIG` | Base64-encoded kubeconfig | `cat ~/.kube/config \| base64 -w 0` |

### 3. Enable GitHub Container Registry

1. Go to **GitHub Settings → Developer settings → Personal access tokens**
2. Generate token with `write:packages` scope
3. GitHub Actions automatically uses `GITHUB_TOKEN`

### 4. Update Image References

Edit `k8s/blue-green/*.yaml` files:

```yaml
# Replace 'your-username' with your GitHub username
image: ghcr.io/your-username/listing-service:latest
```

### 5. Run Setup Script

```bash
chmod +x scripts/deploy-ci-cd.sh
./scripts/deploy-ci-cd.sh
```

### 6. Commit and Push

```bash
git add .
git commit -m "Add CI/CD pipeline"
git push origin main
```

### 7. Monitor Pipeline

Go to: **Repository → Actions**

Watch the pipeline execute through all stages.

## Manual Deployment

For local testing or when CI/CD is unavailable:

```bash
chmod +x scripts/manual-deploy.sh
./scripts/manual-deploy.sh
```

This script:

1. Builds Docker images locally
2. Imports to K3s
3. Runs tests
4. Deploys to inactive environment
5. Prompts for traffic switch
6. Updates active environment

## Testing

### Automated Test Suite

```bash
chmod +x tests/run-all-tests.sh
./tests/run-all-tests.sh
```

Tests include:

- Unit tests (pytest)
- Smoke tests (health checks)
- Integration tests (API functionality)
- Load tests (concurrent requests)

### Integration Tests

```bash
chmod +x tests/integration-tests.sh
./tests/integration-tests.sh
```

Tests:

- ✅ Health checks
- ✅ CRUD operations
- ✅ Database persistence
- ✅ Load handling
- ✅ Error handling

## Monitoring and Observability

### Pipeline Monitoring

**GitHub Actions Dashboard**:

- Real-time pipeline status
- Job logs and artifacts
- Deployment history
- Test results

### Application Monitoring

```bash
# Check deployment status
kubectl get deployments -n plot-listing

# Check pod health
kubectl get pods -n plot-listing

# View logs
kubectl logs -f deployment/listing-service-blue -n plot-listing

# Check resource usage
kubectl top pods -n plot-listing
```

### Metrics to Monitor

1. **Deployment Metrics**:

   - Deployment frequency
   - Lead time for changes
   - Mean time to recovery (MTTR)
   - Change failure rate

2. **Application Metrics**:

   - Request rate
   - Error rate
   - Response time
   - Pod restarts

3. **Infrastructure Metrics**:
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network traffic

## Rollback Procedures

### Immediate Rollback (Blue-Green)

If issues detected after traffic switch:

```bash
# Switch back to previous environment
kubectl patch service listing-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'

kubectl patch service inquiry-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

**Time to rollback**: < 10 seconds

### Deployment Rollback

```bash
# View rollout history
kubectl rollout history deployment/listing-service-blue -n plot-listing

# Rollback to previous version
kubectl rollout undo deployment/listing-service-blue -n plot-listing

# Rollback to specific revision
kubectl rollout undo deployment/listing-service-blue \
  -n plot-listing --to-revision=2
```

## Security Considerations

### 1. Secrets Management

- ✅ Kubernetes secrets for database credentials
- ✅ GitHub secrets for kubeconfig
- ✅ No hardcoded credentials in code
- ✅ Secrets encrypted at rest

### 2. Image Security

- ✅ Images scanned for vulnerabilities
- ✅ Use official base images
- ✅ Regular image updates
- ✅ Minimal image size

### 3. Network Security

- ✅ Network policies restrict pod communication
- ✅ Services not exposed externally unless needed
- ✅ TLS for external communication
- ✅ Ingress with authentication

### 4. Access Control

- ✅ RBAC for Kubernetes access
- ✅ GitHub branch protection
- ✅ Required reviews for PRs
- ✅ Manual approval for production deployments

## Ethical Considerations

### 1. Data Privacy

- User data encrypted in transit and at rest
- Minimal data collection
- GDPR compliance considerations
- Data retention policies

### 2. Availability

- High availability architecture
- Zero-downtime deployments
- Disaster recovery plan
- Regular backups

### 3. Transparency

- Open source components
- Clear documentation
- Audit logs
- Incident reporting

### 4. Environmental Impact

- Resource optimization
- Efficient container images
- Auto-scaling to reduce waste
- Green hosting considerations

## Troubleshooting

### Pipeline Fails at Test Stage

**Symptoms**: Tests fail in GitHub Actions

**Solutions**:

1. Run tests locally: `pytest test_main.py -v`
2. Check test logs in Actions tab
3. Verify dependencies in requirements.txt
4. Check database connectivity

### Pipeline Fails at Build Stage

**Symptoms**: Docker build fails

**Solutions**:

1. Verify Dockerfile syntax
2. Check base image availability
3. Verify GitHub Container Registry access
4. Check GITHUB_TOKEN permissions

### Pipeline Fails at Deploy Stage

**Symptoms**: Deployment to Kubernetes fails

**Solutions**:

1. Verify KUBECONFIG secret is set correctly
2. Check cluster connectivity
3. Verify namespace exists
4. Check resource quotas

### Integration Tests Fail

**Symptoms**: Tests pass locally but fail in pipeline

**Solutions**:

1. Check service endpoints
2. Verify port forwards
3. Check pod readiness
4. Review test timeouts

## Best Practices

### 1. Version Control

- ✅ Semantic versioning for releases
- ✅ Tag releases in Git
- ✅ Maintain CHANGELOG.md
- ✅ Branch protection rules

### 2. Testing

- ✅ Write tests before code (TDD)
- ✅ Maintain >80% code coverage
- ✅ Run tests on every commit
- ✅ Automated integration tests

### 3. Deployment

- ✅ Small, frequent deployments
- ✅ Automated deployments
- ✅ Canary deployments for high-risk changes
- ✅ Feature flags for gradual rollout

### 4. Monitoring

- ✅ Monitor all environments
- ✅ Set up alerts for critical metrics
- ✅ Regular health checks
- ✅ Log aggregation and analysis

## Maintenance

### Regular Tasks

**Daily**:

- Monitor pipeline runs
- Review failed deployments
- Check application logs

**Weekly**:

- Review test coverage
- Update dependencies
- Check security vulnerabilities
- Review resource usage

**Monthly**:

- Update base images
- Review and update documentation
- Conduct disaster recovery drills
- Review and optimize costs

## Support

- **Documentation**: See RUNBOOK.md
- **Issues**: GitHub Issues
- **Pipeline Logs**: GitHub Actions tab
- **Application Logs**: `kubectl logs`

---

**Last Updated**: December 2025  
**Version**: 1.0  
**Maintained by**: Plot Listing DevOps Team
