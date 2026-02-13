#!/bin/bash
# Run pytest test suite for Home Assistant scripts
# Last Updated: 11/25/2025 1:36:00 PM CST

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Home Assistant Scripts Test Suite${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo -e "${YELLOW}pytest not found. Installing test dependencies...${NC}"
    pip install -r test/requirements.txt
fi

# Parse arguments
COVERAGE=1
VERBOSE=""
SPECIFIC_TEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-coverage)
            COVERAGE=0
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -vv)
            VERBOSE="-vv"
            shift
            ;;
        -s|--show-output)
            VERBOSE="$VERBOSE -s"
            shift
            ;;
        *)
            SPECIFIC_TEST="$1"
            shift
            ;;
    esac
done

# Build pytest command
PYTEST_CMD="pytest"

if [ -n "$VERBOSE" ]; then
    PYTEST_CMD="$PYTEST_CMD $VERBOSE"
fi

if [ $COVERAGE -eq 1 ]; then
    PYTEST_CMD="$PYTEST_CMD --cov=hass_util --cov=gen_presence_sensors --cov-report=term-missing --cov-report=html:test/htmlcov"
fi

if [ -n "$SPECIFIC_TEST" ]; then
    PYTEST_CMD="$PYTEST_CMD $SPECIFIC_TEST"
fi

echo -e "${BLUE}Running:${NC} $PYTEST_CMD\n"

# Run tests
if $PYTEST_CMD; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    
    if [ $COVERAGE -eq 1 ]; then
        echo -e "${BLUE}Coverage report generated: test/htmlcov/index.html${NC}"
    fi
    
    exit 0
else
    echo -e "\n${RED}✗ Tests failed${NC}"
    exit 1
fi
