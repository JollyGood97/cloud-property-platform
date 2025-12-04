#!/bin/bash
# Deployment script for Plot Listing platform on K3s

set -e

echo "🚀 Deploying Plot Listing Platform to K3s..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if K3s is running
echo -e "${BLUE}Checking K3s status...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ K3s is not running. Please start K3s first."
    exit 1
fi
echo -e "${GREEN}✓ K3s is running${NC}"
echo ""

# Build Docker images
echo -e "${BLUE}Building Docker images...${NC}"
cd /home/semini/Documents/iit/plot-services

echo "Building listing-service..."
docker build -t listing-service:latest ./listing-service
echo -e "${GREEN}✓ listing-service built${NC}"

echo "Building inquiry-service..."
docker build -t inquiry-service:latest ./inquiry-service
echo -e "${GREEN}✓ inquiry-service built${NC}"
echo ""

# Import images to K3s
echo -e "${BLUE}Importing images to K3s...${NC}"
docker save listing-service:latest | sudo k3s ctr images import -
docker save inquiry-service:latest | sudo k3s ctr images import -
echo -e "${GREEN}✓ Images imported${NC}"
echo ""

# Deploy to K3s
echo -e "${BLUE}Deploying to K3s...${NC}"
cd k8s

echo "1. Creating namespace..."
kubectl apply -f 00-namespace.yaml

echo "2. Creating secrets..."
kubectl apply -f 01-secrets.yaml

echo "3. Deploying PostgreSQL..."
kubectl apply -f 02-postgres.yaml

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n plot-listing --timeout=120s

echo "4. Initializing databases..."
kubectl apply -f 09-init-db-job.yaml
kubectl wait --for=condition=complete job/init-databases -n plot-listing --timeout=60s

echo "5. Deploying listing service..."
kubectl apply -f 03-listing-service.yaml

echo "6. Deploying inquiry service..."
kubectl apply -f 04-inquiry-service.yaml

echo "7. Deploying frontend..."
kubectl apply -f 05-frontend.yaml

echo "8. Creating ingress..."
kubectl apply -f 06-ingress.yaml

echo "9. Applying resource limits..."
kubectl apply -f 07-resource-limits.yaml

echo "10. Applying network policies..."
kubectl apply -f 08-network-policies.yaml

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Show status
echo -e "${BLUE}Checking deployment status...${NC}"
kubectl get pods -n plot-listing
echo ""

echo -e "${BLUE}Services:${NC}"
kubectl get svc -n plot-listing
echo ""

# Get LoadBalancer IP
echo -e "${YELLOW}Waiting for LoadBalancer IP...${NC}"
sleep 5
LB_IP=$(kubectl get svc plot-listing-lb -n plot-listing -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
echo -e "${GREEN}🎉 Deployment Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Namespace: plot-listing"
echo "Services deployed: 3 (listing, inquiry, frontend)"
echo "Database: PostgreSQL"
echo ""
if [ "$LB_IP" != "pending" ]; then
    echo -e "${GREEN}Access your application at: http://$LB_IP${NC}"
else
    echo -e "${YELLOW}LoadBalancer IP pending. Run: kubectl get svc -n plot-listing${NC}"
fi
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n plot-listing"
echo "  kubectl logs -f <pod-name> -n plot-listing"
echo "  kubectl describe pod <pod-name> -n plot-listing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
