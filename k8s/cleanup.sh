#!/bin/bash
# Cleanup script - removes all resources

echo "🗑️  Cleaning up Plot Listing deployment..."

kubectl delete namespace plot-listing

echo "✅ Cleanup complete!"
echo ""
echo "To redeploy, run: ./deploy.sh"
