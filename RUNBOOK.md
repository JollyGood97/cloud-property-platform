<!-- @format -->

# Plot Listing Platform - Deployment Runbook

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Local Deployment](#local-deployment)
4. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
5. [Blue-Green Deployment](#blue-green-deployment)
6. [Testing](#testing)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Required Software

- **Kubernetes**: K3s, Minikube, or any Kubernetes cluster (v1.24+)
- **Docker**: v20.10+
- **kubectl**: v1.24+
- **Python**: 3.11+
- **Git**: 2.30+
- **GitHub CLI** (optional): For automated secret management

### Required Access

- GitHub repository with write access
- Kubernetes cluster with admin privileges
- GitHub Container Registry access (for CI/CD)

### System Requirements

- **CPU**: 4 cores minimum
- **RAM**: 8GB minimum
- **Disk**: 20GB free space

---

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-username/plot-listing.git
cd plot-listing
```

### 2. Install K3s (if not already installed)

```bash
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### 3. Verify Kubernetes Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:

```
NAME     STATUS   ROLES                  AGE   VERSION
node1    Ready    control-plane,master   1d    v1.27.x
```

---

## Local Deployment

### Quick Deploy (Automated)

```bash
# Make scripts executable
chmod +x k8s/deploy.sh k8s/test-deployment.sh scripts/*.sh tests/*.sh

# Deploy everything
cd k8s
./deploy.sh

# Wait for all pods to be ready (2-3 minutes)
kubectl wait --for=condition=ready pod --all -n plot-listing --timeout=5m

# Verify deployment
./test-deployment.sh
```

### Manual Deployment (Step-by-Step)

#### Step 1: Build Docker Images

```bash
# Build listing service
cd listing-service
docker build -t listing-service:latest .

# Build inquiry service
cd ../inquiry-service
docker build -t inquiry-service:latest .

cd ..
```

#### Step 2: Import Images to K3s

```bash
docker save listing-service:latest | sudo k3s ctr images import -
docker save inquiry-service:latest | sudo k3s ctr images import -
```

#### Step 3: Deploy Infrastructure

```bash
cd k8s

# Create namespace
kubectl apply -f 00-namespace.yaml

# Deploy secrets
kubectl apply -f 01-secrets.yaml

# Deploy PostgreSQL
kubectl apply -f 02-postgres.yaml

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n plot-listing --timeout=120s
```

#### Step 4: Initialize Databases

```bash
# Run database initialization job
kubectl apply -f 09-init-db-job.yaml

# Wait for job completion
kubectl wait --for=condition=complete job/init-databases -n plot-listing --timeout=60s

# Verify databases created
kubectl logs job/init-databases -n plot-listing
```

Expected output:

```
Creating databases...
CREATE DATABASE
CREATE DATABASE
Databases created successfully!
```

#### Step 5: Deploy Microservices

```bash
# Deploy listing service
kubectl apply -f 03-listing-service.yaml

# Deploy inquiry service
kubectl apply -f 04-inquiry-service.yaml

# Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=listing-service -n plot-listing --timeout=120s
kubectl wait --for=condition=ready pod -l app=inquiry-service -n plot-listing --timeout=120s
```

#### Step 6: Deploy Frontend

```bash
kubectl apply -f 05-frontend.yaml

# Wait for frontend to be ready
kubectl wait --for=condition=ready pod -l app=frontend -n plot-listing --timeout=120s
```

#### Step 7: Deploy Ingress and Policies

```bash
# Deploy ingress
kubectl apply -f 06-ingress.yaml

# Deploy resource limits
kubectl apply -f 07-resource-limits.yaml

# Deploy network policies
kubectl apply -f 08-network-policies.yaml
```

#### Step 8: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n plot-listing

# Expected output:
# NAME                               READY   STATUS    RESTARTS   AGE
# frontend-xxxxx                     1/1     Running   0          2m
# frontend-xxxxx                     1/1     Running   0          2m
# inquiry-service-xxxxx              1/1     Running   0          3m
# inquiry-service-xxxxx              1/1     Running   0          3m
# listing-service-xxxxx              1/1     Running   0          3m
# listing-service-xxxxx              1/1     Running   0          3m
# postgres-0                         1/1     Running   0          5m

# Check services
kubectl get svc -n plot-listing
```

### Access the Application

#### Option 1: Port Forward (Recommended for local)

```bash
# Forward frontend service
kubectl port-forward -n plot-listing svc/frontend 8080:80

# Access in browser
# http://localhost:8080
```

#### Option 2: NodePort

```bash
# Get NodePort
kubectl get svc plot-listing-lb -n plot-listing

# Access via NodePort (e.g., http://localhost:30257)
```

#### Option 3: Ingress (if configured)

```bash
# Add to /etc/hosts
echo "127.0.0.1 plot-listing.local" | sudo tee -a /etc/hosts

# Access via ingress
# http://plot-listing.local
```

---

## CI/CD Pipeline Setup

### 1. Prepare GitHub Repository

```bash
# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit"

# Create GitHub repository and push
git remote add origin https://github.com/your-username/plot-listing.git
git branch -M main
git push -u origin main
```

### 2. Configure CI/CD

```bash
# Run setup script
chmod +x scripts/deploy-ci-cd.sh
./scripts/deploy-ci-cd.sh
```

This script will:

- Encode your kubeconfig
- Set GitHub secrets (KUBECONFIG)
- Update image references
- Provide instructions for GitHub Container Registry

### 3. Manual Secret Configuration (if needed)

Go to GitHub repository:

1. **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add secret:
   - **Name**: `KUBECONFIG`
   - **Value**: Base64-encoded kubeconfig (from setup script)

### 4. Enable GitHub Container Registry

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens**
2. Generate token with `write:packages` scope
3. The pipeline uses `GITHUB_TOKEN` automatically

### 5. Trigger Pipeline

```bash
# Make a change and push
git add .
git commit -m "Trigger CI/CD pipeline"
git push origin main
```

### 6. Monitor Pipeline

Go to GitHub repository → **Actions** tab

Pipeline stages:

1. ✅ **Test** - Run unit tests
2. ✅ **Build** - Build and push Docker images
3. ✅ **Deploy Blue** - Deploy to blue environment
4. ✅ **Integration Tests** - Test blue environment
5. ✅ **Switch Traffic** - Route traffic to blue
6. ✅ **Deploy Green** - Update green environment

---

## Blue-Green Deployment

### Understanding Blue-Green

- **Blue Environment**: Currently serving production traffic
- **Green Environment**: Standby environment for new deployments
- **Zero Downtime**: Switch traffic instantly between environments

### Architecture

```
                    ┌─────────────┐
                    │   Service   │
                    │  (selector) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │                         │
         ┌────▼────┐              ┌────▼────┐
         │  Blue   │              │  Green  │
         │ (v1.0)  │              │ (v1.1)  │
         └─────────┘              └─────────┘
         Active                   Standby
```

### Manual Blue-Green Deployment

```bash
# Run manual deployment script
chmod +x scripts/manual-deploy.sh
./scripts/manual-deploy.sh
```

The script will:

1. Build Docker images
2. Run tests
3. Deploy to inactive environment (blue or green)
4. Run integration tests
5. Prompt for traffic switch
6. Switch traffic if confirmed

### Check Current Active Environment

```bash
# Check which environment is active
kubectl get svc listing-service -n plot-listing -o jsonpath='{.spec.selector.version}'

# Output: blue or green
```

### Manual Traffic Switch

```bash
# Switch to blue
kubectl patch service listing-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'
kubectl patch service inquiry-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# Switch to green
kubectl patch service listing-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"green"}}}'
kubectl patch service inquiry-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"green"}}}'
```

---

## Testing

### Unit Tests

```bash
# Test listing service
cd listing-service
pip install -r requirements.txt
pytest test_main.py -v

