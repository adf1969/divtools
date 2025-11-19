# dthostmon - DivTools Host Monitor

**Version:** 1.0.0 | **Status:** Phase 1 (MVP)

A cron-based system monitoring application with AI-powered log analysis, change detection, and automated alerting. Monitors remote hosts via SSH, analyzes logs using LLM models (Grok/Ollama), and sends email alerts for anomalies and critical issues.

## Features

### Phase 1 (Current - MVP)
✅ **SSH-Based Log Retrieval** - Securely retrieve logs from remote hosts without agents  
✅ **AI-Powered Analysis** - Grok and Ollama integration for intelligent log analysis  
✅ **Change Detection** - Baseline comparison to detect configuration and log changes  
✅ **Email Alerts** - HTML-formatted alerts with health scores and recommendations  
✅ **Host & Site Reports** - Markdown reports with comprehensive system analysis  
✅ **Hierarchical Configuration** - Global/Site/Host override pattern for report frequencies  
✅ **REST API** - Read-only API for querying monitoring results  
✅ **PostgreSQL Storage** - Persistent storage of baselines, results, and history  
✅ **Docker Deployment** - Containerized with K3s readiness  
✅ **Concurrent Monitoring** - Process multiple hosts simultaneously  

### Coming Soon
🔄 **Phase 1.5** - Write API, Pushover alerts, remote host self-registration  
🔄 **Phase 2** - Web UI dashboard with review tracking and comments  
🔄 **Phase 3** - Prometheus, InfluxDB, Glances integration  
🔄 **Phase 4** - Advanced AI features, predictive alerting, trend analysis  

## Quick Start

### Prerequisites
- Docker and Docker Compose
- PostgreSQL 12+ (at 10.1.1.74:5432 or customize)
- SSH key for remote host access
- Email SMTP server for alerts
- **OpenCode CLI** with at least one authenticated AI provider (see setup below)

### AI Model Setup (New with OpenCode Server)

dthostmon uses OpenCode Server for unified AI access. No individual API keys needed!

**Setup on Host (one-time):**
```bash
# Install OpenCode CLI
curl -L https://get.opencode.ai/linux | bash

# Authenticate with your preferred AI provider(s)
opencode auth login
# Choose: Grok, OpenAI, Anthropic, Ollama, or others
# Enter your API key when prompted

# Verify setup
opencode auth list
opencode models
```

That's it! Docker container automatically uses your authenticated providers.

For detailed setup instructions, see [OPENCODE_SETUP.md](OPENCODE_SETUP.md)

### Installation

1. **Clone and configure:**
```bash
cd /opt/divtools/projects/dthostmon
cp .env.example .env
# Note: No API keys needed in .env anymore - OpenCode handles authentication
nano .env
```

2. **Configure monitored hosts:**
```bash
nano config/dthostmon.yaml
# Add your hosts in the 'hosts' section
```

3. **Build and start:**
```bash
docker compose up -d
```

4. **Initialize database:**
```bash
docker exec dthostmon python3 src/dthostmon_cli.py monitor --init-db
```

5. **Test SSH connectivity:**
```bash
docker exec dthostmon python3 src/dthostmon_cli.py setup
```

### Usage

**Run single monitoring cycle:**
```bash
docker exec dthostmon python3 src/dthostmon_cli.py monitor
```

**Review configuration:**
```bash
docker exec dthostmon python3 src/dthostmon_cli.py config
```

**Access API:**
```bash
curl -H "X-API-Key: your_api_key" http://localhost:8080/health
curl -H "X-API-Key: your_api_key" http://localhost:8080/hosts
```

**API Documentation:**  
Open http://localhost:8080/docs in your browser for interactive API docs.

## Configuration

### Environment Variables (.env)
```env
DB_HOST=10.1.1.74
DB_PORT=5432
DB_NAME=dthostmon
DB_USER=dthostmon
DB_PASSWORD=your_password

SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=alerts@example.com
SMTP_PASSWORD=your_smtp_password

GROK_API_KEY=your_grok_key
OLLAMA_HOST=http://10.1.1.75:11434

SSH_KEY_PATH=/opt/dthostmon/.ssh/id_ed25519
API_KEY=your_random_api_key
```

