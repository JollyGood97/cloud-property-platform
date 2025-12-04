#!/bin/bash
# Quick API test script for Inquiry Service

echo "🧪 Testing Inquiry Service API..."
echo ""

# Start the service in background
echo "Starting service..."
uvicorn main:app --host 0.0.0.0 --port 8001 &
SERVICE_PID=$!

# Wait for service to start
sleep 3

echo ""
echo "1️⃣ Testing Health Check..."
curl -s http://localhost:8001/health | python3 -m json.tool
echo ""

echo "2️⃣ Creating an inquiry..."
curl -s -X POST http://localhost:8001/inquiries \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT001",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+94771234567",
    "message": "I am interested in this luxury villa. Please contact me."
  }' | python3 -m json.tool
echo ""

echo "3️⃣ Getting all inquiries..."
curl -s http://localhost:8001/inquiries | python3 -m json.tool
echo ""

echo "4️⃣ Creating another inquiry..."
curl -s -X POST http://localhost:8001/inquiries \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT002",
    "name": "Jane Smith",
    "email": "jane@example.com",
    "phone": "+94771234568",
    "message": "What is the rental price for this beach house?"
  }' | python3 -m json.tool
echo ""

echo "5️⃣ Getting all inquiries again..."
curl -s http://localhost:8001/inquiries | python3 -m json.tool
echo ""

echo "6️⃣ Filter inquiries for PLOT001..."
curl -s "http://localhost:8001/inquiries?plot_id=PLOT001" | python3 -m json.tool
echo ""

echo "✅ Tests complete!"
echo ""
echo "📖 View API docs at: http://localhost:8001/docs"
echo ""
echo "Press Ctrl+C to stop the service"

# Keep service running
wait $SERVICE_PID
