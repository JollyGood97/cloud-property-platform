#!/bin/bash

# Script to set up CI/CD pipeline for Plot Listing Platform
# This script helps configure GitHub Actions and secrets

set -e

echo "========================================="
echo "Plot Listing CI/CD Setup"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI not found. Install from: https://cli.github.com/${NC}"
    echo "Continuing with manual instructions..."
    MANUAL_MODE=true
else
    MANUAL_MODE=false
fi

# Get kubeconfig
echo -e "${YELLOW}Step 1: Encoding kubeconfig...${NC}"
KUBECONFIG_BASE64=$(cat ~/.kube/config | base64 -w 0)
echo -e "${GREEN}✓ Kubeconfig encoded${NC}"

# Set GitHub secrets
if [ "$MANUAL_MODE" = false ]; then
    echo -e "${YELLOW}Step 2: Setting GitHub secrets...${NC}"
    
    # Check if logged in
    if ! gh auth status &> /dev/null; then
        echo "Please login to GitHub CLI:"
        gh auth login
    fi
    
    # Set secrets
    echo "$KUBECONFIG_BASE64" | gh secret set KUBECONFIG
    echo -e "${GREEN}✓ KUBECONFIG secret set${NC}"
    
else
    echo -e "${YELLOW}Step 2: Manual secret setup required${NC}"
    echo ""
    echo "Go to your GitHub repository:"
    echo "Settings → Secrets and variables → Actions → New repository secret"
    echo ""
    echo "Add the following secret:"
    echo "Name: KUBECONFIG"
    echo "Value: (copy the base64 string below)"
    echo ""
    echo "---BEGIN KUBECONFIG BASE64---"
    echo "$KUBECONFIG_BASE64"
    echo "---END KUBECONFIG BASE64---"
    echo ""
    read -p "Press Enter after adding the secret..."
fi

# Enable GitHub Container Registry
echo -e "${YELLOW}Step 3: GitHub Container Registry setup${NC}"
echo ""
echo "To use GitHub Container Registry (ghcr.io):"
echo "1. Go to GitHub Settings → Developer settings → Personal access tokens"
echo "2. Generate a token with 'write:packages' scope"
echo "3. The CI/CD pipeline will automatically use GITHUB_TOKEN"
echo ""
echo -e "${GREEN}✓ Instructions provided${NC}"

# Update image references
echo -e "${YELLOW}Step 4: Update image references${NC}"
echo ""
read -p "Enter your GitHub username: " GITHUB_USER

# Update blue-green manifests
sed -i "s|ghcr.io/your-username|ghcr.io/$GITHUB_USER|g" k8s/blue-green/*.yaml
echo -e "${GREEN}✓ Updated image references in k8s/blue-green/*.yaml${NC}"

# Create GitHub Actions workflow directory if not exists
mkdir -p .github/workflows

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}CI/CD Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Commit and push your changes:"
echo "   git add ."
echo "   git commit -m 'Add CI/CD pipeline'"
echo "   git push origin main"
echo ""
echo "2. The pipeline will automatically:"
echo "   - Run tests on every push"
echo "   - Build Docker images"
echo "   - Deploy to Blue environment"
echo "   - Run integration tests"
echo "   - Switch traffic to Blue"
echo "   - Update Green environment"
echo ""
echo "3. Monitor the pipeline:"
echo "   GitHub → Actions tab"
echo ""
echo "4. Manual deployment (if needed):"
echo "   ./scripts/manual-deploy.sh"
echo ""