### Monitored Hosts (config/dthostmon.yaml)
```yaml
# Global report configuration
global:
  report_frequency: daily  # Options: hourly, daily, weekly
  resource_thresholds:
    health: "0-30"      # Green ✅ (0-30% usage)
    info: "31-60"       # Blue ℹ️ (31-60% usage)
    warning: "61-89"    # Yellow ⚠️ (61-89% usage)
    critical: "90-100"  # Red 🚨 (90-100% usage)

# Site-specific configuration (optional)
sites:
  s01-chicago:
    report_frequency: weekly  # Override global
    resource_thresholds:
      health: "0-25"  # Stricter thresholds for production

# Monitored hosts
hosts:
  - name: webserver-1
    hostname: 192.168.1.100
    port: 22
    user: monitoring
    enabled: true
    site: s01-chicago          # Group into site
    report_frequency: daily     # Override site/global
    logs:
      - /var/log/syslog
      - /var/log/auth.log
      - /var/log/nginx/error.log
    tags:
      - production
      - webserver
      - nginx
```

### Automatic Configuration Sync (NEW!)

Automatically synchronize your monitoring configuration from existing divtools Docker infrastructure:

```bash
# Preview what will be synced
./scripts/dthostmon_sync_config.sh -test

# Sync configuration from $DIVTOOLS/docker/sites
./scripts/dthostmon_sync_config.sh

# With debug output
./scripts/dthostmon_sync_config.sh -debug

# Example file generation
You can use the sync script to create example YAML/ENV files for sites or hosts:

```
# Generate example host YAML to stdout
./scripts/dthostmon_sync_config.sh -yaml-ex -

# Scaffold example env files for all hosts under the sites directory
./scripts/dthostmon_sync_config.sh -env-exh -sites-dir $DIVTOOLS/docker/sites

Note: `-test` performs validation of the generated configuration and will exit with a non-zero code if errors are found; use `-debug` to see validation details.
```
```

**Configuration Sources:**
1. **Folder Structure** - Auto-discover sites/hosts from `$DOCKER_SITES_DIR`
2. **ENV Variables** - Read `DTHM_*` variables from `.env.*` files
3. **YAML Files** - Read structured config from `dthm-*.yaml` files

**Example:**
```bash
# In your Docker infrastructure
$DIVTOOLS/docker/sites/
├── s01-prod/
│   ├── .env.s01-prod           # Site config via ENV vars
│   ├── db01/
│   │   ├── .env.db01          # DTHM_HOST_HOSTNAME=10.1.1.10
│   │   │                      # DTHM_HOST_TAGS=database,postgresql
│   │   └── dthm-host.yaml     # Advanced monitoring settings
│   └── web01/
│       └── .env.web01
└── s02-dev/
    └── devbox/
        └── .env.devbox

# Run sync to update dthostmon.yaml automatically
cd /path/to/dthostmon
./scripts/dthostmon_sync_config.sh
```

📖 **Full Documentation:** See [`docs/CONFIG-SYNC.md`](docs/CONFIG-SYNC.md) for complete guide with all ENV variables and examples.

### Report Features

**Host Reports** - Individual system analysis with:
- Critical issues highlighted at top
- System health metrics (CPU, Memory, Disk) with status indicators
- System changes (command history, package installs, file modifications)
- Log analysis (syslog, application logs, docker containers)
- AI-powered analysis and recommendations

**Site Reports** - Aggregate analysis across multiple hosts:
- Critical items grouped by host
- Site overview statistics (healthy/warning/critical counts)
- Systems with recent changes
- Resource usage table sorted by worst resource
- Storage highlights for hosts near capacity

