#!/bin/bash
# dthostmon Interactive Setup Script
# Last Updated: 1/16/2025 1:00:00 PM CST
#
# Implements FR-INIT-001: Interactive setup with logging, step validation, and user prompts

# Source logging utilities if available (from divtools)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../scripts/util/logging.sh" ]; then
    source "$SCRIPT_DIR/../../scripts/util/logging.sh"
else
    # Fallback logging functions if not in divtools environment
    log() {
        local level="$1"
        local message="$2"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message"
    }
fi

# Setup logging to file
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="logs/setup_${TIMESTAMP}.log"
mkdir -p logs

# Log both to console and file
log_dual() {
    local level="$1"
    local message="$2"
    log "$level" "$message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status tracking
STEPS_COMPLETED=()
STEPS_SKIPPED=()
STEPS_FAILED=()

# Flag for non-interactive mode
NON_INTERACTIVE=0
AUTO_YES=0

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive|-n)
            NON_INTERACTIVE=1
            shift
            ;;
        --yes|-y)
            AUTO_YES=1
            shift
            ;;
        --dev)
            DEV_MODE=1
            shift
            ;;
        --help|-h)
            echo "dthostmon Setup Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --non-interactive, -n    Run without prompting (uses defaults)"
            echo "  --yes, -y               Answer 'yes' to all prompts"
            echo "  --dev                   Setup development environment"
            echo "  --help, -h              Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Display header
echo ""
echo "=========================================="
echo "  dthostmon Interactive Setup"
echo "=========================================="
echo ""
log_dual "INFO" "Setup started - Log file: $LOG_FILE"

# Check if running from correct directory
check_project_directory() {
    log_dual "INFO" "Step: Checking project directory"
    
    if [ ! -f "dca-dthostmon.yml" ]; then
        log_dual "ERROR" "Must run from dthostmon project directory"
        log_dual "ERROR" "Expected file 'dca-dthostmon.yml' not found"
        exit 1
    fi
    
    log_dual "INFO" "✓ Running from correct directory: $SCRIPT_DIR"
    STEPS_COMPLETED+=("Project Directory Check")
}

# Ask user for confirmation
ask_user() {
    local prompt="$1"
    local default="${2:-Y}"
    
    # Non-interactive mode
    if [ $NON_INTERACTIVE -eq 1 ] || [ $AUTO_YES -eq 1 ]; then
        echo "$prompt [default: $default]"
        log_dual "INFO" "Auto-answering: $default (non-interactive mode)"
        return 0
    fi
    
    # Interactive prompt
    if [ "$default" = "Y" ]; then
        read -p "$prompt [Y/n]: " response
        response=${response:-Y}
    else
        read -p "$prompt [y/N]: " response
        response=${response:-N}
    fi
    
    log_dual "INFO" "User response: $response"
    
    case "$response" in
        [Yy]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check system prerequisites
check_prerequisites() {
    log_dual "INFO" "Step: Checking system prerequisites"
    
    local all_ok=1
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_dual "INFO" "✓ Docker installed: $docker_version"
    else
        log_dual "ERROR" "✗ Docker not found - please install Docker first"
        all_ok=0
    fi
    
    # Check docker compose (plugin or standalone)
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        log_dual "INFO" "✓ Docker Compose plugin installed: $compose_version"
    elif command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        log_dual "WARN" "⚠ Using legacy docker-compose: $compose_version"
        log_dual "INFO" "  Consider upgrading to Docker Compose V2 plugin"
    else
        log_dual "ERROR" "✗ Docker Compose not found"
        all_ok=0
    fi
    
    # Check Python 3 (for dev mode)
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version | awk '{print $2}')
        log_dual "INFO" "✓ Python 3 installed: $python_version"
    else
        log_dual "WARN" "⚠ Python 3 not found (needed for dev mode only)"
    fi
    
    if [ $all_ok -eq 1 ]; then
        STEPS_COMPLETED+=("Prerequisites Check")
        return 0
    else
        STEPS_FAILED+=("Prerequisites Check")
        return 1
    fi
}

