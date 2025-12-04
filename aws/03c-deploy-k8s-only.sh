#!/bin/bash

# Deploy only K8s manifests (images already built)

set -e

echo "========================================="
echo "Deploy to K3s (K8s manifests only)"
echo "========================================="
echo ""

# Check if ec2-details.txt exists
if [ ! -f "ec2-details.txt" ]; then
    echo "❌ ec2-details.txt not found!"
    exit 1
fi

# Read EC2 details
PUBLIC_IP=$(grep "Public IP:" ec2-details.txt | awk '{print $3}')
KEY_FILE="plot-listing-key.pem"

echo "EC2 Public IP: $PUBLIC_IP"
echo ""

echo "Deploying Kubernetes manifests..."
echo ""

ssh -i $KEY_FILE ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

cd ~/plot-services/k8s

echo "Step 1: Creating namespace..."
sudo k3s kubectl apply -f 00-namespace.yaml

echo ""
echo "Step 2: Creating secrets..."
sudo k3s kubectl apply -f 01-secrets.yaml

echo ""
echo "Step 3: Deploying PostgreSQL..."
sudo k3s kubectl apply -f 02-postgres.yaml

echo "Waiting for PostgreSQL to be ready..."
sudo k3s kubectl wait --for=condition=ready pod -l app=postgres -n plot-listing --timeout=120s

echo ""
echo "Step 4: Initializing databases..."
sudo k3s kubectl apply -f 09-init-db-job.yaml

echo "Waiting for database initialization..."
sudo k3s kubectl wait --for=condition=complete job/init-databases -n plot-listing --timeout=60s

echo ""
echo "Step 5: Deploying microservices..."
sudo k3s kubectl apply -f 03-listing-service.yaml
sudo k3s kubectl apply -f 04-inquiry-service.yaml

echo ""
echo "Step 6: Deploying frontend..."
sudo k3s kubectl apply -f 05-frontend.yaml

echo ""
echo "Step 7: Deploying ingress and policies..."
sudo k3s kubectl apply -f 06-ingress.yaml
sudo k3s kubectl apply -f 07-resource-limits.yaml
sudo k3s kubectl apply -f 08-network-policies.yaml

echo ""
echo "Waiting for all pods to be ready (this may take 2-3 minutes)..."
sudo k3s kubectl wait --for=condition=ready pod --all -n plot-listing --timeout=300s

echo ""
echo "✅ All pods are ready!"
echo ""

# Show deployment status
echo "========================================="
echo "Deployment Status"
echo "========================================="
echo ""

echo "Pods:"
sudo k3s kubectl get pods -n plot-listing

echo ""
echo "Services:"
sudo k3s kubectl get svc -n plot-listing

echo ""
echo "Ingress:"
sudo k3s kubectl get ingress -n plot-listing 2>/dev/null || echo "No ingress found"

ENDSSH

echo ""
echo "========================================="
echo "✅ Application Deployed Successfully!"
echo "========================================="
echo ""
echo "Your application is now running on EC2!"
echo ""
echo "Access URLs:"
echo "  Frontend: http://$PUBLIC_IP:30257"
echo "  Listing API: http://$PUBLIC_IP:30257/api/listings"
echo "  Inquiry API: http://$PUBLIC_IP:30257/api/inquiries"
echo ""
echo "Test it:"
echo "  curl http://$PUBLIC_IP:30257/api/listings"
echo ""
echo "To check status:"
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo k3s kubectl get pods -n plot-listing'"
echo ""

# Save access info
cat > app-access.txt << EOF
Application Access Information
==============================

Frontend: http://$PUBLIC_IP:30257
Listing API: http://$PUBLIC_IP:30257/api/listings
Inquiry API: http://$PUBLIC_IP:30257/api/inquiries

Test Commands:
--------------

# Get all listings
curl http://$PUBLIC_IP:30257/api/listings

# Create a listing
curl -X POST http://$PUBLIC_IP:30257/api/listings \\
  -H "Content-Type: application/json" \\
  -d '{
    "plot_id": "AWS001",
    "title": "Cloud Villa",
    "location": "AWS Region",
    "category": "Sale",
    "price": 500000,
    "available": true
  }'

# Get all inquiries
curl http://$PUBLIC_IP:30257/api/inquiries

# Create an inquiry
curl -X POST http://$PUBLIC_IP:30257/api/inquiries \\
  -H "Content-Type: application/json" \\
  -d '{
    "plot_id": "AWS001",
    "name": "Test User",
    "email": "test@example.com",
    "phone": "+1234567890",
    "message": "Interested in this property"
  }'

SSH Access:
-----------
ssh -i plot-listing-key.pem ubuntu@$PUBLIC_IP

Check Pods:
-----------
ssh -i plot-listing-key.pem ubuntu@$PUBLIC_IP 'sudo k3s kubectl get pods -n plot-listing'

View Logs:
----------
ssh -i plot-listing-key.pem ubuntu@$PUBLIC_IP 'sudo k3s kubectl logs -f deployment/listing-service -n plot-listing'
EOF

echo "✅ Access information saved to: app-access.txt"
echo ""
echo "========================================="
echo "Next: Test your application!"
echo "  curl http://$PUBLIC_IP:30257/api/listings"
echo "========================================="
