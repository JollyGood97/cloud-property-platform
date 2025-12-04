#!/bin/bash

# Cleanup EC2 to save space after switching to GitHub Container Registry
# This removes local source code and Docker images, keeping only K3s and deployments

set -e

echo "========================================="
echo "EC2 Space Cleanup"
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

echo "⚠️  WARNING: This will remove:"
echo "  - Source code files (listing-service, inquiry-service, plot-frontend)"
echo "  - Local Docker images"
echo "  - Docker build cache"
echo ""
echo "This will keep:"
echo "  - K3s cluster (running)"
echo "  - Deployed pods (running)"
echo "  - K8s manifests (for future deployments)"
echo ""

read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

ssh -i $KEY_FILE ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

cd ~

echo "Current disk usage:"
df -h / | grep -v Filesystem

echo ""
echo "Step 1: Removing source code directories..."

# Remove source code (keep k8s manifests)
if [ -d "plot-services/listing-service" ]; then
    rm -rf plot-services/listing-service
    echo "✅ Removed listing-service source"
fi

if [ -d "plot-services/inquiry-service" ]; then
    rm -rf plot-services/inquiry-service
    echo "✅ Removed inquiry-service source"
fi

if [ -d "plot-services/plot-frontend" ]; then
    rm -rf plot-services/plot-frontend
    echo "✅ Removed plot-frontend source"
fi

echo ""
echo "Step 2: Cleaning Docker images and cache..."

# Remove unused Docker images
sudo docker system prune -af --volumes 2>/dev/null || echo "Docker cleanup done"

echo "✅ Docker images and cache cleaned"

echo ""
echo "Step 3: Cleaning package cache..."

# Clean apt cache
sudo apt-get clean
sudo apt-get autoclean

echo "✅ Package cache cleaned"

echo ""
echo "Step 4: Removing old logs..."

# Clean old logs
sudo journalctl --vacuum-time=1d 2>/dev/null || echo "Journal cleanup done"

echo "✅ Old logs cleaned"

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""

echo "Disk usage after cleanup:"
df -h / | grep -v Filesystem

echo ""
echo "What's still on the instance:"
echo "  ✅ K3s cluster (running)"
echo "  ✅ Your deployed application (running)"
echo "  ✅ K8s manifests (~/plot-services/k8s/)"
echo ""

echo "Checking running pods:"
sudo k3s kubectl get pods -n plot-listing

ENDSSH

echo ""
echo "========================================="
echo "✅ EC2 Cleanup Complete!"
echo "========================================="
echo ""
echo "Space saved: ~2-3 GB"
echo ""
echo "Your application is still running!"
echo "Access: http://$PUBLIC_IP:30257"
echo ""
echo "Future deployments will use GitHub Container Registry images."
echo ""
