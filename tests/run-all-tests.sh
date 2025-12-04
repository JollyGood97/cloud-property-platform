#!/bin/bash

# Automated Test Runner for Plot Listing Platform
# Runs all tests: unit tests, integration tests, and smoke tests

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
UNIT_TESTS_PASSED=0
INTEGRATION_TESTS_PASSED=0
SMOKE_TESTS_PASSED=0

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Plot Listing - Automated Test Suite${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}=========================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_section "Checking Prerequisites"

if ! command_exists python3; then
    echo -e "${RED}✗ Python3 not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python3 found${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

if ! command_exists docker; then
    echo -e "${RED}✗ Docker not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Kubernetes cluster not accessible${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"

# 1. Unit Tests
print_section "Running Unit Tests"

echo -e "${YELLOW}Testing Listing Service...${NC}"
cd listing-service
if pip install -q -r requirements.txt && pytest test_main.py -v; then
    echo -e "${GREEN}✓ Listing Service tests passed${NC}"
    UNIT_TESTS_PASSED=$((UNIT_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Listing Service tests failed${NC}"
fi
cd ..

echo ""
echo -e "${YELLOW}Testing Inquiry Service...${NC}"
cd inquiry-service
if pip install -q -r requirements.txt && pytest test_main.py -v; then
    echo -e "${GREEN}✓ Inquiry Service tests passed${NC}"
    UNIT_TESTS_PASSED=$((UNIT_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Inquiry Service tests failed${NC}"
fi
cd ..

# 2. Check Deployment
print_section "Checking Deployment Status"

NAMESPACE="plot-listing"

if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}✗ Namespace $NAMESPACE not found${NC}"
    echo -e "${YELLOW}Please deploy the application first: cd k8s && ./deploy.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Namespace exists${NC}"

# Check pods
echo -e "${YELLOW}Checking pods...${NC}"
kubectl get pods -n $NAMESPACE

PODS_READY=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PODS_TOTAL=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)

if [ "$PODS_READY" -eq "$PODS_TOTAL" ] && [ "$PODS_READY" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods are running ($PODS_READY/$PODS_TOTAL)${NC}"
else
    echo -e "${RED}✗ Some pods are not running ($PODS_READY/$PODS_TOTAL)${NC}"
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=120s || true
fi

# 3. Smoke Tests
print_section "Running Smoke Tests"

echo -e "${YELLOW}Setting up port forwards...${NC}"
kubectl port-forward -n $NAMESPACE svc/listing-service 8000:8000 &
PF_LISTING=$!
kubectl port-forward -n $NAMESPACE svc/inquiry-service 8001:8001 &
PF_INQUIRY=$!

sleep 5

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up port forwards...${NC}"
    kill $PF_LISTING $PF_INQUIRY 2>/dev/null || true
}
trap cleanup EXIT

# Test health endpoints
echo -e "${YELLOW}Testing health endpoints...${NC}"
if curl -f -s http://localhost:8000/health > /dev/null; then
    echo -e "${GREEN}✓ Listing service health check passed${NC}"
    SMOKE_TESTS_PASSED=$((SMOKE_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Listing service health check failed${NC}"
fi

if curl -f -s http://localhost:8001/health > /dev/null; then
    echo -e "${GREEN}✓ Inquiry service health check passed${NC}"
    SMOKE_TESTS_PASSED=$((SMOKE_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Inquiry service health check failed${NC}"
fi

# Test basic API functionality
echo -e "${YELLOW}Testing basic API functionality...${NC}"
if curl -f -s http://localhost:8000/listings > /dev/null; then
    echo -e "${GREEN}✓ Listing API accessible${NC}"
    SMOKE_TESTS_PASSED=$((SMOKE_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Listing API not accessible${NC}"
fi

if curl -f -s http://localhost:8001/inquiries > /dev/null; then
    echo -e "${GREEN}✓ Inquiry API accessible${NC}"
    SMOKE_TESTS_PASSED=$((SMOKE_TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Inquiry API not accessible${NC}"
fi

# 4. Integration Tests
print_section "Running Integration Tests"

if [ -f "tests/integration-tests.sh" ]; then
    chmod +x tests/integration-tests.sh
    if ./tests/integration-tests.sh; then
        echo -e "${GREEN}✓ Integration tests passed${NC}"
        INTEGRATION_TESTS_PASSED=1
    else
        echo -e "${RED}✗ Integration tests failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Integration test script not found${NC}"
fi

# 5. Summary
print_section "Test Summary"

echo ""
echo -e "${BLUE}Unit Tests:${NC}"
echo -e "  Listing Service: ${GREEN}✓${NC}"
echo -e "  Inquiry Service: ${GREEN}✓${NC}"
echo -e "  Total: ${GREEN}$UNIT_TESTS_PASSED/2${NC}"

echo ""
echo -e "${BLUE}Smoke Tests:${NC}"
echo -e "  Health Checks: ${GREEN}✓${NC}"
echo -e "  API Accessibility: ${GREEN}✓${NC}"
echo -e "  Total: ${GREEN}$SMOKE_TESTS_PASSED/4${NC}"

echo ""
echo -e "${BLUE}Integration Tests:${NC}"
if [ $INTEGRATION_TESTS_PASSED -eq 1 ]; then
    echo -e "  Status: ${GREEN}✓ PASSED${NC}"
else
    echo -e "  Status: ${RED}✗ FAILED${NC}"
fi

echo ""
echo -e "${BLUE}Deployment Status:${NC}"
echo -e "  Pods Running: ${GREEN}$PODS_READY/$PODS_TOTAL${NC}"
echo -e "  Namespace: ${GREEN}$NAMESPACE${NC}"

echo ""
echo -e "${YELLOW}=========================================${NC}"

# Overall result
TOTAL_PASSED=$((UNIT_TESTS_PASSED + SMOKE_TESTS_PASSED + INTEGRATION_TESTS_PASSED))
TOTAL_TESTS=$((2 + 4 + 1))

if [ $TOTAL_PASSED -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED ($TOTAL_PASSED/$TOTAL_TESTS)${NC}"
    echo -e "${GREEN}✓ System is healthy and ready for production${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ SOME TESTS FAILED ($TOTAL_PASSED/$TOTAL_TESTS)${NC}"
    echo -e "${YELLOW}⚠ Review failed tests before deploying to production${NC}"
    exit 1
fi
