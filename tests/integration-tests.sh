#!/bin/bash

# Integration Test Suite for Plot Listing Platform
# Tests all microservices and their interactions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="plot-listing"
ENVIRONMENT="${ENVIRONMENT:-production}"

# Get service endpoint
if [ "$ENVIRONMENT" == "blue" ]; then
    LISTING_SVC="listing-service-blue"
    INQUIRY_SVC="inquiry-service-blue"
else
    LISTING_SVC="listing-service"
    INQUIRY_SVC="inquiry-service"
fi

# Port forward services for testing
echo -e "${YELLOW}Setting up port forwards...${NC}"
kubectl port-forward -n $NAMESPACE svc/$LISTING_SVC 8000:8000 &
PF_LISTING=$!
kubectl port-forward -n $NAMESPACE svc/$INQUIRY_SVC 8001:8001 &
PF_INQUIRY=$!

sleep 5

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up port forwards...${NC}"
    kill $PF_LISTING $PF_INQUIRY 2>/dev/null || true
}
trap cleanup EXIT

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Plot Listing Integration Tests${NC}"
echo -e "${YELLOW}========================================${NC}"

# Test 1: Health checks
run_test "Listing Service Health Check" \
    "curl -f -s http://localhost:8000/health > /dev/null"

run_test "Inquiry Service Health Check" \
    "curl -f -s http://localhost:8001/health > /dev/null"

# Test 2: Create listing
LISTING_RESPONSE=$(curl -s -X POST http://localhost:8000/listings \
    -H "Content-Type: application/json" \
    -d '{
        "plot_id": "TEST001",
        "title": "Test Property",
        "location": "Test City",
        "category": "Sale",
        "price": 100000,
        "available": true
    }')

run_test "Create Listing" \
    "echo '$LISTING_RESPONSE' | grep -q 'TEST001'"

# Test 3: Get all listings
run_test "Get All Listings" \
    "curl -f -s http://localhost:8000/listings | grep -q 'TEST001'"

# Test 4: Get specific listing
run_test "Get Specific Listing" \
    "curl -f -s http://localhost:8000/listings/TEST001 | grep -q 'Test Property'"

# Test 5: Update listing
UPDATE_RESPONSE=$(curl -s -X PUT http://localhost:8000/listings/TEST001 \
    -H "Content-Type: application/json" \
    -d '{
        "title": "Updated Test Property",
        "location": "Test City",
        "category": "Sale",
        "price": 150000,
        "available": true
    }')

run_test "Update Listing" \
    "echo '$UPDATE_RESPONSE' | grep -q 'Updated Test Property'"

# Test 6: Create inquiry
INQUIRY_RESPONSE=$(curl -s -X POST http://localhost:8001/inquiries \
    -H "Content-Type: application/json" \
    -d '{
        "plot_id": "TEST001",
        "name": "Test User",
        "email": "test@example.com",
        "phone": "+1234567890",
        "message": "Interested in this property"
    }')

run_test "Create Inquiry" \
    "echo '$INQUIRY_RESPONSE' | grep -q 'test@example.com'"

# Test 7: Get all inquiries
run_test "Get All Inquiries" \
    "curl -f -s http://localhost:8001/inquiries | grep -q 'TEST001'"

# Test 8: Get inquiries by plot_id
run_test "Get Inquiries by Plot ID" \
    "curl -f -s 'http://localhost:8001/inquiries?plot_id=TEST001' | grep -q 'Test User'"

# Test 9: Database persistence (restart pod and check data)
echo -e "${YELLOW}Testing database persistence...${NC}"
LISTING_POD=$(kubectl get pods -n $NAMESPACE -l app=listing-service -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $LISTING_POD -n $NAMESPACE
sleep 10

run_test "Database Persistence After Pod Restart" \
    "curl -f -s http://localhost:8000/listings/TEST001 | grep -q 'Updated Test Property'"

# Test 10: Load test (concurrent requests)
echo -e "${YELLOW}Running load test (10 concurrent requests)...${NC}"
for i in {1..10}; do
    curl -s http://localhost:8000/listings > /dev/null &
done
wait

run_test "Load Test - Concurrent Requests" \
    "curl -f -s http://localhost:8000/listings > /dev/null"

# Test 11: Delete listing
run_test "Delete Listing" \
    "curl -f -s -X DELETE http://localhost:8000/listings/TEST001 > /dev/null"

# Test 12: Verify deletion
run_test "Verify Listing Deleted" \
    "! curl -f -s http://localhost:8000/listings/TEST001 2>/dev/null"

# Summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}========================================${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
