#!/bin/bash
# dthostmon Development Helper Script
# Last Updated: 11/14/2025 12:00:00 PM CDT

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Commands
cmd_test() {
    log_info "Running tests..."
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    pytest -v
}

cmd_test_coverage() {
    log_info "Running tests with coverage..."
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    pytest --cov=src/dthostmon --cov-report=html --cov-report=term-missing
    log_success "Coverage report generated: htmlcov/index.html"
}

cmd_lint() {
    log_info "Running linters..."
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    echo ""
    log_info "Running flake8..."
    flake8 src/dthostmon || true
    
    echo ""
    log_info "Running pylint..."
    pylint src/dthostmon || true
    
    echo ""
    log_info "Checking code formatting..."
    black --check src/dthostmon || true
}

cmd_format() {
    log_info "Formatting code with black..."
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    black src/dthostmon tests/
    log_success "Code formatted"
}

cmd_build() {
    log_info "Building Docker image..."
    docker compose build
    log_success "Docker image built"
}

cmd_up() {
    log_info "Starting dthostmon..."
    docker compose up -d
    log_success "dthostmon started"
    
    echo ""
    log_info "Waiting for container to be ready..."
    sleep 3
    
    docker ps | grep dthostmon
    echo ""
    log_info "View logs with: docker logs -f dthostmon"
    log_info "Access API at: http://localhost:8080/docs"
}

cmd_down() {
    log_info "Stopping dthostmon..."
    docker compose down
    log_success "dthostmon stopped"
}

cmd_logs() {
    docker logs -f dthostmon
}

cmd_shell() {
    log_info "Opening shell in dthostmon container..."
    docker exec -it dthostmon /bin/bash
}

cmd_monitor() {
    log_info "Running monitoring cycle..."
    docker exec dthostmon python3 src/dthostmon_cli.py monitor
}

cmd_config() {
    log_info "Reviewing configuration..."
    docker exec dthostmon python3 src/dthostmon_cli.py config
}

cmd_setup_hosts() {
    log_info "Testing SSH connectivity..."
    docker exec dthostmon python3 src/dthostmon_cli.py setup
}

cmd_api_test() {
    log_info "Testing API endpoints..."
    
    if [ -z "$API_KEY" ]; then
        log_warn "API_KEY environment variable not set. Using 'test_api_key'"
        API_KEY="test_api_key"
    fi
    
    echo ""
    log_info "Testing /health..."
    curl -s http://localhost:8080/health | jq || log_error "Health check failed"
    
    echo ""
    log_info "Testing /hosts (requires API key)..."
    curl -s -H "X-API-Key: $API_KEY" http://localhost:8080/hosts | jq || log_warn "API key may be incorrect"
}

cmd_clean() {
    log_warn "Cleaning up..."
    
    # Remove Python cache
    find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    
    # Remove test artifacts
    rm -rf .pytest_cache htmlcov .coverage 2>/dev/null || true
    
    # Remove build artifacts
    rm -rf build dist *.egg-info 2>/dev/null || true
    
    log_success "Cleanup complete"
}

cmd_stats() {
    echo "=== dthostmon Project Statistics ==="
    echo ""
    echo "Python Files: $(find src tests -name '*.py' | wc -l)"
    echo "Total Lines: $(find src tests -name '*.py' -exec wc -l {} + | tail -1 | awk '{print $1}')"
    echo "Documentation: $(find . -maxdepth 1 -name '*.md' | wc -l) files"
    echo "All Files: $(find . -type f ! -path './.git/*' ! -path './venv/*' | wc -l)"
    echo ""
    
    if docker ps | grep -q dthostmon; then
        echo "Container Status: ${GREEN}Running${NC}"
    else
        echo "Container Status: ${RED}Stopped${NC}"
    fi
}

cmd_help() {
    cat << EOF
dthostmon Development Helper

Usage: ./dev.sh <command>

Commands:
  test              Run all tests
  test-cov          Run tests with coverage report
  lint              Run linters (flake8, pylint, black --check)
  format            Format code with black
  
  build             Build Docker image
  up                Start Docker containers
  down              Stop Docker containers
  logs              Follow container logs
  shell             Open shell in container
  
  monitor           Run monitoring cycle
  config            Review configuration
  setup             Test SSH connectivity to hosts
  api-test          Test API endpoints
  
  clean             Clean up Python cache and test artifacts
  stats             Show project statistics
  help              Show this help message

Examples:
  ./dev.sh test-cov     # Run tests with coverage
  ./dev.sh up           # Start the application
  ./dev.sh monitor      # Run monitoring cycle
  ./dev.sh api-test     # Test API endpoints
EOF
}

# Main dispatcher
case "$1" in
    test)
        cmd_test
        ;;
    test-cov|coverage)
        cmd_test_coverage
        ;;
    lint)
        cmd_lint
        ;;
    format)
        cmd_format
        ;;
    build)
        cmd_build
        ;;
    up|start)
        cmd_up
        ;;
    down|stop)
        cmd_down
        ;;
    logs)
        cmd_logs
        ;;
    shell|bash)
        cmd_shell
        ;;
    monitor)
        cmd_monitor
        ;;
    config)
        cmd_config
        ;;
    setup)
        cmd_setup_hosts
        ;;
    api-test)
        cmd_api_test
        ;;
    clean)
        cmd_clean
        ;;
    stats)
        cmd_stats
        ;;
    help|--help|-h|"")
        cmd_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
