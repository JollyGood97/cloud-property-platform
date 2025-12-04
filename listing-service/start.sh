#!/bin/bash
# Quick start script for Listing Service

echo "🚀 Starting Listing Service..."
echo ""

# Run the service
uvicorn main:app --reload --host 0.0.0.0 --port 8000