**Email Delivery** - Markdown reports sent as attachments:
- Hierarchical frequency: Host > Site > Global override
- Customizable thresholds per site or globally
- Daily, weekly, or hourly scheduling
- Proper attachment formatting for all email clients

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    dthostmon Container                    │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ┌────────────┐        ┌──────────────┐                  │
│  │    Cron    │───────>│ Orchestrator │                  │
│  │  Scheduler │        │              │                  │
│  └────────────┘        └──────┬───────┘                  │
│                               │                           │
│         ┌─────────────────────┼───────────────┐          │
│         │                     │               │          │
│    ┌────▼────┐          ┌────▼────┐     ┌───▼────┐      │
│    │   SSH   │          │   AI    │     │ Email  │      │
│    │  Client │          │Analyzer │     │ Alert  │      │
│    └────┬────┘          └────┬────┘     └───┬────┘      │
│         │                    │              │           │
│         └────────────────────┴──────────────┘           │
│                              │                           │
│                     ┌────────▼────────┐                  │
│                     │   PostgreSQL    │ (External)       │
│                     │     Database    │                  │
│                     └─────────────────┘                  │
│                                                            │
│  ┌──────────────────────────────────────────────┐        │
│  │              FastAPI REST API                 │        │
│  │         (Port 8080 - Read-Only)               │        │
│  └──────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────┘
```

## Development

### Running Tests
```bash
# All tests
pytest

# Unit tests only
pytest tests/unit/

# With coverage
pytest --cov=src/dthostmon --cov-report=html

# Specific test file
pytest tests/unit/test_config.py -v
```

### Development Setup
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements-dev.txt

# Run linting
flake8 src/dthostmon
pylint src/dthostmon
black --check src/dthostmon

# Format code
black src/dthostmon
```

### Project Structure
```
dthostmon/
├── src/dthostmon/          # Application source code
│   ├── core/               # Core modules (SSH, AI, orchestrator)
│   ├── api/                # FastAPI REST API
│   ├── models/             # Database models
│   └── utils/              # Utilities (config, logging)
├── tests/                  # Test suite
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── fixtures/           # Test fixtures
├── config/                 # Configuration files
├── docs/                   # Documentation (PRD, PROJECT-HISTORY)
├── dthostmon.Dockerfile    # Docker image definition
├── dca-dthostmon.yml       # Docker Compose configuration
├── requirements.txt        # Python dependencies
└── pytest.ini              # Test configuration
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/hosts` | List all monitored hosts |
| GET | `/hosts/{id}` | Get specific host info |
| GET | `/results/{host_id}` | Get monitoring results for host |
| GET | `/results/{host_id}/latest` | Get latest result for host |
| GET | `/changes/{run_id}` | Get detected changes for run |
| GET | `/logs/{run_id}` | Get log entries for run |
| GET | `/history/{host_id}` | Get monitoring history |

**Authentication:** All endpoints require `X-API-Key` header.

## Monitoring Workflow

1. **Cron triggers monitoring cycle** (default: every hour)
2. **Orchestrator processes hosts concurrently** (5 at a time)
3. **SSH client retrieves logs** from each host
4. **Compare with baseline** to detect changes
5. **AI analyzer reviews logs** for anomalies
6. **Results saved to database**
7. **Email alerts sent** if severity is WARN/CRITICAL
8. **API exposes results** for external queries

## Troubleshooting

**SSH Connection Failures:**
```bash
# Verify SSH key permissions
ls -l ~/.ssh/id_ed25519  # Should be 600

# Test manual SSH
ssh -i ~/.ssh/id_ed25519 user@hostname

# Run setup check
docker exec dthostmon python3 src/dthostmon_cli.py setup
```

**Database Connection Issues:**
```bash
# Test PostgreSQL connectivity
psql -h 10.1.1.74 -U dthostmon -d dthostmon -c "SELECT 1"

# Check database logs
docker logs dthostmon
```

**Email Alerts Not Sending:**
```bash
# Check SMTP settings in .env
# Verify firewall allows SMTP traffic
# Test SMTP manually:
python3 -c "import smtplib; smtplib.SMTP('smtp.example.com', 587).starttls()"
```

## Contributing

See [TESTING.md](TESTING.md) for test guidelines and [docs/PRD.md](docs/PRD.md) for feature roadmap.

## License

Proprietary - DivTools Infrastructure

## Support

For issues or questions, refer to:
- **PRD:** [docs/PRD.md](docs/PRD.md)
- **Project History:** [docs/PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md)
- **Test Documentation:** [TESTING.md](TESTING.md)