# Setup environment file
setup_env_file() {
    log_dual "INFO" "Step: Setting up environment file (.env)"
    
    if [ -f ".env" ]; then
        log_dual "INFO" "✓ .env file already exists"
        
        if ask_user "Do you want to recreate .env from template?" "N"; then
            log_dual "INFO" "Backing up existing .env to .env.backup.$TIMESTAMP"
            cp .env ".env.backup.$TIMESTAMP"
            cp .env.example .env
            log_dual "INFO" "✓ Recreated .env from template"
        else
            log_dual "INFO" "Keeping existing .env file"
        fi
    else
        if ask_user "Create .env file from template?" "Y"; then
            cp .env.example .env
            log_dual "INFO" "✓ Created .env file from template"
        else
            log_dual "WARN" "Skipped .env creation - you'll need to create it manually"
            STEPS_SKIPPED+=("Environment File")
            return 0
        fi
    fi
    
    echo ""
    log_dual "WARN" "⚠ IMPORTANT: Edit .env with your actual credentials!"
    echo -e "${YELLOW}   Required variables:${NC}"
    echo "   - DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD"
    echo "   - SMTP_HOST, SMTP_PORT, SMTP_FROM"
    echo "   - SSH_KEY_PATH"
    echo ""
    
    STEPS_COMPLETED+=("Environment File")
}

# Setup configuration file
setup_config_file() {
    log_dual "INFO" "Step: Setting up configuration file"
    
    if [ -f "config/dthostmon.yaml" ]; then
        log_dual "INFO" "✓ config/dthostmon.yaml already exists"
        
        if ask_user "Do you want to recreate config from example?" "N"; then
            log_dual "INFO" "Backing up existing config to config/dthostmon.yaml.backup.$TIMESTAMP"
            cp config/dthostmon.yaml "config/dthostmon.yaml.backup.$TIMESTAMP"
            cp config/dthostmon.yaml.example config/dthostmon.yaml
            log_dual "INFO" "✓ Recreated config from example"
        else
            log_dual "INFO" "Keeping existing configuration"
        fi
    else
        if ask_user "Create config/dthostmon.yaml from example?" "Y"; then
            cp config/dthostmon.yaml.example config/dthostmon.yaml
            log_dual "INFO" "✓ Created config/dthostmon.yaml from example"
        else
            log_dual "WARN" "Skipped config creation - you'll need to create it manually"
            STEPS_SKIPPED+=("Configuration File")
            return 0
        fi
    fi
    
    echo ""
    log_dual "WARN" "⚠ IMPORTANT: Edit config/dthostmon.yaml with your hosts!"
    echo ""
    
    STEPS_COMPLETED+=("Configuration File")
}

# Create necessary directories
create_directories() {
    log_dual "INFO" "Step: Creating necessary directories"
    
    local dirs=("logs" "logs/monitoring" "logs/setup")
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_dual "INFO" "✓ Directory exists: $dir"
        else
            mkdir -p "$dir"
            log_dual "INFO" "✓ Created directory: $dir"
        fi
    done
    
    STEPS_COMPLETED+=("Directory Creation")
}

