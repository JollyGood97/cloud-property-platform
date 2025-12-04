#!/bin/bash

# Manual deployment script for Plot Listing Platform
# Use this for local deployments or when CI/CD is not available

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Plot Listing Manual Deployment${NC}"
echo -e "${GREEN}=========================================${NC}"

# Configuration
NAMESPACE="plot-listing"
CURRENT_ENV="blue"  # Start with blue

# Function to check if deployment exists
deployment_exists() {
    kubectl get deployment $1 -n $NAMESPACE &> /dev/null
}

# Step 1: Build Docker images
echo -e "${YELLOW}Step 1: Building Docker images...${NC}"
docker build -t listing-service:latest ./listing-service
docker build -t inquiry-service:latest ./inquiry-service
echo -e "${GREEN}✓ Images built${NC}"

# Step 2: Import to K3s
echo -e "${YELLOW}Step 2: Importing images to K3s...${NC}"
docker save listing-service:latest | sudo k3s ctr images import -
docker save inquiry-service:latest | sudo k3s ctr images import -
echo -e "${GREEN}✓ Images imported${NC}"

# Step 3: Run tests
echo -e "${YELLOW}Step 3: Running tests...${NC}"
cd listing-service && pytest test_main.py -v && cd ..
cd inquiry-service && pytest test_main.py -v && cd ..
echo -e "${GREEN}✓ Tests passed${NC}"

# Step 4: Deploy base infrastructure (if not exists)
echo -e "${YELLOW}Step 4: Checking base infrastructure...${NC}"
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "Deploying base infrastructure..."
    kubectl apply -f k8s/00-namespace.yaml
    kubectl apply -f k8s/01-secrets.yaml
    kubectl apply -f k8s/02-postgres.yaml
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s
    kubectl apply -f k8s/09-init-db-job.yaml
    kubectl wait --for=condition=complete job/init-databases -n $NAMESPACE --timeout=60s
    echo -e "${GREEN}✓ Base infrastructure deployed${NC}"
else
    echo -e "${GREEN}✓ Base infrastructure exists${NC}"
fi

# Step 5: Determine current active environment
echo -e "${YELLOW}Step 5: Determining active environment...${NC}"
if deployment_exists "listing-service-blue"; then
    CURRENT_SELECTOR=$(kubectl get svc listing-service -n $NAMESPACE -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")
    if [ "$CURRENT_SELECTOR" == "blue" ]; then
        DEPLOY_TO="green"
        CURRENT_ENV="blue"
    else
        DEPLOY_TO="blue"
        CURRENT_ENV="green"
    fi
else
    DEPLOY_TO="blue"
    CURRENT_ENV="none"
fi

echo -e "${GREEN}Current active: $CURRENT_ENV${NC}"
echo -e "${GREEN}Deploying to: $DEPLOY_TO${NC}"

# Step 6: Deploy to inactive environment
echo -e "${YELLOW}Step 6: Deploying to $DEPLOY_TO environment...${NC}"

# Update image tags in manifests
sed -i "s|image: .*listing-service.*|image: listing-service:latest|g" k8s/blue-green/listing-service-blue-green.yaml
sed -i "s|image: .*inquiry-service.*|image: inquiry-service:latest|g" k8s/blue-green/inquiry-service-blue-green.yaml

kubectl apply -f k8s/blue-green/listing-service-blue-green.yaml
kubectl apply -f k8s/blue-green/inquiry-service-blue-green.yaml

# Wait for rollout
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/listing-service-$DEPLOY_TO -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/inquiry-service-$DEPLOY_TO -n $NAMESPACE --timeout=5m
echo -e "${GREEN}✓ Deployment complete${NC}"

# Step 7: Run integration tests on new environment
echo -e "${YELLOW}Step 7: Running integration tests on $DEPLOY_TO...${NC}"
export ENVIRONMENT=$DEPLOY_TO
chmod +x tests/integration-tests.sh
if ./tests/integration-tests.sh; then
    echo -e "${GREEN}✓ Integration tests passed${NC}"
else
    echo -e "${RED}✗ Integration tests failed!${NC}"
    echo "Deployment to $DEPLOY_TO completed but tests failed."
    echo "Traffic is still on $CURRENT_ENV. Investigate before switching."
    exit 1
fi

# Step 8: Switch traffic
echo -e "${YELLOW}Step 8: Switching traffic to $DEPLOY_TO...${NC}"
read -p "Switch traffic to $DEPLOY_TO? (yes/no): " CONFIRM

if [ "$CONFIRM" == "yes" ]; then
    kubectl patch service listing-service -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"version\":\"$DEPLOY_TO\"}}}"
    kubectl patch service inquiry-service -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"version\":\"$DEPLOY_TO\"}}}"
    echo -e "${GREEN}✓ Traffic switched to $DEPLOY_TO${NC}"
    
    # Deploy frontend and other services
    echo -e "${YELLOW}Step 9: Deploying frontend and supporting services...${NC}"
    kubectl apply -f k8s/05-frontend.yaml
    kubectl apply -f k8s/06-ingress.yaml
    kubectl apply -f k8s/07-resource-limits.yaml
    kubectl apply -f k8s/08-network-policies.yaml
    echo -e "${GREEN}✓ All services deployed${NC}"
else
    echo -e "${YELLOW}Traffic switch cancelled. $DEPLOY_TO is ready but not active.${NC}"
fi

# Step 10: Verify deployment
echo -e "${YELLOW}Step 10: Verifying deployment...${NC}"
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Active environment: $DEPLOY_TO"
echo ""
echo "Access the application:"
echo "  kubectl port-forward -n $NAMESPACE svc/frontend 8080:80"
echo "  Then visit: http://localhost:8080"
echo ""
echo "Run tests:"
echo "  ./tests/integration-tests.sh"
echo ""
