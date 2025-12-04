#!/bin/bash
# Test script to verify deployment

echo "🧪 Testing Plot Listing Platform..."
echo ""

# Get LoadBalancer IP
LB_IP=$(kubectl get svc plot-listing-lb -n plot-listing -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$LB_IP" ]; then
    echo "⚠️  LoadBalancer IP not ready yet. Using port-forward instead..."
    kubectl port-forward -n plot-listing svc/frontend 8080:80 &
    PF_PID=$!
    sleep 3
    BASE_URL="http://localhost:8080"
else
    BASE_URL="http://$LB_IP"
fi

echo "Testing against: $BASE_URL"
echo ""

# Test frontend
echo "1️⃣ Testing frontend..."
curl -s -o /dev/null -w "Status: %{http_code}\n" $BASE_URL/

# Test listing service
echo "2️⃣ Testing listing service - Create listing..."
curl -s -X POST $BASE_URL/api/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "TEST001",
    "title": "Test Property",
    "location": "Colombo",
    "category": "Sale",
    "price": 1000000,
    "available": true
  }' | python3 -m json.tool

echo ""
echo "3️⃣ Testing listing service - Get listings..."
curl -s $BASE_URL/api/listings | python3 -m json.tool

# Test inquiry service
echo ""
echo "4️⃣ Testing inquiry service - Create inquiry..."
curl -s -X POST $BASE_URL/api/inquiries \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "TEST001",
    "name": "Test User",
    "email": "test@example.com",
    "phone": "+94771234567",
    "message": "Test inquiry"
  }' | python3 -m json.tool

echo ""
echo "5️⃣ Testing inquiry service - Get inquiries..."
curl -s $BASE_URL/api/inquiries | python3 -m json.tool

echo ""
echo "✅ Tests complete!"

# Cleanup port-forward if used
if [ ! -z "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null
fi
