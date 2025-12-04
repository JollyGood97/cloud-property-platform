# Kubernetes Deployment for Plot Listing Platform

This directory contains all Kubernetes manifests for deploying the Plot Listing platform on K3s.

## 📁 Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Creates plot-listing namespace |
| `01-secrets.yaml` | PostgreSQL credentials |
| `02-postgres.yaml` | PostgreSQL StatefulSet + PVC |
| `03-listing-service.yaml` | Listing service deployment |
| `04-inquiry-service.yaml` | Inquiry service deployment |
| `05-frontend.yaml` | Frontend deployment with Nginx |
| `06-ingress.yaml` | Ingress + LoadBalancer |
| `07-resource-limits.yaml` | Resource quotas & limits |
| `08-network-policies.yaml` | Network security policies |
| `09-init-db-job.yaml` | Database initialization job |

## 🚀 Quick Deploy

```bash
# Make scripts executable
chmod +x deploy.sh cleanup.sh test-deployment.sh

# Deploy everything
./deploy.sh

# Test deployment
./test-deployment.sh

# Cleanup (if needed)
./cleanup.sh
```

## 📋 Manual Deployment

```bash
# 1. Build Docker images
cd /home/semini/Documents/iit/plot-services
docker build -t listing-service:latest ./listing-service
docker build -t inquiry-service:latest ./inquiry-service

# 2. Import to K3s
docker save listing-service:latest | sudo k3s ctr images import -
docker save inquiry-service:latest | sudo k3s ctr images import -

# 3. Deploy in order
cd k8s
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secrets.yaml
kubectl apply -f 02-postgres.yaml

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n plot-listing --timeout=120s

# Initialize databases
kubectl apply -f 09-init-db-job.yaml
kubectl wait --for=condition=complete job/init-databases -n plot-listing --timeout=60s

# Deploy services
kubectl apply -f 03-listing-service.yaml
kubectl apply -f 04-inquiry-service.yaml
kubectl apply -f 05-frontend.yaml
kubectl apply -f 06-ingress.yaml
kubectl apply -f 07-resource-limits.yaml
kubectl apply -f 08-network-policies.yaml
```

## 🔍 Verify Deployment

```bash
# Check pods
kubectl get pods -n plot-listing

# Check services
kubectl get svc -n plot-listing

# Check ingress
kubectl get ingress -n plot-listing

# Get LoadBalancer IP
kubectl get svc plot-listing-lb -n plot-listing

# View logs
kubectl logs -f <pod-name> -n plot-listing
```

## 🌐 Access Application

```bash
# Get LoadBalancer IP
LB_IP=$(kubectl get svc plot-listing-lb -n plot-listing -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access frontend
curl http://$LB_IP/

# Test listing API
curl http://$LB_IP/api/listings

# Test inquiry API
curl http://$LB_IP/api/inquiries
```

## 🏗️ Architecture

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         ┌────▼───┐   ┌───▼────┐  ┌───▼────┐
         │Frontend│   │Listing │  │Inquiry │
         │        │   │Service │  │Service │
         └────────┘   └───┬────┘  └───┬────┘
                          │            │
                      ┌───▼────────────▼───┐
                      │    PostgreSQL      │
                      └────────────────────┘
```

## 🔒 Security Features

- ✅ Network policies (pod-to-pod isolation)
- ✅ Resource limits (prevent resource exhaustion)
- ✅ Secrets for credentials
- ✅ Non-root containers
- ✅ Health checks (liveness & readiness)
- ✅ Init containers (wait for dependencies)

## 📊 Scalability Features

- ✅ Horizontal Pod Autoscaler (HPA)
- ✅ Multiple replicas (2 per service)
- ✅ Auto-scaling based on CPU (70% threshold)
- ✅ Resource requests & limits

## 🛠️ Troubleshooting

```bash
# Pod not starting
kubectl describe pod <pod-name> -n plot-listing

# Check logs
kubectl logs <pod-name> -n plot-listing

# Check events
kubectl get events -n plot-listing --sort-by='.lastTimestamp'

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n plot-listing

# Access pod shell
kubectl exec -it <pod-name> -n plot-listing -- /bin/sh
```

## 🔄 Updates

```bash
# Rebuild and update image
docker build -t listing-service:latest ./listing-service
docker save listing-service:latest | sudo k3s ctr images import -

# Restart deployment (rolling update)
kubectl rollout restart deployment/listing-service -n plot-listing

# Check rollout status
kubectl rollout status deployment/listing-service -n plot-listing
```
