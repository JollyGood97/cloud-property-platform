#!/bin/bash
# Quick API test script

echo "🧪 Testing Listing Service API..."
echo ""

# Start the service in background
echo "Starting service..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
SERVICE_PID=$!

# Wait for service to start
sleep 3

echo ""
echo "1️⃣ Testing Health Check..."
curl -s http://localhost:8000/health | python3 -m json.tool
echo ""

echo "2️⃣ Creating a listing..."
curl -s -X POST http://localhost:8000/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT001",
    "title": "Luxury Villa in Colombo",
    "location": "Colombo 07",
    "category": "Sale",
    "price": 50000000,
    "available": true
  }' | python3 -m json.tool
echo ""

echo "3️⃣ Getting all listings..."
curl -s http://localhost:8000/listings | python3 -m json.tool
echo ""

echo "4️⃣ Creating another listing..."
curl -s -X POST http://localhost:8000/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT002",
    "title": "Beach House in Galle",
    "location": "Galle",
    "category": "Rent",
    "price": 150000,
    "available": true
  }' | python3 -m json.tool
echo ""

echo "5️⃣ Getting all listings again..."
curl -s http://localhost:8000/listings | python3 -m json.tool
echo ""

echo "✅ Tests complete!"
echo ""
echo "📖 View API docs at: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop the service"

# Keep service running
wait $SERVICE_PID