# Test inquiry service
cd ../inquiry-service
pip install -r requirements.txt
pytest test_main.py -v
```

### Integration Tests

```bash
# Run full integration test suite
chmod +x tests/integration-tests.sh
./tests/integration-tests.sh
```

Tests include:

- ✅ Health checks
- ✅ Create listing
- ✅ Get all listings
- ✅ Get specific listing
- ✅ Update listing
- ✅ Create inquiry
- ✅ Get inquiries
- ✅ Database persistence
- ✅ Load testing
- ✅ Delete operations

### Manual API Testing

```bash
# Port forward services
kubectl port-forward -n plot-listing svc/frontend 8080:80 &

# Test listing API
curl -X POST http://localhost:8080/api/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "TEST001",
    "title": "Test Property",
    "location": "Test City",
    "category": "Sale",
    "price": 100000,
    "available": true
  }'

# Get listings
curl http://localhost:8080/api/listings

# Test inquiry API
curl -X POST http://localhost:8080/api/inquiries \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "TEST001",
    "name": "Test User",
    "email": "test@example.com",
    "phone": "+1234567890",
    "message": "Interested in this property"
  }'

# Get inquiries
curl http://localhost:8080/api/inquiries
```

### Load Testing

```bash
# Install Apache Bench (if not installed)
sudo apt-get install apache2-utils

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 http://localhost:8080/api/listings
```

---

## Monitoring

### Check Pod Status

```bash
# Get all pods
kubectl get pods -n plot-listing

