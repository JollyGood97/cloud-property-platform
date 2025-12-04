#!/bin/bash

# Fix security group to allow NodePort access

PROFILE="personal"
REGION="us-east-1"

# Get security group ID from ec2-details.txt
if [ ! -f "ec2-details.txt" ]; then
    echo "❌ ec2-details.txt not found!"
    exit 1
fi

INSTANCE_ID=$(grep "Instance ID:" ec2-details.txt | awk '{print $3}')

# Get security group ID
SG_ID=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --profile $PROFILE \
    --region $REGION \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group: $SG_ID"
echo ""
echo "Current rules:"
aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --profile $PROFILE \
    --region $REGION \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort]' \
    --output table

echo ""
echo "NodePort range (30000-32767) should be open."
echo "If not, adding it now..."

# Try to add NodePort range (will fail if already exists, which is fine)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 30000-32767 \
    --cidr 0.0.0.0/0 \
    --profile $PROFILE \
    --region $REGION 2>/dev/null && echo "✅ NodePort range added" || echo "✅ NodePort range already exists"

echo ""
echo "Security group updated!"
