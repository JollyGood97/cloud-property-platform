#!/bin/bash

# Recover SSH key from AWS EC2
# This creates a NEW key pair and updates the instance

echo "========================================="
echo "SSH Key Recovery"
echo "========================================="
echo ""
echo "Unfortunately, AWS doesn't allow downloading existing keys."
echo "We need to create a NEW key and add it to the instance."
echo ""
echo "Option 1: Create new key pair (requires instance restart)"
echo "Option 2: Use AWS Systems Manager (no key needed)"
echo ""
read -p "Choose option (1 or 2): " OPTION

if [ "$OPTION" == "1" ]; then
    echo ""
    echo "Creating new key pair..."
    
    # Delete old key pair
    aws ec2 delete-key-pair --key-name plot-listing-key --profile personal --region us-east-1 2>/dev/null
    
    # Create new key pair
    aws ec2 create-key-pair \
        --key-name plot-listing-key-new \
        --profile personal \
        --region us-east-1 \
        --query 'KeyMaterial' \
        --output text > plot-listing-key-new.pem
    
    chmod 400 plot-listing-key-new.pem
    
    echo "✅ New key created: plot-listing-key-new.pem"
    echo ""
    echo "⚠️  IMPORTANT: You need to add this key to your EC2 instance."
    echo "This requires either:"
    echo "  1. AWS Systems Manager access"
    echo "  2. Creating a new instance"
    echo ""
    echo "For now, use this key for NEW instances."
    
elif [ "$OPTION" == "2" ]; then
    echo ""
    echo "Installing AWS Systems Manager plugin..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
        sudo dpkg -i session-manager-plugin.deb
    else
        echo "Please install manually from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    fi
    
    echo ""
    echo "Connect with:"
    echo "aws ssm start-session --target i-006a81563f1261dc7 --profile personal --region us-east-1"
fi
