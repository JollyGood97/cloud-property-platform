#!/bin/bash

# Step 3: Deploy Plot Listing application to EC2 K3s cluster
# This script copies your files and deploys everything

set -e

echo "========================================="
echo "Step 3: Deploy Application to EC2"
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

# Step 3.1: Copy files to EC2
echo "Step 3.1: Copying files to EC2..."
echo "This may take a minute..."
echo ""

# Create remote directory
ssh -i $KEY_FILE ubuntu@$PUBLIC_IP "mkdir -p ~/plot-services"

# Copy necessary files
echo "Copying listing-service..."
scp -i $KEY_FILE -r listing-service ubuntu@$PUBLIC_IP:~/plot-services/

echo "Copying inquiry-service..."
scp -i $KEY_FILE -r inquiry-service ubuntu@$PUBLIC_IP:~/plot-services/

echo "Copying plot-frontend..."
scp -i $KEY_FILE -r plot-frontend ubuntu@$PUBLIC_IP:~/plot-services/

echo "Copying k8s manifests..."
scp -i $KEY_FILE -r k8s ubuntu@$PUBLIC_IP:~/plot-services/

echo "✅ Files copied to EC2"
echo ""

# Step 3.2: Install Docker on EC2
echo "Step 3.2: Installing Docker on EC2..."
echo ""

ssh -i $KEY_FILE ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

ENDSSH

echo ""
echo "Step 3.3: Building Docker images on EC2..."
echo "This takes ~3-5 minutes..."
echo ""

ssh -i $KEY_FILE ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

cd ~/plot-services

echo "Building listing-service image..."
sudo docker build -t listing-service:latest ./listing-service

echo ""
echo "Building inquiry-service image..."
sudo docker build -t inquiry-service:latest ./inquiry-service

echo ""
echo "✅ Docker images built"
echo ""

# Import images to K3s
echo "Importing images to K3s..."
sudo docker save listing-service:latest | sudo k3s ctr images import -
sudo docker save inquiry-service:latest | sudo k3s ctr images import -

echo "✅ Images imported to K3s"
echo ""

# List images
echo "Available images in K3s:"
sudo k3s crictl images | grep -E "listing-service|inquiry-service"

ENDSSH

echo ""
echo "Step 3.4: Deploying to Kubernetes..."
echo ""

ssh -i $KEY_FILE ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

cd ~/plot-services/k8s

# Make deploy script executable
chmod +x deploy.sh

# Deploy everything
echo "Running deployment script..."
sudo ./deploy.sh

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
sudo k3s kubectl get ingress -n plot-listing

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
echo "To check status:"
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo k3s kubectl get pods -n plot-listing'"
echo ""
echo "To view logs:"
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo k3s kubectl logs -f deployment/listing-service -n plot-listing'"
echo ""
echo "========================================="
echo "NEXT STEP: Test your application"
echo "Run: ./aws/04-test-app.sh"
echo "========================================="

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
EOF

echo ""
echo "✅ Access information saved to: app-access.txt"
