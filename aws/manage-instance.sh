#!/bin/bash

# Manage EC2 instance - Start, Stop, or Check Status

PROFILE="personal"
REGION="us-east-1"

# Check if ec2-details.txt exists
if [ ! -f "ec2-details.txt" ]; then
    echo "❌ ec2-details.txt not found!"
    exit 1
fi

# Read instance ID
INSTANCE_ID=$(grep "Instance ID:" ec2-details.txt | awk '{print $3}')

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Could not find Instance ID in ec2-details.txt"
    exit 1
fi

echo "========================================="
echo "EC2 Instance Manager"
echo "========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo ""

# Function to get instance state
get_state() {
    aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --profile $PROFILE \
        --region $REGION \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text
}

# Function to get public IP
get_ip() {
    aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --profile $PROFILE \
        --region $REGION \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text
}

# Show current status
STATE=$(get_state)
echo "Current state: $STATE"

if [ "$STATE" == "running" ]; then
    PUBLIC_IP=$(get_ip)
    echo "Public IP: $PUBLIC_IP"
fi

echo ""
echo "What would you like to do?"
echo "  1) Stop instance (save money, keep data)"
echo "  2) Start instance (resume work)"
echo "  3) Check status only"
echo "  4) Terminate instance (DELETE EVERYTHING)"
echo "  5) Exit"
echo ""

read -p "Enter choice (1-5): " CHOICE

case $CHOICE in
    1)
        if [ "$STATE" == "stopped" ]; then
            echo "Instance is already stopped"
            exit 0
        fi
        
        echo ""
        echo "Stopping instance..."
        aws ec2 stop-instances \
            --instance-ids $INSTANCE_ID \
            --profile $PROFILE \
            --region $REGION > /dev/null
        
        echo "Waiting for instance to stop..."
        aws ec2 wait instance-stopped \
            --instance-ids $INSTANCE_ID \
            --profile $PROFILE \
            --region $REGION
        
        echo ""
        echo "✅ Instance stopped!"
        echo ""
        echo "Cost while stopped: ~$0.07/day (storage only)"
        echo ""
        echo "To start again, run: ./aws/manage-instance.sh"
        ;;
    
    2)
        if [ "$STATE" == "running" ]; then
            echo "Instance is already running"
            PUBLIC_IP=$(get_ip)
            echo "Public IP: $PUBLIC_IP"
            exit 0
        fi
        
        echo ""
        echo "Starting instance..."
        aws ec2 start-instances \
            --instance-ids $INSTANCE_ID \
            --profile $PROFILE \
            --region $REGION > /dev/null
        
        echo "Waiting for instance to start..."
        aws ec2 wait instance-running \
            --instance-ids $INSTANCE_ID \
            --profile $PROFILE \
            --region $REGION
        
        # Get new public IP
        PUBLIC_IP=$(get_ip)
        
        echo ""
        echo "✅ Instance started!"
        echo ""
        echo "New Public IP: $PUBLIC_IP"
        echo ""
        echo "⚠️  IP address changed! Update your bookmarks."
        echo ""
        echo "Access your app: http://$PUBLIC_IP:30257"
        echo ""
        echo "SSH: ssh -i plot-listing-key.pem ubuntu@$PUBLIC_IP"
        
        # Update ec2-details.txt with new IP
        sed -i "s/Public IP: .*/Public IP: $PUBLIC_IP/" ec2-details.txt
        echo ""
        echo "✅ ec2-details.txt updated with new IP"
        ;;
    
    3)
        echo ""
        echo "Instance State: $STATE"
        
        if [ "$STATE" == "running" ]; then
            PUBLIC_IP=$(get_ip)
            echo "Public IP: $PUBLIC_IP"
            echo "Access: http://$PUBLIC_IP:30257"
            echo "Cost: ~$0.05/hour"
        elif [ "$STATE" == "stopped" ]; then
            echo "Cost: ~$0.07/day (storage only)"
        fi
        ;;
    
    4)
        echo ""
        echo "⚠️  WARNING: This will DELETE EVERYTHING!"
        echo "  - EC2 instance"
        echo "  - All data"
        echo "  - K3s cluster"
        echo "  - Your application"
        echo ""
        echo "This action CANNOT be undone!"
        echo ""
        read -p "Type 'DELETE' to confirm: " CONFIRM
        
        if [ "$CONFIRM" != "DELETE" ]; then
            echo "Termination cancelled"
            exit 0
        fi
        
        echo ""
        echo "Terminating instance..."
        aws ec2 terminate-instances \
            --instance-ids $INSTANCE_ID \
            --profile $PROFILE \
            --region $REGION > /dev/null
        
        echo ""
        echo "✅ Instance termination initiated"
        echo ""
        echo "The instance will be deleted in a few minutes."
        echo "You can launch a new one with: ./aws/01-launch-ec2.sh"
        ;;
    
    5)
        echo "Exiting..."
        exit 0
        ;;
    
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
