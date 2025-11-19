# Docker Development Best Practices

**Last Updated:** November 16, 2025

**Project:** dthostmon (DivTools Host Monitor)

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Development Environment Setup](#development-environment-setup)
3. [Container Development Best Practices](#container-development-best-practices)
4. [Language & Framework Considerations](#language--framework-considerations)
5. [Database Management](#database-management)
6. [Development Tools & Platforms](#development-tools--platforms)
7. [Testing Strategies](#testing-strategies)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Production Deployment](#production-deployment)
10. [AI-Assisted Development](#ai-assisted-development)
11. [dthostmon Specific Recommendations](#dthostmon-specific-recommendations)

---

## Executive Summary

This document outlines industry-standard best practices for developing containerized applications, specifically tailored for the **dthostmon** project. It covers development environments (Windows 10/11, WSL2, Ubuntu), container orchestration (Docker, K3s), language frameworks (Python, Node.js, React), and AI-assisted development workflows.

### Key Technologies in Scope
- **Languages:** Python 3.11+, JavaScript (Node.js), TypeScript, React.js
- **Containerization:** Docker, Docker Compose, Kubernetes (K3s)
- **Development OS:** Windows 10/11 with WSL2, Ubuntu LXC/VMs on Proxmox
- **Databases:** PostgreSQL, SQLite
- **Web Frameworks:** FastAPI (Python), Express.js (Node.js), React.js (Frontend)
- **TUI Frameworks:** Rich, Textual, Blessed, Ink (for terminal UIs)
- **AI Tools:** GitHub Copilot, Claude, GPT-4, OpenCode Server

---

## Development Environment Setup

### 1.1 Windows 10/11 with WSL2 (Primary Development)

**Why WSL2 for Docker Development?**
- Native Linux kernel provides better performance than Docker Desktop on Windows
- Seamless integration with VS Code via Remote-WSL extension
- Access to Linux tools and package managers (apt, snap)
- Direct filesystem access without performance penalties
- Better compatibility with shell scripts and Unix tools

**Recommended WSL2 Setup:**

```bash
# Install WSL2 Ubuntu 22.04 LTS
wsl --install -d Ubuntu-22.04

# Update WSL2 kernel
wsl --update

# Set default WSL version
wsl --set-default-version 2

# Configure .wslconfig (in Windows %USERPROFILE%\.wslconfig)
[wsl2]
memory=8GB              # Limit memory usage
processors=4            # CPU cores
swap=4GB
localhostForwarding=true # Access WSL services from Windows
```

**VS Code Integration:**

```json
// .vscode/settings.json
{
  "remote.WSL.fileWatcher.polling": false,
  "remote.WSL.useShellEnvironment": true,
  "terminal.integrated.defaultProfile.windows": "WSL",
  "python.defaultInterpreterPath": "/usr/bin/python3",
  "docker.host": "unix:///var/run/docker.sock"
}
```

**Essential VS Code Extensions:**
- **Remote - WSL** (ms-vscode-remote.remote-wsl)
- **Docker** (ms-azuretools.vscode-docker)
- **Python** (ms-python.python)
- **Pylance** (ms-python.vscode-pylance)
- **ESLint** (dbaeumer.vscode-eslint)
- **GitLens** (eamodio.gitlens)
- **Thunder Client** (rangav.vscode-thunder-client) - API testing
- **YAML** (redhat.vscode-yaml)
- **Better Comments** (aaron-bond.better-comments)
- **GitHub Copilot** (github.copilot)

### 1.2 Docker Installation on WSL2

**Best Practice: Install Docker Engine directly in WSL2 (not Docker Desktop)**

```bash
# Remove old Docker versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose V2
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

**Why Docker Engine over Docker Desktop?**
- Lighter resource usage
- Direct integration with WSL2 filesystem
- No licensing concerns for enterprise use
- Better performance for container builds
- Native Linux socket communication

### 1.3 Ubuntu LXC/VM Setup on Proxmox

**Use Cases:**
- Integration testing in production-like environment
- CI/CD runners
- Staging deployments
- Multi-host testing

**LXC Container Template (for development/testing):**

```bash
# Create privileged LXC with Docker support
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname dthostmon-dev \
  --memory 4096 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 0 \
  --storage local-lvm \
  --rootfs local-lvm:16

# Start and enter
pct start 200
pct enter 200

# Install Docker inside LXC
curl -fsSL https://get.docker.com | sh
```

**VM vs LXC Decision Matrix:**

| Feature | LXC | VM |
|---------|-----|-----|
| Resource Overhead | Minimal | Higher |
| Nested Virtualization | Supported (nesting=1) | Full support |
| Kernel Sharing | Shared with host | Isolated |
| Docker Support | Yes (with nesting) | Native |
| Use Case | Dev/Test | Production staging |
| Boot Time | <5 seconds | ~30 seconds |
| **Recommendation** | **Development & CI/CD** | **Production staging** |

---

## Container Development Best Practices

### 2.1 Multi-Stage Dockerfile Pattern

**Why Multi-Stage Builds?**
- Smaller final image size (remove build tools)
- Security (no build-time secrets in final image)
- Faster deployment (less data transfer)

**Example for dthostmon:**

```dockerfile
# Stage 1: Build stage
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /build/wheels -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    openssh-client \
    postgresql-client \
    cron \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built wheels from builder
COPY --from=builder /build/wheels /wheels
RUN pip install --no-cache /wheels/*

# Install OpenCode CLI
RUN curl -L https://get.opencode.ai/linux | bash

# Copy application code
COPY src/ /app/src/
COPY config/ /app/config/

# Create directories
RUN mkdir -p /opt/dthostmon/config \
             /opt/dthostmon/logs \
             /opt/dthostmon/.ssh \
             /root/.local/share/opencode \
    && chmod 700 /opt/dthostmon/.ssh

# Copy and set entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["api"]
```

### 2.2 Docker Compose Best Practices

**Development vs Production Compose Files:**

```yaml
# docker-compose.yml (base configuration)
version: "3.8"

services:
  dthostmon:
    build: .
    image: dthostmon:${VERSION:-latest}
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./config:/opt/dthostmon/config:rw
      - ./logs:/opt/dthostmon/logs:rw
      - ~/.ssh:/opt/dthostmon/.ssh:ro
    networks:
      - dthostmon_network
    labels:
      - "divtools.group=monitoring"

networks:
  dthostmon_network:
    driver: bridge
```

```yaml
# docker-compose.dev.yml (development overrides)
version: "3.8"

services:
  dthostmon:
    build:
      context: .
      target: builder  # Use builder stage for dev tools
    volumes:
      # Mount source code for live reload
      - ./src:/app/src:rw
      - ./tests:/app/tests:rw
      - ./alembic:/app/alembic:rw
    environment:
      - DEBUG=true
      - LOG_LEVEL=DEBUG
    command: ["dev"]  # Run in dev mode
    ports:
      - "8080:8080"
      - "5678:5678"  # Debugger port
```

```yaml
# docker-compose.test.yml (testing environment)
version: "3.8"

services:
  dthostmon:
    command: ["pytest", "tests/"]
    environment:
      - TESTING=true
      - DATABASE_URL=postgresql://test:test@postgres-test:5432/dthostmon_test
    depends_on:
      - postgres-test

  postgres-test:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: dthostmon_test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    tmpfs:
      - /var/lib/postgresql/data  # In-memory for speed
```

**Usage:**

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Testing
docker compose -f docker-compose.yml -f docker-compose.test.yml up --abort-on-container-exit

# Production
docker compose up -d
```

### 2.3 .dockerignore Optimization

```gitignore
# .dockerignore
# Reduce build context size and improve build speed

# Git
.git
.gitignore
.github

# Documentation
*.md
docs/
!docs/API.md

# Testing
tests/
pytest.ini
.pytest_cache
.coverage
htmlcov/

# Development
.vscode/
.idea/
*.pyc
__pycache__/
.env
.env.*
!.env.example

# Logs
logs/
*.log

# OS
.DS_Store
Thumbs.db

# Temporary
tmp/
temp/
*.tmp
```

### 2.4 Container Layer Caching Strategy

**Order Dockerfile commands by change frequency (least to most):**

```dockerfile
# 1. Base image (rarely changes)
FROM python:3.11-slim

# 2. System packages (occasionally change)
RUN apt-get update && apt-get install -y openssh-client

# 3. Requirements (change moderately)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 4. Application code (changes frequently)
COPY src/ /app/src/

# 5. Configuration templates (change rarely)
COPY config/ /app/config/
```

**BuildKit Features:**

```bash
# Enable BuildKit for parallel layer builds
export DOCKER_BUILDKIT=1

# Build with cache mount for pip
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from dthostmon:latest \
  -t dthostmon:dev .
```

---

## Language & Framework Considerations

### 3.1 Python - Best for AI-Assisted Development ⭐

**Why Python is Ideal for AI Code Generation:**

✅ **Strengths:**
- **High readability:** AI models trained extensively on Python (most popular language on GitHub)
- **Explicit syntax:** Less ambiguity = fewer AI errors
- **Rich standard library:** AI can reference well-documented APIs
- **Type hints:** Help AI understand intent (`def process(data: dict) -> bool:`)
- **Consistent idioms:** PEP 8 provides clear style guide
- **Strong ecosystem:** AI knows popular libraries (FastAPI, SQLAlchemy, pytest)

❌ **Weaknesses:**
- Runtime errors (no compile-time checks)
- Performance (slower than compiled languages)
- GIL limitations (for CPU-bound tasks)

**AI-Friendly Python Patterns:**

```python
# Good: Type hints help AI understand and generate correct code
from typing import List, Dict, Optional
from datetime import datetime

def analyze_logs(
    log_entries: List[Dict[str, str]], 
    threshold: int = 100
) -> Optional[Dict[str, any]]:
    """
    Analyze log entries and return anomaly report.
    
    Args:
        log_entries: List of log dictionaries with 'timestamp', 'level', 'message'
        threshold: Minimum anomaly score to report
        
    Returns:
        Dictionary with analysis results or None if no anomalies
    """
    results = {"anomalies": [], "score": 0}
    # AI can easily complete this function
    return results if results["score"] > threshold else None
```

**Python Framework Recommendations:**

| Framework | Use Case | AI Code Quality | Learning Curve |
|-----------|----------|-----------------|----------------|
| **FastAPI** ⭐ | REST APIs, async | Excellent | Low |
| **Flask** | Simple APIs, microservices | Very Good | Very Low |
| **Django** | Full web apps | Good | Medium |
| **SQLAlchemy** | Database ORM | Excellent | Medium |
| **Pydantic** | Data validation | Excellent | Low |
| **Click/Typer** | CLI tools | Excellent | Low |
| **Rich/Textual** | TUI applications | Good | Medium |

**dthostmon Current Stack:**
- ✅ FastAPI (REST API)
- ✅ SQLAlchemy (database ORM)
- ✅ Pydantic (validation)
- ✅ pytest (testing)

### 3.2 JavaScript/TypeScript (Node.js) - Good for Web Services

**Why TypeScript > JavaScript for AI:**

```typescript
// TypeScript: AI understands types and can catch errors
interface HostConfig {
    hostname: string;
    port: number;
    enabled: boolean;
    tags?: string[];
}

async function connectToHost(config: HostConfig): Promise<SSHClient> {
    // AI generates type-safe code
    const client = new SSHClient({
        host: config.hostname,
        port: config.port
    });
    await client.connect();
    return client;
}

// JavaScript: AI has less context, more prone to errors
async function connectToHost(config) {
    const client = new SSHClient({
        host: config.hostname,  // No guarantee this property exists
        port: config.port
    });
    await client.connect();
    return client;
}
```

**Node.js Framework Recommendations:**

| Framework | Use Case | AI Code Quality | Performance |
|-----------|----------|-----------------|-------------|
| **Express.js** | REST APIs | Very Good | Good |
| **Fastify** | High-performance APIs | Good | Excellent |
| **NestJS** ⭐ | Enterprise apps | Excellent | Good |
| **Next.js** ⭐ | Full-stack React | Excellent | Excellent |
| **Prisma** | Database ORM | Excellent | Very Good |
| **TypeORM** | Database ORM | Good | Good |

**When to Use Node.js:**
- Real-time applications (WebSockets)
- I/O-bound operations (file processing, API proxying)
- JavaScript/TypeScript ecosystem preference
- React-based full-stack apps

**When Python is Better:**
- Data processing and analysis
- AI/ML integration
- System administration tasks
- Scientific computing

### 3.3 React.js - Frontend Framework (Future Phase 2+)

**React Best Practices for AI-Assisted Development:**

```typescript
// Component structure that AI generates well

// 1. Props interface
interface DashboardProps {
    hostData: HostMetrics[];
    onRefresh: () => void;
}

// 2. Component with clear types
export const Dashboard: React.FC<DashboardProps> = ({ hostData, onRefresh }) => {
    // 3. Hooks at top level
    const [selectedHost, setSelectedHost] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(false);
    
    // 4. Custom hooks
    const { data, error } = useHostMetrics(selectedHost);
    
    // 5. Event handlers
    const handleHostSelect = useCallback((hostId: string) => {
        setSelectedHost(hostId);
    }, []);
    
    // 6. Render
    return (
        <div className="dashboard">
            <HostList hosts={hostData} onSelect={handleHostSelect} />
            {selectedHost && <HostDetails hostId={selectedHost} />}
        </div>
    );
};
```

**Recommended React Stack for dthostmon Web UI:**

| Tool | Purpose | Why |
|------|---------|-----|
| **Next.js 14+** | Framework | Server components, SSR, API routes |
| **TypeScript** | Type safety | AI generates better code |
| **TailwindCSS** | Styling | Utility-first, AI understands classes |
| **shadcn/ui** | Components | Copy-paste, customizable, AI-friendly |
| **React Query** | Data fetching | Built-in caching, AI knows patterns |
| **Zustand** | State management | Simple, AI generates correct usage |
| **Recharts** | Metrics charts | Declarative, AI can create dashboards |

---

## Database Management

### 4.1 PostgreSQL Schema Management

**Industry Standard: Alembic (Python) or Prisma (Node.js)**

**dthostmon uses Alembic (already implemented):**

```python
# alembic/versions/001_initial_schema.py
"""Initial schema

Revision ID: 001
Create Date: 2025-11-14
"""

from alembic import op
import sqlalchemy as sa

def upgrade():
    op.create_table(
        'hosts',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('hostname', sa.String(255), nullable=False),
        sa.Column('site', sa.String(100)),
        sa.Column('enabled', sa.Boolean, default=True),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
        sa.Index('idx_hosts_site', 'site'),
        sa.Index('idx_hosts_enabled', 'enabled')
    )

def downgrade():
    op.drop_table('hosts')
```

**Best Practices:**

```bash
# Development workflow
alembic revision -m "add_report_frequency_to_hosts"  # Create migration
alembic upgrade head                                  # Apply migration
alembic downgrade -1                                  # Rollback one migration

# Production workflow
alembic upgrade head --sql > migration_001.sql        # Generate SQL
psql -U postgres -d dthostmon < migration_001.sql     # Review and apply manually
```

### 4.2 Database Access Patterns

**SQLAlchemy Best Practices:**

```python
# Good: Session management with context manager
from contextlib import contextmanager
from sqlalchemy.orm import sessionmaker

@contextmanager
def get_db_session():
    """Context manager for database sessions."""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

# Usage
def create_host(name: str, hostname: str) -> Host:
    with get_db_session() as session:
        host = Host(name=name, hostname=hostname)
        session.add(host)
        return host

# Better: Repository pattern (for larger apps)
class HostRepository:
    def __init__(self, session: Session):
        self.session = session
    
    def create(self, **kwargs) -> Host:
        host = Host(**kwargs)
        self.session.add(host)
        self.session.flush()
        return host
    
    def find_by_site(self, site: str) -> List[Host]:
        return self.session.query(Host).filter(Host.site == site).all()
```

### 4.3 Database Containerization

**Development Database:**

```yaml
# docker-compose.dev.yml
services:
  postgres-dev:
    image: postgres:15-alpine
    container_name: dthostmon-postgres-dev
    environment:
      POSTGRES_DB: dthostmon_dev
      POSTGRES_USER: devuser
      POSTGRES_PASSWORD: devpass
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devuser"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_dev_data:
```

**Production Database (External):**
- Use managed PostgreSQL (AWS RDS, Azure Database, DigitalOcean Managed DB)
- Or dedicated PostgreSQL VM on Proxmox
- Never store production data in Docker volumes (unless using persistent volume with backups)

---

## Development Tools & Platforms

### 5.1 VS Code Configuration for Docker Development

```json
// .vscode/settings.json
{
    // Python
    "python.defaultInterpreterPath": "/usr/bin/python3.11",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "python.testing.pytestEnabled": true,
    "python.testing.unittestEnabled": false,
    
    // Docker
    "docker.showStartPage": false,
    "docker.dockerPath": "docker",
    "docker.host": "unix:///var/run/docker.sock",
    
    // Editor
    "editor.formatOnSave": true,
    "editor.rulers": [88, 120],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    
    // Remote Development
    "remote.extensionKind": {
        "ms-python.python": ["workspace"]
    },
    
    // Git
    "git.enableSmartCommit": true,
    "git.autofetch": true
}
```

```json
// .vscode/launch.json (debugging)
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: FastAPI",
            "type": "python",
            "request": "launch",
            "module": "uvicorn",
            "args": [
                "src.dthostmon.api.server:app",
                "--reload",
                "--host", "0.0.0.0",
                "--port", "8080"
            ],
            "jinja": true,
            "justMyCode": false
        },
        {
            "name": "Python: Docker Attach",
            "type": "python",
            "request": "attach",
            "connect": {
                "host": "localhost",
                "port": 5678
            },
            "pathMappings": [
                {
                    "localRoot": "${workspaceFolder}",
                    "remoteRoot": "/app"
                }
            ]
        },
        {
            "name": "Python: Pytest Current File",
            "type": "python",
            "request": "launch",
            "module": "pytest",
            "args": [
                "${file}",
                "-v",
                "-s"
            ],
            "console": "integratedTerminal"
        }
    ]
}
```

### 5.2 Development Helper Scripts

**Create `dev.sh` script for common tasks:**

```bash
#!/bin/bash
# Development helper script for dthostmon
# Last Updated: 11/16/2025

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[dev.sh]${NC} $1"; }
warn() { echo -e "${YELLOW}[dev.sh]${NC} $1"; }
error() { echo -e "${RED}[dev.sh]${NC} $1"; }

show_help() {
    cat << EOF
dthostmon Development Helper Script

Usage: ./dev.sh [command]

Commands:
    build       Build Docker image
    up          Start development environment
    down        Stop development environment
    restart     Restart containers
    logs        Show container logs
    shell       Enter container shell
    test        Run tests
    lint        Run linting
    format      Format code with black
    migrate     Run database migrations
    psql        Connect to PostgreSQL
    clean       Remove containers, volumes, images
    
Examples:
    ./dev.sh up
    ./dev.sh test
    ./dev.sh shell
EOF
}

case "$1" in
    build)
        log "Building Docker image..."
        docker compose -f docker-compose.yml -f docker-compose.dev.yml build
        ;;
    up)
        log "Starting development environment..."
        docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
        log "Environment started. Access API at http://localhost:8080"
        ;;
    down)
        log "Stopping development environment..."
        docker compose -f docker-compose.yml -f docker-compose.dev.yml down
        ;;
    restart)
        log "Restarting containers..."
        docker compose -f docker-compose.yml -f docker-compose.dev.yml restart
        ;;
    logs)
        docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
        ;;
    shell)
        log "Entering container shell..."
        docker compose -f docker-compose.yml -f docker-compose.dev.yml exec dthostmon /bin/bash
        ;;
    test)
        log "Running tests..."
        docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm dthostmon pytest tests/ -v
        ;;
    lint)
        log "Running linting..."
        docker compose exec dthostmon pylint src/dthostmon/
        ;;
    format)
        log "Formatting code..."
        docker compose exec dthostmon black src/ tests/
        ;;
    migrate)
        log "Running database migrations..."
        docker compose exec dthostmon alembic upgrade head
        ;;
    psql)
        log "Connecting to PostgreSQL..."
        docker compose exec postgres-dev psql -U devuser -d dthostmon_dev
        ;;
    clean)
        warn "This will remove all containers, volumes, and images. Continue? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v
            docker rmi dthostmon:latest dthostmon:dev 2>/dev/null || true
            log "Cleaned up"
        fi
        ;;
    *)
        show_help
        ;;
esac
```

### 5.3 Terminal/TUI Frameworks

**Python TUI Frameworks:**

| Framework | Description | AI Code Quality | Use Case |
|-----------|-------------|-----------------|----------|
| **Rich** ⭐ | Terminal formatting, tables, progress | Excellent | CLI output enhancement |
| **Textual** ⭐ | Modern TUI framework | Very Good | Full TUI apps |
| **Prompt Toolkit** | Interactive CLIs | Good | Input prompts, autocomplete |
| **Typer** | CLI framework (Click alternative) | Excellent | CLI commands |
| **Questionary** | Interactive prompts | Very Good | Setup wizards |

**Example: Rich for dthostmon CLI:**

```python
from rich.console import Console
from rich.table import Table
from rich.progress import track
from rich.panel import Panel

console = Console()

def show_host_status(hosts: List[Host]):
    """Display host status in formatted table."""
    table = Table(title="Host Status", show_header=True)
    table.add_column("Name", style="cyan")
    table.add_column("Site", style="magenta")
    table.add_column("Status", justify="center")
    table.add_column("Health", justify="right")
    
    for host in hosts:
        status_icon = "✓" if host.enabled else "✗"
        status_color = "green" if host.enabled else "red"
        table.add_row(
            host.name,
            host.site,
            f"[{status_color}]{status_icon}[/{status_color}]",
            f"{host.health_score}%"
        )
    
    console.print(table)

def run_monitoring(hosts: List[Host]):
    """Monitor hosts with progress bar."""
    for host in track(hosts, description="Monitoring hosts..."):
        monitor_host(host)
    
    console.print("[green]✓[/green] Monitoring complete!")
```

**Node.js TUI Frameworks:**

| Framework | Description | AI Code Quality | Use Case |
|-----------|-------------|-----------------|----------|
| **Ink** ⭐ | React for CLI | Excellent | React-based TUIs |
| **Blessed** | Low-level TUI | Good | Custom terminal UIs |
| **Inquirer** | Interactive prompts | Very Good | CLI wizards |
| **Commander** | CLI framework | Excellent | Command parsing |

---

## Testing Strategies

### 6.1 Testing Pyramid

```
        /\
       /  \        E2E Tests (5-10%)
      /____\       - Full system integration
     /      \      - Selenium/Playwright
    /        \     
   /  Integration  \   Integration Tests (20-30%)
  /    Tests        \  - API tests
 /__________________\  - Database tests
/                    \ 
/   Unit Tests        \ Unit Tests (60-70%)
/    (60-70%)         \ - Function-level
/______________________\ - Fast, isolated

```

**dthostmon Test Structure:**

```
tests/
├── unit/                      # Unit tests (pytest)
│   ├── test_ssh_client.py     # SSH connection logic
│   ├── test_ai_analyzer.py    # AI analysis functions
│   ├── test_config.py         # Configuration parsing
│   ├── test_email_alert.py    # Email generation
│   └── test_report_scheduler.py
├── integration/               # Integration tests
│   ├── test_orchestrator.py   # End-to-end workflow
│   ├── test_api_endpoints.py  # REST API
│   └── test_database.py       # Database operations
├── fixtures/                  # Test data
│   ├── sample_logs.txt
│   ├── sample_config.yaml
│   └── mock_responses.json
├── conftest.py               # Shared fixtures
└── testmenu.sh               # Interactive test runner
```

### 6.2 Test Configuration

**pytest.ini:**

```ini
[pytest]
minversion = 7.0
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    -v
    --strict-markers
    --tb=short
    --cov=src/dthostmon
    --cov-report=html
    --cov-report=term-missing
    --cov-fail-under=80
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Slow tests (skip with -m "not slow")
    requires_db: Requires database connection
    requires_ssh: Requires SSH server
```

### 6.3 Testing in Containers

**Run tests inside container:**

```bash
# Unit tests
docker compose -f docker-compose.test.yml run --rm dthostmon \
    pytest tests/unit/ -v

# Integration tests with database
docker compose -f docker-compose.test.yml up -d postgres-test
docker compose -f docker-compose.test.yml run --rm dthostmon \
    pytest tests/integration/ -v --requires-db

# Full test suite with coverage
docker compose -f docker-compose.test.yml run --rm dthostmon \
    pytest tests/ -v --cov=src/dthostmon --cov-report=html

# Cleanup
docker compose -f docker-compose.test.yml down -v
```

---

## CI/CD Pipeline

### 7.1 GitHub Actions Workflow

**`.github/workflows/ci.yml`:**

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: |
          pip install pylint black flake8
          pip install -r requirements.txt
          
      - name: Run black (formatting check)
        run: black --check src/ tests/
        
      - name: Run pylint
        run: pylint src/dthostmon/
        
      - name: Run flake8
        run: flake8 src/ --max-line-length=88

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: dthostmon_test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
          
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          cache: 'pip'
          
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
          
      - name: Run tests
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/dthostmon_test
          TESTING: true
        run: |
          pytest tests/ -v \
            --cov=src/dthostmon \
            --cov-report=xml \
            --cov-report=term-missing \
            --cov-fail-under=80
            
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          flags: unittests
          name: codecov-dthostmon

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

### 7.2 GitLab CI (Alternative)

**`.gitlab-ci.yml`:**

```yaml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

lint:
  stage: lint
  image: python:3.11-slim
  script:
    - pip install pylint black flake8
    - black --check src/ tests/
    - pylint src/dthostmon/
    - flake8 src/ --max-line-length=88

test:
  stage: test
  image: python:3.11-slim
  services:
    - postgres:15-alpine
  variables:
    POSTGRES_DB: dthostmon_test
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: postgresql://test:test@postgres:5432/dthostmon_test
  script:
    - pip install -r requirements.txt -r requirements-dev.txt
    - pytest tests/ -v --cov=src/dthostmon --cov-report=term --cov-report=html
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
    paths:
      - htmlcov/

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG
  only:
    - main
    - develop
```

---

## Production Deployment

### 8.1 Kubernetes (K3s) Deployment

**K3s Installation on Ubuntu LXC/VM:**

```bash
# Install K3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Verify installation
kubectl get nodes

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

**Kubernetes Manifests:**

**`k8s/namespace.yaml`:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dthostmon
  labels:
    name: dthostmon
```

**`k8s/configmap.yaml`:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dthostmon-config
  namespace: dthostmon
data:
  dthostmon.yaml: |
    global:
      monitoring_interval: 3600
      concurrent_workers: 10
    email:
      smtp_host: smtp.gmail.com
      smtp_port: 587
    ai:
      opencode_url: http://localhost:4096
```

**`k8s/secret.yaml`:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dthostmon-secrets
  namespace: dthostmon
type: Opaque
stringData:
  DATABASE_URL: postgresql://user:password@postgres:5432/dthostmon
  EMAIL_PASSWORD: smtp_password_here
  API_KEY: your_api_key_here
```

**`k8s/deployment.yaml`:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dthostmon
  namespace: dthostmon
  labels:
    app: dthostmon
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: dthostmon
  template:
    metadata:
      labels:
        app: dthostmon
    spec:
      containers:
      - name: dthostmon
        image: ghcr.io/adf1969/dthostmon:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: api
        envFrom:
        - secretRef:
            name: dthostmon-secrets
        volumeMounts:
        - name: config
          mountPath: /opt/dthostmon/config
          readOnly: true
        - name: logs
          mountPath: /opt/dthostmon/logs
        - name: ssh-keys
          mountPath: /opt/dthostmon/.ssh
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: dthostmon-config
      - name: logs
        persistentVolumeClaim:
          claimName: dthostmon-logs-pvc
      - name: ssh-keys
        secret:
          secretName: dthostmon-ssh-keys
          defaultMode: 0600
```

**`k8s/service.yaml`:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: dthostmon-service
  namespace: dthostmon
spec:
  type: ClusterIP
  selector:
    app: dthostmon
  ports:
  - port: 8080
    targetPort: 8080
    name: api
```

**`k8s/ingress.yaml`:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dthostmon-ingress
  namespace: dthostmon
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  rules:
  - host: dthostmon.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dthostmon-service
            port:
              number: 8080
  tls:
  - hosts:
    - dthostmon.example.com
    secretName: dthostmon-tls
```

**Deploy to K3s:**

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets (edit first!)
kubectl apply -f k8s/secret.yaml

# Create configmap
kubectl apply -f k8s/configmap.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Verify deployment
kubectl get pods -n dthostmon
kubectl logs -n dthostmon -l app=dthostmon --tail=50
```

### 8.2 Monitoring and Logging

**Prometheus + Grafana Stack:**

```yaml
# k8s/prometheus-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dthostmon
  namespace: dthostmon
spec:
  selector:
    matchLabels:
      app: dthostmon
  endpoints:
  - port: api
    path: /metrics
    interval: 30s
```

**Loki for Log Aggregation:**

```yaml
# k8s/loki-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: dthostmon
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrape_configs:
      - job_name: dthostmon
        static_configs:
          - targets:
              - localhost
            labels:
              job: dthostmon
              __path__: /opt/dthostmon/logs/*.log
```

---

## AI-Assisted Development

### 9.1 GitHub Copilot Best Practices

**Enable Copilot Suggestions:**

```json
// .vscode/settings.json
{
    "github.copilot.enable": {
        "*": true,
        "python": true,
        "yaml": true,
        "markdown": true
    },
    "github.copilot.advanced": {
        "debug.overrideEngine": "copilot-codex"
    }
}
```

**Write AI-Friendly Comments:**

```python
# Good: Descriptive comments guide AI
# Function to connect to remote host via SSH, retry 3 times with exponential backoff
def connect_to_host(hostname: str, port: int = 22) -> SSHClient:
    # AI will generate the retry logic correctly
    pass

# Bad: Vague comments confuse AI
# Connect to host
def connect(h, p):
    pass
```

**Use Type Hints:**

```python
# AI generates better code with type hints
from typing import List, Dict, Optional

def analyze_logs(
    logs: List[str], 
    context: Dict[str, any]
) -> Optional[Dict[str, any]]:
    """
    Analyze log entries using AI model.
    
    Args:
        logs: List of log lines to analyze
        context: Additional context (hostname, site, etc.)
        
    Returns:
        Analysis results with anomalies and health score
    """
    # AI completes this accurately with types
```

### 9.2 Claude/GPT-4 for Architecture

**Use AI for:**
- ✅ Architecture design reviews
- ✅ Code refactoring suggestions
- ✅ Test case generation
- ✅ Documentation writing
- ✅ Debugging complex issues

**Effective Prompts:**

```
Good Prompt:
"Review this Python function that monitors SSH connections. It should:
1. Retry 3 times with exponential backoff
2. Log each connection attempt
3. Return None if all retries fail
4. Include type hints and docstring

[paste code]

Suggest improvements for error handling, logging, and code clarity."

Bad Prompt:
"Fix this code"
```

### 9.3 OpenCode Server Integration

**dthostmon already uses OpenCode Server for AI analysis.**

**Architecture:**

```
┌─────────────────┐
│  dthostmon      │
│  Container      │
│                 │
│  ┌───────────┐  │
│  │ Monitor   │  │
│  │ Worker    │  │
│  └─────┬─────┘  │
│        │        │
│        ▼        │
│  ┌───────────┐  │
│  │ OpenCode  │  │◄──── API Calls (localhost:4096)
│  │ Server    │  │
│  └───────────┘  │
│        │        │
│        ▼        │
│  ┌───────────┐  │
│  │ Multi-    │  │
│  │ Model     │  │◄──── Grok, Claude, GPT-4, Ollama
│  │ Routing   │  │
│  └───────────┘  │
└─────────────────┘
```

**Benefits:**
- Single authentication point (host manages API keys)
- Easy model switching (no code changes)
- Cost optimization (route to cheapest available model)
- Fallback support (if one model fails, try another)

---

## dthostmon Specific Recommendations

### 10.1 Current Architecture Assessment

**✅ Good Decisions:**
- Python 3.11+ (excellent AI support, rich ecosystem)
- FastAPI (modern, async, well-documented)
- PostgreSQL (robust, scalable)
- Docker containerization (K3s-ready)
- Alembic migrations (industry standard)
- OpenCode Server (multi-model flexibility)
- pytest for testing (comprehensive, AI-friendly)

**⚠️ Consider Adding:**
- **Structured logging** (JSON format for log aggregation)
- **Metrics endpoint** (Prometheus `/metrics`)
- **Feature flags** (gradual rollout of new features)
- **Rate limiting** (protect API endpoints)
- **Request tracing** (distributed tracing for debugging)

### 10.2 Phase 2+ Recommendations (Web UI)

**Technology Stack:**

| Component | Recommended | Alternative | Why |
|-----------|-------------|-------------|-----|
| **Frontend Framework** | Next.js 14 | Remix | Server components, SEO, API routes |
| **Language** | TypeScript | JavaScript | Type safety, AI code quality |
| **Styling** | TailwindCSS | Chakra UI | Utility-first, AI understands |
| **Components** | shadcn/ui | Ant Design | Copy-paste, customizable |
| **State Management** | Zustand | Redux Toolkit | Simple, less boilerplate |
| **Data Fetching** | React Query | SWR | Built-in caching, polling |
| **Charts** | Recharts | Chart.js | Declarative, React-native |
| **Forms** | React Hook Form | Formik | Performance, validation |
| **Tables** | TanStack Table | Ag-Grid | Powerful, lightweight |

**Architecture (Separate Container):**

```
┌─────────────────┐      ┌─────────────────┐
│  dthostmon-ui   │      │  dthostmon-api  │
│  (Next.js)      │◄────►│  (FastAPI)      │
│                 │ HTTP │                 │
│  Port: 3000     │      │  Port: 8080     │
└─────────────────┘      └─────────────────┘
```

**Or Integrated:**

```
┌─────────────────────────────┐
│  dthostmon                  │
│                             │
│  ┌───────────┐              │
│  │ FastAPI   │◄──API calls──┤
│  │ Backend   │              │
│  └───────────┘              │
│                             │
│  ┌───────────┐              │
│  │ Static    │◄──Static─────┤
│  │ Frontend  │   files      │
│  │ (build)   │              │
│  └───────────┘              │
└─────────────────────────────┘
```

### 10.3 Recommended Development Workflow

**Day-to-Day Development:**

```bash
# Morning: Start development environment
cd /home/divix/divtools/projects/dthostmon
./dev.sh up

# Edit code in VS Code (WSL2)
code .

# Run tests after changes
./dev.sh test

# Check logs
./dev.sh logs

# Enter container for debugging
./dev.sh shell

# Evening: Stop environment
./dev.sh down
```

**Feature Development Workflow:**

```bash
# 1. Create feature branch
git checkout -b feature/add-prometheus-integration

# 2. Make changes
# 3. Add tests
# 4. Run tests locally
./dev.sh test

# 5. Lint code
./dev.sh lint

# 6. Format code
./dev.sh format

# 7. Commit changes
git add .
git commit -m "feat: add Prometheus metrics integration"

# 8. Push and create PR
git push origin feature/add-prometheus-integration
```

**Kubernetes Deployment Workflow:**

```bash
# 1. Build and push image
docker build -t ghcr.io/adf1969/dthostmon:v1.2.0 .
docker push ghcr.io/adf1969/dthostmon:v1.2.0

# 2. Update deployment
kubectl set image deployment/dthostmon \
    dthostmon=ghcr.io/adf1969/dthostmon:v1.2.0 \
    -n dthostmon

# 3. Monitor rollout
kubectl rollout status deployment/dthostmon -n dthostmon

# 4. Verify
kubectl get pods -n dthostmon
kubectl logs -n dthostmon -l app=dthostmon --tail=50

# 5. Rollback if needed
kubectl rollout undo deployment/dthostmon -n dthostmon
```

---

## Summary & Quick Reference

### Technology Decision Matrix

| Requirement | Recommended | AI Code Quality | Maturity | dthostmon Status |
|-------------|-------------|-----------------|----------|------------------|
| **Backend Language** | Python 3.11+ | ⭐⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **API Framework** | FastAPI | ⭐⭐⭐⭐⭐ | Modern | ✅ Implemented |
| **Database** | PostgreSQL | ⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **ORM** | SQLAlchemy | ⭐⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **Migrations** | Alembic | ⭐⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **Testing** | pytest | ⭐⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **Containerization** | Docker | ⭐⭐⭐⭐⭐ | Mature | ✅ Implemented |
| **Orchestration** | K3s | ⭐⭐⭐⭐ | Stable | 📋 Planned Phase 1 |
| **Frontend (Phase 2)** | Next.js + TypeScript | ⭐⭐⭐⭐⭐ | Modern | 📋 Planned Phase 2 |
| **TUI** | Rich + Typer | ⭐⭐⭐⭐⭐ | Mature | 🔄 Partial |
| **CI/CD** | GitHub Actions | ⭐⭐⭐⭐⭐ | Mature | 📋 Planned |
| **Monitoring** | Prometheus + Grafana | ⭐⭐⭐⭐ | Mature | 📋 Planned Phase 3 |

**Legend:**
- ⭐⭐⭐⭐⭐ Excellent AI code generation
- ⭐⭐⭐⭐ Very good AI support
- ⭐⭐⭐ Good AI support

### Essential Commands Reference

```bash
# Development
./dev.sh up              # Start dev environment
./dev.sh test            # Run tests
./dev.sh shell           # Enter container
./dev.sh logs            # View logs

# Docker
docker compose build     # Build image
docker compose up -d     # Start detached
docker compose down      # Stop and remove
docker compose logs -f   # Follow logs

# Kubernetes
kubectl apply -f k8s/    # Deploy all manifests
kubectl get pods -n dthostmon
kubectl logs -n dthostmon -l app=dthostmon -f
kubectl exec -it <pod> -n dthostmon -- /bin/bash

# Testing
pytest tests/unit/       # Unit tests only
pytest tests/ -v --cov   # All tests with coverage
pytest -m "not slow"     # Skip slow tests

# Database
alembic revision -m "add_column"  # Create migration
alembic upgrade head              # Apply migrations
alembic downgrade -1              # Rollback one
```

### Resources & Documentation

**Official Documentation:**
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy 2.0](https://docs.sqlalchemy.org/en/20/)
- [pytest Documentation](https://docs.pytest.org/)
- [Kubernetes Patterns](https://kubernetes.io/docs/concepts/)
- [Next.js Documentation](https://nextjs.org/docs)

**Learning Resources:**
- [The Twelve-Factor App](https://12factor.net/) - Application design principles
- [Container Best Practices](https://cloud.google.com/architecture/best-practices-for-building-containers)
- [Python Testing Best Practices](https://docs.python-guide.org/writing/tests/)

---

## YouTube Video Tutorials by Technology

### Docker & Containerization

**Docker Fundamentals:**
- [Docker Tutorial for Beginners - TechWorld with Nana](https://www.youtube.com/watch?v=3c-iBn73dDE) - Complete Docker tutorial (3h 9m)
- [Docker Course - From Beginner to Advanced - freeCodeCamp](https://www.youtube.com/watch?v=RqTEHSBrYFw) - Comprehensive Docker course (2h 16m)
- [Docker Crash Course for Absolute Beginners - TechWorld with Nana](https://www.youtube.com/watch?v=pg19Z8LL06w) - Quick start (1h 2m)
- [Docker in 100 Seconds - Fireship](https://www.youtube.com/watch?v=Gjnup-PuquQ) - Quick overview (2m 29s)

**Docker Compose:**
- [Docker Compose Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=SXwC9fSwct8) - Multi-container apps (1h 34m)
- [Docker Compose in 12 Minutes - Jake Wright](https://www.youtube.com/watch?v=Qw9zlE3t8Ko) - Quick tutorial (12m 8s)
- [Docker Compose will BLOW your MIND - NetworkChuck](https://www.youtube.com/watch?v=DM65_JyGxCo) - Practical examples (21m 47s)

**Multi-Stage Builds:**
- [Docker Multi-Stage Builds - TechWorld with Nana](https://www.youtube.com/watch?v=zpkqNPwEzac) - Optimization techniques (15m 42s)
- [Docker Multi-Stage Builds Tutorial - That DevOps Guy](https://www.youtube.com/watch?v=2lQ0xOGMIGY) - Best practices (12m 18s)

**Dockerfile Best Practices:**
- [Dockerfile Best Practices - Docker](https://www.youtube.com/watch?v=JofsaZ3H1qM) - Official Docker guidance (38m 25s)
- [10 Best Practices to Containerize Python Apps - ArjanCodes](https://www.youtube.com/watch?v=4W8ZRF0pTv4) - Python-specific (24m 33s)

### Kubernetes & K3s

**Kubernetes Fundamentals:**
- [Kubernetes Tutorial for Beginners - TechWorld with Nana](https://www.youtube.com/watch?v=X48VuDVv0do) - Complete K8s course (4h 4m)
- [Kubernetes Crash Course for Absolute Beginners - TechWorld with Nana](https://www.youtube.com/watch?v=s_o8dwzRlu4) - Quick start (1h 9m)
- [Kubernetes in 100 Seconds - Fireship](https://www.youtube.com/watch?v=PziYflu8cRs) - Quick overview (2m 28s)

**K3s Lightweight Kubernetes:**
- [K3s Lightweight Kubernetes Tutorial - TechnoTim](https://www.youtube.com/watch?v=UoOcLXfa8EU) - Complete K3s setup (24m 56s)
- [K3s Tutorial - Jeff Geerling](https://www.youtube.com/watch?v=2iTu96TA45k) - Raspberry Pi cluster (15m 32s)
- [Getting Started with K3s - Rancher Labs](https://www.youtube.com/watch?v=8o-RLfAO61Y) - Official tutorial (44m 18s)

**Kubernetes Deployments:**
- [Kubernetes Deployments Explained - TechWorld with Nana](https://www.youtube.com/watch?v=mNK14yXIZF4) - Deployment strategies (12m 44s)
- [Kubernetes Services Explained - TechWorld with Nana](https://www.youtube.com/watch?v=T4Z7visMM4E) - Service types (18m 23s)

### Python Development

**Python Fundamentals:**
- [Python Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=_uQrJ0TkZlc) - Complete Python course (6h 14m)
- [Python for Beginners - freeCodeCamp](https://www.youtube.com/watch?v=rfscVS0vtbw) - Comprehensive tutorial (4h 26m)
- [Intermediate Python Programming Course - freeCodeCamp](https://www.youtube.com/watch?v=HGOBQPFzWKo) - Advanced concepts (6h 0m)

**Python Type Hints:**
- [Python Type Hints - ArjanCodes](https://www.youtube.com/watch?v=QORvB-_mbZ0) - Modern type annotations (21m 17s)
- [Python Type Checking with mypy - mCoding](https://www.youtube.com/watch?v=1nGEFWy2vFw) - Static type checking (15m 34s)

**Python Best Practices:**
- [25 nooby Python habits - mCoding](https://www.youtube.com/watch?v=qUeud6DvOWI) - Common mistakes (23m 42s)
- [Python Code Smells - ArjanCodes](https://www.youtube.com/watch?v=zmWf_cHyo8s) - Clean code practices (17m 28s)

### FastAPI

**FastAPI Tutorials:**
- [FastAPI Tutorial - Building RESTful APIs - Coding with Roby](https://www.youtube.com/watch?v=tLKKmouUams) - Complete FastAPI course (2h 28m)
- [FastAPI Course for Beginners - freeCodeCamp](https://www.youtube.com/watch?v=0sOvCWFmrtA) - Comprehensive tutorial (19h 1m)
- [FastAPI in 100 Seconds - Fireship](https://www.youtube.com/watch?v=SORiTsvnU28) - Quick overview (2m 20s)
- [Build a REST API with FastAPI - TechWorld with Nana](https://www.youtube.com/watch?v=iWS9ogMPOI0) - Practical example (1h 23m)

**FastAPI Advanced Topics:**
- [FastAPI Authentication & Authorization - testdriven.io](https://www.youtube.com/watch?v=fGN5gR9KoKs) - Security implementation (48m 15s)
- [FastAPI Async/Await - ArjanCodes](https://www.youtube.com/watch?v=9zinZmE3Ogk) - Async programming (24m 37s)

### PostgreSQL & Databases

**PostgreSQL Fundamentals:**
- [PostgreSQL Tutorial for Beginners - Amigoscode](https://www.youtube.com/watch?v=qw--VYLpxG4) - Complete PostgreSQL course (4h 18m)
- [PostgreSQL Crash Course - Traversy Media](https://www.youtube.com/watch?v=qw--VYLpxG4) - Quick tutorial (1h 12m)
- [SQL Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=7S_tz1z_5bA) - SQL fundamentals (3h 10m)

**SQLAlchemy ORM:**
- [SQLAlchemy Tutorial - Tech With Tim](https://www.youtube.com/watch?v=AKQ3XEDI9Mw) - Complete ORM tutorial (1h 1m)
- [SQLAlchemy 2.0 Tutorial - ArjanCodes](https://www.youtube.com/watch?v=AKQ3XEDI9Mw) - Modern SQLAlchemy (28m 45s)
- [Database Migrations with Alembic - Pretty Printed](https://www.youtube.com/watch?v=SdcH6IEi6nE) - Migration management (16m 23s)

**Database Design:**
- [Database Design Course - freeCodeCamp](https://www.youtube.com/watch?v=ztHopE5Wnpc) - Design principles (8h 23m)
- [7 Database Design Mistakes - Ben Awad](https://www.youtube.com/watch?v=qVhlpQJTr1Y) - Common pitfalls (10m 15s)

### Testing with pytest

**pytest Fundamentals:**
- [pytest Tutorial - Complete Guide - Tech With Tim](https://www.youtube.com/watch?v=cHYq1MRoyI0) - Comprehensive pytest (1h 23m)
- [Python Testing 101 with pytest - ArjanCodes](https://www.youtube.com/watch?v=etosV2IWBF0) - Best practices (22m 18s)
- [pytest Tutorial - Corey Schafer](https://www.youtube.com/watch?v=6tNS--WetLI) - Testing fundamentals (40m 37s)

**Testing Best Practices:**
- [Test-Driven Development with pytest - ArjanCodes](https://www.youtube.com/watch?v=B1j6k2j2eJg) - TDD workflow (25m 14s)
- [Mocking in Python - ArjanCodes](https://www.youtube.com/watch?v=2RBWKHa5eDw) - Mock objects (18m 42s)
- [pytest Fixtures - mCoding](https://www.youtube.com/watch?v=IVrGz8w0H8c) - Advanced fixtures (14m 28s)

### TypeScript & Node.js

**TypeScript Fundamentals:**
- [TypeScript Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=d56mG7DezGs) - Complete TypeScript course (1h 48m)
- [TypeScript Course - freeCodeCamp](https://www.youtube.com/watch?v=30LWjhZzg50) - Comprehensive tutorial (5h 3m)
- [TypeScript in 100 Seconds - Fireship](https://www.youtube.com/watch?v=zQnBQ4tB3ZA) - Quick overview (2m 41s)

**Node.js Development:**
- [Node.js Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=TlB_eWDSMt4) - Complete Node.js course (3h 5m)
- [Node.js Crash Course - Traversy Media](https://www.youtube.com/watch?v=fBNz5xF-Kbo) - Quick tutorial (1h 30m)
- [Node.js Backend Development Course - freeCodeCamp](https://www.youtube.com/watch?v=Oe421EPjeBE) - Backend focus (8h 16m)

**Express.js:**
- [Express.js Tutorial - Programming with Mosh](https://www.youtube.com/watch?v=pKd0Rpw7O48) - REST API with Express (1h 6m)
- [Express.js Crash Course - Traversy Media](https://www.youtube.com/watch?v=L72fhGm1tfE) - Quick start (39m 42s)

### React.js & Next.js

**React.js Fundamentals:**
- [React Course for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=SqcY0GlETPk) - Complete React course (8h 15m)
- [React Tutorial for Beginners - freeCodeCamp](https://www.youtube.com/watch?v=bMknfKXIFA8) - Comprehensive tutorial (11h 56m)
- [React in 100 Seconds - Fireship](https://www.youtube.com/watch?v=Tn6-PIqc4UM) - Quick overview (2m 21s)

**Next.js Framework:**
- [Next.js 14 Tutorial - Codevolution](https://www.youtube.com/watch?v=ZjAqacIC_3c) - Complete Next.js course (9h 23m)
- [Next.js Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=ZVnjOPwW4ZA) - Practical tutorial (1h 48m)
- [Next.js App Router - Fireship](https://www.youtube.com/watch?v=gSSsZReIFRk) - Server components (11m 34s)

**React Best Practices:**
- [React Hooks Tutorial - Codevolution](https://www.youtube.com/watch?v=cF2lQ_gZeA8) - Modern React patterns (9h 18m)
- [10 React Antipatterns - Fireship](https://www.youtube.com/watch?v=b0IZo2Aho9Y) - Common mistakes (8m 42s)

### TailwindCSS & UI Components

**TailwindCSS:**
- [Tailwind CSS Crash Course - Traversy Media](https://www.youtube.com/watch?v=UBOj6rqRUME) - Quick tutorial (1h 12m)
- [Tailwind CSS Tutorial - The Net Ninja](https://www.youtube.com/watch?v=bxmDnn7lrnk) - Complete course (3h 8m)
- [Tailwind in 100 Seconds - Fireship](https://www.youtube.com/watch?v=mr15Xzb1Ook) - Quick overview (2m 14s)

**shadcn/ui Components:**
- [shadcn/ui Tutorial - Build Better Components](https://www.youtube.com/watch?v=h5l5UCM5oiA) - Component library (24m 16s)
- [Build a Modern UI with shadcn/ui - Web Dev Simplified](https://www.youtube.com/watch?v=_OKAwz3u6Mo) - Practical examples (32m 45s)

### Git & GitHub

**Git Fundamentals:**
- [Git Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=8JJ101D3knE) - Complete Git course (1h 9m)
- [Git and GitHub Crash Course - freeCodeCamp](https://www.youtube.com/watch?v=RGOj5yH7evk) - Version control basics (1h 28m)
- [Git in 100 Seconds - Fireship](https://www.youtube.com/watch?v=hwP7WQkmECE) - Quick overview (2m 8s)

**GitHub Actions CI/CD:**
- [GitHub Actions Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=R8_veQiYBjI) - Complete CI/CD tutorial (1h 20m)
- [GitHub Actions Crash Course - Traversy Media](https://www.youtube.com/watch?v=mFFXuXjVgkU) - Quick tutorial (35m 18s)
- [GitHub Actions CI/CD Pipeline - DevOps Journey](https://www.youtube.com/watch?v=mBLp094JJLc) - Practical implementation (42m 23s)

### VS Code & Development Tools

**VS Code Setup:**
- [VS Code Tutorial for Beginners - Programming with Mosh](https://www.youtube.com/watch?v=VqCgcpAypFQ) - Complete guide (49m 33s)
- [25 VS Code Productivity Tips - Fireship](https://www.youtube.com/watch?v=ifTF3ags0XI) - Productivity hacks (12m 16s)
- [VS Code for Python Development - Corey Schafer](https://www.youtube.com/watch?v=-nh9rCzPJ20) - Python setup (24m 47s)

**WSL2 Setup:**
- [WSL2 Setup Tutorial - NetworkChuck](https://www.youtube.com/watch?v=_fntjriRe48) - Windows Linux setup (16m 42s)
- [WSL2 and VS Code - David Bombal](https://www.youtube.com/watch?v=qYlgUDKKK5A) - Development environment (18m 35s)
- [Docker on WSL2 - TechWorld with Nana](https://www.youtube.com/watch?v=5RQbdMn04Oc) - Docker integration (12m 28s)

### Proxmox & Virtualization

**Proxmox Basics:**
- [Proxmox Tutorial for Beginners - LearnLinuxTV](https://www.youtube.com/watch?v=LCjuiIswXGs) - Complete course (1h 34m)
- [Proxmox Setup Guide - TechnoTim](https://www.youtube.com/watch?v=GoZaMgEgrHw) - Installation tutorial (23m 45s)
- [Proxmox LXC Containers - Craft Computing](https://www.youtube.com/watch?v=cCTHgXS7z-o) - Container management (15m 18s)

**LXC vs VM:**
- [LXC vs Docker vs VM - LearnLinuxTV](https://www.youtube.com/watch?v=Yxck0oczNsU) - Comparison guide (18m 42s)
- [Proxmox LXC Tutorial - DB Tech](https://www.youtube.com/watch?v=wMxRLBJhYcg) - LXC setup (22m 16s)

### AI-Assisted Development

**GitHub Copilot:**
- [GitHub Copilot Tutorial - Fireship](https://www.youtube.com/watch?v=4duqI8WyfqE) - AI pair programming (6m 35s)
- [GitHub Copilot Complete Guide - Traversy Media](https://www.youtube.com/watch?v=F4J3w1YnRKo) - Practical usage (42m 18s)
- [AI-Powered Coding - NetworkChuck](https://www.youtube.com/watch?v=kP7J7lhVfz0) - Copilot tips (15m 23s)

**AI Code Generation:**
- [ChatGPT for Developers - freeCodeCamp](https://www.youtube.com/watch?v=sTeoEFzVNSc) - AI-assisted coding (1h 18m)
- [Using AI to Write Better Code - Fireship](https://www.youtube.com/watch?v=Xo6bCUnwSIo) - AI integration (9m 42s)

### DevOps & CI/CD

**CI/CD Fundamentals:**
- [DevOps Tutorial for Beginners - TechWorld with Nana](https://www.youtube.com/watch?v=j5Zsa_eOXeY) - Complete DevOps course (2h 17m)
- [CI/CD Pipeline Tutorial - freeCodeCamp](https://www.youtube.com/watch?v=scEDHsr3APg) - Pipeline implementation (2h 33m)
- [DevOps in 100 Seconds - Fireship](https://www.youtube.com/watch?v=scEDHsr3APg) - Quick overview (2m 38s)

**Monitoring & Logging:**
- [Prometheus Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=h4Sl21AKiDg) - Monitoring setup (56m 47s)
- [Grafana Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=QDqq8avMcYM) - Visualization dashboards (42m 18s)
- [ELK Stack Tutorial - Amigoscode](https://www.youtube.com/watch?v=gS_nHTWZEJ8) - Log aggregation (1h 32m)

### Terminal & CLI Tools

**Shell Scripting:**
- [Bash Scripting Tutorial - freeCodeCamp](https://www.youtube.com/watch?v=tK9Oc6AEnR4) - Complete bash course (3h 6m)
- [Shell Scripting Crash Course - Traversy Media](https://www.youtube.com/watch?v=v-F3YLd6oMw) - Quick tutorial (32m 18s)
- [Linux Command Line Tutorial - NetworkChuck](https://www.youtube.com/watch?v=s3ii48qYBxA) - CLI fundamentals (1h 2m)

**Terminal Multiplexers:**
- [tmux Tutorial - Dreams of Code](https://www.youtube.com/watch?v=DzNmUNvnB04) - Terminal multiplexing (11m 42s)
- [tmux Crash Course - Traversy Media](https://www.youtube.com/watch?v=Yl7NFenTgIo) - Quick guide (17m 28s)

### Security Best Practices

**Container Security:**
- [Docker Security Best Practices - TechWorld with Nana](https://www.youtube.com/watch?v=gxQJDmQZhfE) - Security hardening (28m 45s)
- [Kubernetes Security - That DevOps Guy](https://www.youtube.com/watch?v=VjlvS-qiz_U) - K8s security (34m 16s)
- [DevSecOps Tutorial - freeCodeCamp](https://www.youtube.com/watch?v=nrhxNNH5lt0) - Security integration (2h 44m)

**Secrets Management:**
- [Managing Secrets in Docker - TechWorld with Nana](https://www.youtube.com/watch?v=jtSZAJ-wYBk) - Docker secrets (18m 23s)
- [Kubernetes Secrets Management - DevOps Toolkit](https://www.youtube.com/watch?v=iTG2mJyxG0Y) - K8s secrets (22m 47s)

---

### Learning Path Recommendations

**Beginner Path (0-3 months):**
1. Docker Fundamentals → Docker Compose
2. Python Basics → FastAPI
3. Git & GitHub basics
4. PostgreSQL & SQLAlchemy
5. pytest fundamentals

**Intermediate Path (3-6 months):**
1. Kubernetes & K3s
2. CI/CD with GitHub Actions
3. TypeScript & React.js
4. Advanced testing strategies
5. Monitoring & logging

**Advanced Path (6-12 months):**
1. Microservices architecture
2. Service mesh & Istio
3. Advanced K8s patterns
4. Performance optimization
5. Security best practices

**Recommended Channels to Subscribe:**
- **TechWorld with Nana** - DevOps, Kubernetes, Docker
- **Fireship** - Quick tech overviews and trends
- **freeCodeCamp** - Comprehensive programming courses
- **Programming with Mosh** - Software development tutorials
- **ArjanCodes** - Python best practices and design patterns
- **Traversy Media** - Web development tutorials
- **NetworkChuck** - Networking and DevOps
- **TechnoTim** - Homelab and self-hosting
- **LearnLinuxTV** - Linux and open source

---

**Document Maintenance:** This document should be reviewed and updated quarterly or when major technology decisions are made.

**Last Review:** November 16, 2025
**Next Review:** February 16, 2026