# Check SSH key
check_ssh_key() {
    log_dual "INFO" "Step: Checking SSH key configuration"
    
    local ssh_key_path="${SSH_KEY_PATH:-~/.ssh/id_ed25519}"
    ssh_key_path="${ssh_key_path/#\~/$HOME}"
    
    if [ -f "$ssh_key_path" ]; then
        log_dual "INFO" "✓ SSH key found: $ssh_key_path"
        
        # Check if key has passphrase
        if ssh-keygen -y -f "$ssh_key_path" &>/dev/null; then
            log_dual "INFO" "✓ SSH key is accessible (no passphrase or agent configured)"
        else
            log_dual "WARN" "⚠ SSH key may require passphrase - ensure ssh-agent is configured"
        fi
    else
        log_dual "WARN" "⚠ SSH key not found at: $ssh_key_path"
        
        if ask_user "Do you want to generate an SSH key now?" "N"; then
            ssh-keygen -t ed25519 -f "$ssh_key_path" -C "dthostmon@$(hostname)"
            log_dual "INFO" "✓ Generated SSH key: $ssh_key_path"
            echo ""
            log_dual "WARN" "⚠ Copy public key to monitored hosts:"
            echo "   ssh-copy-id -i ${ssh_key_path}.pub user@host"
            echo ""
        else
            log_dual "WARN" "Skipped SSH key generation"
        fi
    fi
    
    STEPS_COMPLETED+=("SSH Key Check")
}

# Create Docker Compose symlink
create_compose_symlink() {
    log_dual "INFO" "Step: Creating docker-compose.yml symlink"
    
    if [ -L "docker-compose.yml" ]; then
        log_dual "INFO" "✓ Symlink already exists: docker-compose.yml -> $(readlink docker-compose.yml)"
    elif [ -f "docker-compose.yml" ]; then
        log_dual "WARN" "⚠ docker-compose.yml exists as a regular file"
        
        if ask_user "Replace it with symlink to dca-dthostmon.yml?" "Y"; then
            rm docker-compose.yml
            ln -s dca-dthostmon.yml docker-compose.yml
            log_dual "INFO" "✓ Created symlink: docker-compose.yml -> dca-dthostmon.yml"
        else
            log_dual "INFO" "Keeping existing docker-compose.yml file"
        fi
    else
        ln -s dca-dthostmon.yml docker-compose.yml
        log_dual "INFO" "✓ Created symlink: docker-compose.yml -> dca-dthostmon.yml"
    fi
    
    STEPS_COMPLETED+=("Docker Compose Symlink")
}

# Build Docker image
build_docker_image() {
    log_dual "INFO" "Step: Building Docker image"
    
    if ask_user "Build Docker image now?" "Y"; then
        log_dual "INFO" "Building Docker image... (this may take a few minutes)"
        
        if docker compose build 2>&1 | tee -a "$LOG_FILE"; then
            log_dual "INFO" "✓ Docker image built successfully"
            STEPS_COMPLETED+=("Docker Image Build")
        else
            log_dual "ERROR" "✗ Docker image build failed - check log file"
            STEPS_FAILED+=("Docker Image Build")
            return 1
        fi
    else
        log_dual "INFO" "Skipped Docker image build"
        STEPS_SKIPPED+=("Docker Image Build")
    fi
}

# Initialize database
initialize_database() {
    log_dual "INFO" "Step: Database initialization"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "dthostmon"; then
        log_dual "WARN" "⚠ Container not running - skipping database initialization"
        log_dual "INFO" "  Run 'docker compose up -d' first, then:"
        log_dual "INFO" "  docker compose exec dthostmon alembic upgrade head"
        STEPS_SKIPPED+=("Database Initialization")
        return 0
    fi
    
    if ask_user "Initialize/migrate database schema?" "Y"; then
        log_dual "INFO" "Running database migrations..."
        
        if docker compose exec -T dthostmon alembic upgrade head 2>&1 | tee -a "$LOG_FILE"; then
            log_dual "INFO" "✓ Database initialized/migrated successfully"
            STEPS_COMPLETED+=("Database Initialization")
        else
            log_dual "ERROR" "✗ Database initialization failed - check log file"
            STEPS_FAILED+=("Database Initialization")
            return 1
        fi
    else
        log_dual "INFO" "Skipped database initialization"
        STEPS_SKIPPED+=("Database Initialization")
    fi
}

