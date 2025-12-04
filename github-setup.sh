#!/bin/bash

# GitHub Setup Script for cloud-property-platform

echo "========================================="
echo "GitHub Repository Setup"
echo "========================================="
echo ""

# Step 1: Initialize git
echo "Step 1: Initializing git repository..."
git init
git add .
git commit -m "Initial commit: Cloud Property Platform with K8s and CI/CD"

echo ""
echo "Step 2: Create GitHub repository"
echo "Go to: https://github.com/new"
echo ""
echo "Repository settings:"
echo "  Name: cloud-property-platform"
echo "  Description: Microservices platform for property management"
echo "  Visibility: PUBLIC (required for free GitHub Actions)"
echo "  DO NOT initialize with README"
echo ""
read -p "Press Enter after creating the repository..."

# Step 3: Add remote
echo ""
echo "Step 3: Adding GitHub remote..."
git remote add origin https://github.com/JollyGood97/cloud-property-platform.git
git branch -M main

echo ""
echo "Step 4: Push to GitHub..."
git push -u origin main

echo ""
echo "========================================="
echo "✅ Code pushed to GitHub!"
echo "========================================="
echo ""
echo "Next: Configure GitHub Secrets"
echo ""
echo "Go to: https://github.com/JollyGood97/cloud-property-platform/settings/secrets/actions"
echo ""
echo "Add these secrets:"
echo ""
echo "1. EC2_HOST"
echo "   Value: $(grep "Public IP:" ec2-details.txt | awk '{print $3}')"
echo ""
echo "2. EC2_SSH_KEY"
echo "   Value: (paste content of plot-listing-key.pem)"
echo "   Get it with: cat plot-listing-key.pem"
echo ""
echo "After adding secrets, push any change to trigger the pipeline:"
echo "  git commit --allow-empty -m 'Trigger CI/CD'"
echo "  git push"
echo ""
