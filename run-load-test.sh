#!/bin/bash

# Load Test Runner for Family Tree Backend
# Usage: ./run-load-test.sh [light|medium|heavy]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Family Tree Backend Load Test${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}Error: k6 is not installed${NC}"
    echo ""
    echo "Please install k6:"
    echo "  Linux: sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 && echo 'deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list && sudo apt-get update && sudo apt-get install k6"
    echo "  macOS: brew install k6"
    echo "  Or visit: https://k6.io/docs/get-started/installation/"
    exit 1
fi

# Parse test intensity
INTENSITY=${1:-medium}

echo -e "${YELLOW}Test Intensity: $INTENSITY${NC}"
echo ""

case $INTENSITY in
  light)
    echo "Running light load test (max 20 VUs)..."
    k6 run --vus 10 --duration 2m load-test.js
    ;;
  medium)
    echo "Running medium load test (max 50 VUs)..."
    k6 run load-test.js
    ;;
  heavy)
    echo "Running heavy load test (max 200 VUs)..."
    k6 run --stage 1m:20,3m:50,1m:100,3m:100,1m:200,2m:200,1m:0 load-test.js
    ;;
  *)
    echo -e "${RED}Invalid intensity: $INTENSITY${NC}"
    echo "Usage: ./run-load-test.sh [light|medium|heavy]"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Load test completed!${NC}"
echo -e "${YELLOW}Check load-test-summary.json for detailed results${NC}"
