#!/bin/bash

# Step 2: Install K3s on EC2 instance
# This script SSHs into EC2 and installs K3s

set -e

echo "========================================="
echo "Step 2: Install K3s on EC2"
echo "========================================="
echo ""

# Check if ec2-details.txt exists
if [ ! -f "ec2-details.txt" ]; then
    echo "❌ ec2-details.txt not found!"
    echo "Run ./aws/01-launch-ec2.sh first"
    exit 1
fi

# Read EC2 details
PUBLIC_IP=$(grep "Public IP:" ec2-details.txt | awk '{print $3}')
KEY_FILE="plot-listing-key.pem"

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Could not find Public IP in ec2-details.txt"
    exit 1
fi

echo "EC2 Public IP: $PUBLIC_IP"
echo "SSH Key: $KEY_FILE"
echo ""

# Wait for SSH to be ready
echo "Waiting for SSH to be ready (30 seconds)..."
sleep 30

echo "Testing SSH connection..."
if ! ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUBLIC_IP "echo 'SSH works'" &> /dev/null; then
    echo "⚠️  SSH not ready yet, waiting another 30 seconds..."
    sleep 30
fi

echo "✅ SSH connection ready"
echo ""

# Install K3s
echo "Step 2.1: Installing K3s on EC2..."
echo "This takes ~2 minutes..."
echo ""

ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -

echo ""
echo "Waiting for K3s to be ready..."
sleep 10

# Wait for K3s to be ready
sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s

echo ""
echo "✅ K3s installed successfully!"
echo ""

# Check K3s status
echo "K3s Status:"
sudo systemctl status k3s --no-pager | head -5

echo ""
echo "Kubernetes Nodes:"
sudo k3s kubectl get nodes

echo ""
echo "Kubernetes Version:"
sudo k3s kubectl version --short

ENDSSH

echo ""
echo "========================================="
echo "✅ K3s Installation Complete!"
echo "========================================="
echo ""
echo "Your K3s cluster is ready on EC2!"
echo ""
echo "To access the cluster:"
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP"
echo ""
echo "To check cluster status:"
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'sudo k3s kubectl get nodes'"
echo ""
echo "========================================="
echo "NEXT STEP: Deploy your application"
echo "Run: ./aws/03-deploy-app.sh"
echo "========================================="