# Setup development environment
setup_dev_environment() {
    if [ -z "$DEV_MODE" ]; then
        return 0
    fi
    
    log_dual "INFO" "Step: Setting up development environment"
    
    if [ -d "venv" ]; then
        log_dual "INFO" "✓ Virtual environment already exists"
        
        if ask_user "Recreate virtual environment?" "N"; then
            rm -rf venv
            python3 -m venv venv
            log_dual "INFO" "✓ Recreated virtual environment"
        fi
    else
        if ask_user "Create Python virtual environment for development?" "Y"; then
            python3 -m venv venv
            log_dual "INFO" "✓ Created virtual environment"
        else
            log_dual "INFO" "Skipped virtual environment creation"
            STEPS_SKIPPED+=("Development Environment")
            return 0
        fi
    fi
    
    # Install dependencies
    if ask_user "Install development dependencies?" "Y"; then
        log_dual "INFO" "Installing dependencies..."
        source venv/bin/activate
        pip install -r requirements-dev.txt 2>&1 | tee -a "$LOG_FILE"
        log_dual "INFO" "✓ Installed development dependencies"
    fi
    
    STEPS_COMPLETED+=("Development Environment")
}

# Display summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "  Setup Summary"
    echo "=========================================="
    echo ""
    
    if [ ${#STEPS_COMPLETED[@]} -gt 0 ]; then
        echo -e "${GREEN}Completed Steps:${NC}"
        for step in "${STEPS_COMPLETED[@]}"; do
            echo "  ✓ $step"
        done
        echo ""
    fi
    
    if [ ${#STEPS_SKIPPED[@]} -gt 0 ]; then
        echo -e "${YELLOW}Skipped Steps:${NC}"
        for step in "${STEPS_SKIPPED[@]}"; do
            echo "  ⊘ $step"
        done
        echo ""
    fi
    
    if [ ${#STEPS_FAILED[@]} -gt 0 ]; then
        echo -e "${RED}Failed Steps:${NC}"
        for step in "${STEPS_FAILED[@]}"; do
            echo "  ✗ $step"
        done
        echo ""
    fi
    
    log_dual "INFO" "Setup log saved to: $LOG_FILE"
}

# Display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "  Next Steps"
    echo "=========================================="
    echo ""
    echo "1. Edit configuration files:"
    echo "   nano .env"
    echo "   nano config/dthostmon.yaml"
    echo ""
    echo "2. Start the container:"
    echo "   docker compose up -d"
    echo ""
    echo "3. View logs:"
    echo "   docker compose logs -f"
    echo ""
    echo "4. Run database migration (if not done):"
    echo "   docker compose exec dthostmon alembic upgrade head"
    echo ""
    echo "5. Test SSH connectivity:"
    echo "   docker compose exec dthostmon python3 src/dthostmon_cli.py setup"
    echo ""
    echo "6. Run test monitoring cycle:"
    echo "   docker compose exec dthostmon python3 src/dthostmon_cli.py monitor"
    echo ""
    echo "7. Run tests:"
    echo "   cd tests && ./testmenu.sh"
    echo ""
    echo "For more information, see README.md"
    echo ""
}

# Main setup flow
main() {
    # Trap Ctrl+C
    trap 'echo ""; log_dual "WARN" "Setup cancelled by user"; display_summary; exit 130' INT
    
    check_project_directory
    
    echo ""
    if ! ask_user "Begin dthostmon setup?" "Y"; then
        log_dual "INFO" "Setup cancelled by user"
        exit 0
    fi
    
    echo ""
    check_prerequisites || exit 1
    
    echo ""
    setup_env_file
    
    echo ""
    setup_config_file
    
    echo ""
    create_directories
    
    echo ""
    check_ssh_key
    
    echo ""
    create_compose_symlink
    
    echo ""
    build_docker_image
    
    echo ""
    initialize_database
    
    if [ -n "$DEV_MODE" ]; then
        echo ""
        setup_dev_environment
    fi
    
    display_summary
    display_next_steps
    
    log_dual "INFO" "Setup completed successfully"
}

# Run main setup
main
