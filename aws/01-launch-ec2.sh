#!/bin/bash

# Step 1: Launch EC2 instance for K3s deployment
# This script creates a t2.medium instance with proper security group

set -e

PROFILE="personal"
REGION="us-east-1"  # Change if you prefer different region
KEY_NAME="plot-listing-key"
INSTANCE_NAME="plot-listing-k3s"

echo "========================================="
echo "Step 1: Launch EC2 Instance for K3s"
echo "========================================="
echo ""

# Check if AWS CLI is configured
echo "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
    echo "❌ AWS CLI not configured for profile: $PROFILE"
    echo "Run: aws configure --profile $PROFILE"
    exit 1
fi
echo "✅ AWS CLI configured"
echo ""

# Create key pair if it doesn't exist
echo "Step 1.1: Creating SSH key pair..."
if aws ec2 describe-key-pairs --key-names $KEY_NAME --profile $PROFILE --region $REGION &> /dev/null; then
    echo "⚠️  Key pair '$KEY_NAME' already exists"
    echo "Using existing key. Make sure you have the .pem file!"
else
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --profile $PROFILE \
        --region $REGION \
        --query 'KeyMaterial' \
        --output text > ${KEY_NAME}.pem
    
    chmod 400 ${KEY_NAME}.pem
    echo "✅ Key pair created: ${KEY_NAME}.pem"
    echo "⚠️  IMPORTANT: Save this file! You need it to SSH into EC2"
fi
echo ""

# Create security group
echo "Step 1.2: Creating security group..."
SG_NAME="plot-listing-sg"

# Check if security group exists
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --profile $PROFILE \
    --region $REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    # Get default VPC
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=isDefault,Values=true" \
        --profile $PROFILE \
        --region $REGION \
        --query 'Vpcs[0].VpcId' \
        --output text)
    
    # Create security group
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Security group for Plot Listing K3s cluster" \
        --vpc-id $VPC_ID \
        --profile $PROFILE \
        --region $REGION \
        --query 'GroupId' \
        --output text)
    
    echo "✅ Security group created: $SG_ID"
    
    # Add rules
    echo "Adding security group rules..."
    
    # SSH
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --profile $PROFILE \
        --region $REGION
    
    # HTTP
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --profile $PROFILE \
        --region $REGION
    
    # HTTPS
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --profile $PROFILE \
        --region $REGION
    
    # K3s API
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 6443 \
        --cidr 0.0.0.0/0 \
        --profile $PROFILE \
        --region $REGION
    
    # NodePort range
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 30000-32767 \
        --cidr 0.0.0.0/0 \
        --profile $PROFILE \
        --region $REGION
    
    echo "✅ Security group rules added"
else
    echo "✅ Using existing security group: $SG_ID"
fi
echo ""

# Get latest Ubuntu 22.04 AMI
echo "Step 1.3: Finding Ubuntu 22.04 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --profile $PROFILE \
    --region $REGION \
    --output text)

echo "✅ Using AMI: $AMI_ID"
echo ""

# Launch instance
echo "Step 1.4: Launching EC2 instance..."
echo "Instance type: t2.medium (2 vCPU, 4GB RAM)"
echo "This will cost ~$0.05/hour"
echo ""

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.medium \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3}' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --profile $PROFILE \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Instance launched: $INSTANCE_ID"
echo ""

# Wait for instance to be running
echo "Waiting for instance to start (this takes ~30 seconds)..."
aws ec2 wait instance-running \
    --instance-ids $INSTANCE_ID \
    --profile $PROFILE \
    --region $REGION

echo "✅ Instance is running!"
echo ""

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --profile $PROFILE \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "========================================="
echo "✅ EC2 Instance Ready!"
echo "========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "SSH Key: ${KEY_NAME}.pem"
echo ""
echo "Save these details! You'll need them."
echo ""
echo "To SSH into the instance:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo ""
echo "To stop the instance (to save money):"
echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION"
echo ""
echo "To start the instance again:"
echo "  aws ec2 start-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION"
echo ""
echo "To terminate (delete) the instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION"
echo ""

# Save details to file
cat > ec2-details.txt << EOF
EC2 Instance Details
====================
Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
Region: $REGION
SSH Key: ${KEY_NAME}.pem
Security Group: $SG_ID

SSH Command:
ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}

Stop Instance:
aws ec2 stop-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION

Start Instance:
aws ec2 start-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION

Get New IP (after restart):
aws ec2 describe-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
EOF

echo "✅ Details saved to: ec2-details.txt"
echo ""
echo "========================================="
echo "NEXT STEP: Wait 1 minute for instance to fully initialize"
echo "Then run: ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo "========================================="