# Watch pods in real-time
kubectl get pods -n plot-listing -w

# Get detailed pod info
kubectl describe pod <pod-name> -n plot-listing
```

### View Logs

```bash
# View logs for a specific pod
kubectl logs <pod-name> -n plot-listing

# Follow logs in real-time
kubectl logs -f <pod-name> -n plot-listing

# View logs for all pods of a service
kubectl logs -l app=listing-service -n plot-listing --tail=100
```

### Check Resource Usage

```bash
# Get resource usage
kubectl top pods -n plot-listing
kubectl top nodes

# Check resource limits
kubectl describe resourcequota -n plot-listing
```

### Check Service Health

```bash
# Port forward and check health endpoints
kubectl port-forward -n plot-listing svc/listing-service 8000:8000 &
curl http://localhost:8000/health

kubectl port-forward -n plot-listing svc/inquiry-service 8001:8001 &
curl http://localhost:8001/health
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n plot-listing

# Common issues:
# 1. Image pull error - Check image name and registry
# 2. Init container failing - Check database connectivity
# 3. Resource limits - Check available resources
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pod postgres-0 -n plot-listing

# Check PostgreSQL logs
kubectl logs postgres-0 -n plot-listing

# Test database connectivity from service pod
kubectl exec -it <service-pod> -n plot-listing -- sh
nc -zv postgres 5432
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n plot-listing

# Check if pods are ready
kubectl get pods -n plot-listing

# Check ingress
kubectl describe ingress plot-listing-ingress -n plot-listing

# Check network policies
kubectl get networkpolicies -n plot-listing
```

### CI/CD Pipeline Failing

```bash
# Check GitHub Actions logs
# Go to: GitHub → Actions → Select failed workflow

# Common issues:
# 1. KUBECONFIG secret not set
# 2. Image registry authentication
# 3. Kubernetes cluster not accessible
# 4. Tests failing
```

---

## Rollback Procedures

### Immediate Rollback (Blue-Green)

```bash
# If green is broken, switch back to blue
kubectl patch service listing-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'
kubectl patch service inquiry-service -n plot-listing \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# Verify traffic switched
kubectl get svc listing-service inquiry-service -n plot-listing -o wide
```

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/listing-service -n plot-listing

# Rollback to previous version
kubectl rollout undo deployment/listing-service -n plot-listing
kubectl rollout undo deployment/inquiry-service -n plot-listing

# Rollback to specific revision
kubectl rollout undo deployment/listing-service -n plot-listing --to-revision=2
```

### Database Rollback

```bash
# If database migration failed, restore from backup
# (Ensure you have database backups configured)

# Access PostgreSQL pod
kubectl exec -it postgres-0 -n plot-listing -- bash

# Restore database
psql -U plotuser -d listings_db < /backup/listings_db_backup.sql
psql -U plotuser -d inquiries_db < /backup/inquiries_db_backup.sql
```

---

## Cleanup

### Remove Deployment

```bash
# Run cleanup script
cd k8s
./cleanup.sh

# Or manually
kubectl delete namespace plot-listing
```

### Remove K3s (if needed)

```bash
/usr/local/bin/k3s-uninstall.sh
```

---

## Support and Contacts

- **Documentation**: See README.md files in each service directory
- **Issues**: GitHub Issues
- **Architecture**: See architecture diagrams in report

---

## Appendix

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n plot-listing

# Get events
kubectl get events -n plot-listing --sort-by='.lastTimestamp'

# Execute command in pod
kubectl exec -it <pod-name> -n plot-listing -- /bin/sh

# Copy files from pod
kubectl cp plot-listing/<pod-name>:/path/to/file ./local-file

# Scale deployment
kubectl scale deployment/listing-service -n plot-listing --replicas=3

# Update image
kubectl set image deployment/listing-service \
  listing-service=listing-service:v2.0 -n plot-listing
```

### Environment Variables

| Variable     | Description                  | Default                                                     |
| ------------ | ---------------------------- | ----------------------------------------------------------- |
| DATABASE_URL | PostgreSQL connection string | postgresql://plotuser:plotpass123@postgres:5432/listings_db |
| NAMESPACE    | Kubernetes namespace         | plot-listing                                                |

---

**Last Updated**: December 2025  
**Version**: 1.0
