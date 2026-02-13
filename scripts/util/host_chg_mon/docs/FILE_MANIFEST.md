# Host Monitoring Solution - File Manifest

## Quick Reference

All host monitoring solution files are located in:
- **Main scripts:** `/home/divix/divtools/scripts/util/host_chg_mon/`
- **Main Python app:** `/home/divix/divtools/scripts/util/mcp_host_monitor.py`
- **Architecture guides:** `/home/divix/divtools/scripts/util/*.md`
- **Configuration template:** `/home/divix/divtools/config/mcp_monitoring.yaml.example`

## Complete File Listing

### Core Bash Scripts

#### `host_change_log.sh` (17 KB)
**Purpose:** Initial host setup and monitoring infrastructure configuration
**What it does:**
- Configures bash history for persistence (HISTSIZE=10000, HISTFILESIZE=20000)
- Creates monitoring directory structure at `/var/log/divtools/monitor`
- Sets up symlinks to system logs (auth, syslog, security logs)
- Calculates Docker configuration checksums
- Creates cron job for periodic change verification
- Initializes audit log files

**How to use:**
```bash
cd /home/divix/divtools/scripts/util/host_chg_mon
./host_change_log.sh setup          # Run on target host
./host_change_log.sh status         # Check current status
./host_change_log.sh verify         # Verify all changes
```

**Key Dependencies:** jq, curl, standard Linux tools (journalctl, dpkg, docker, etc.)

---

#### `host_change_analyzer.sh` (20 KB)
**Purpose:** Autonomous host analysis using local Ollama LLM
**What it does:**
- Detects and verifies Ollama service on host
- Collects changes from multiple sources (history, apt logs, docker, security logs)
- Sends change batch to local LLM for analysis
- Parses JSON response for severity classification
- Writes timestamped audit log entries
- Provides report viewing and status checking

**How to use:**
```bash
cd /home/divix/divtools/scripts/util/host_chg_mon
./host_change_analyzer.sh analyze   # Collect and analyze changes
./host_change_analyzer.sh status    # Show analysis status
./host_change_analyzer.sh report    # Display audit log report
./host_change_analyzer.sh history   # View historical analyses
```

**Key Dependencies:** Ollama service running locally, jq, curl, journalctl

**Supported Models:** llama3.2, mistral, phi3, llama3.1 (see LOCAL_LLM_GUIDE.md for recommendations)

---

#### `example_n8n_checks.sh` (14 KB)
**Purpose:** Collection of monitoring commands for n8n integration
**What it does:**
- Provides modular check commands for n8n workflow nodes
- Formats output as JSON for n8n HTTP nodes
- Covers: APT updates, Docker changes, User logins, Log files, Network changes
- Includes example cURL commands for integration
- Documents expected JSON response formats

**How to use:**
```bash
cd /home/divix/divtools/scripts/util/host_chg_mon
# Call individual check functions from n8n HTTP nodes:
source ./example_n8n_checks.sh
check_apt_updates       # Returns JSON
check_docker_changes    # Returns JSON
check_user_logins       # Returns JSON
check_log_changes       # Returns JSON
check_network_changes   # Returns JSON
```

**Key Dependencies:** Standard Linux tools, jq for JSON output

---

### Python MCP Application

#### `mcp_host_monitor.py` (17 KB)
**Location:** `/home/divix/divtools/scripts/util/mcp_host_monitor.py`

**Purpose:** Python-based monitoring application using Model Context Protocol for standardized integration

**What it does:**
- Loads host configurations from YAML file
- Manages credentials securely (environment vars, encrypted files, OS keychain)
- Connects to configured MCPs (SSH, Config, Slack, Filesystem, etc.)
- Collects changes concurrently across multiple hosts
- Sends batches to Claude API for intelligent analysis
- Writes audit logs with severity classification
- Provides CLI interface for analysis, reporting, and history

**How to use:**
```bash
cd /home/divix/divtools/scripts/util
python3 mcp_host_monitor.py --config config/mcp_monitoring.yaml.example --all
python3 mcp_host_monitor.py --analyze
python3 mcp_host_monitor.py --report
python3 mcp_host_monitor.py --history 24h
python3 mcp_host_monitor.py --test
```

**Key Features:**
- Async/await for concurrent host operations
- Structured logging with severity levels
- JSON response parsing from Claude
- YAML configuration loading with validation
- Credential manager supporting 4+ storage strategies
- Built-in test mode for validation

**Key Dependencies:**
```
anthropic>=0.7.0
pyyaml>=6.0
asyncio (stdlib)
json (stdlib)
```

**Configuration:** See `config/mcp_monitoring.yaml.example`

---

### Configuration Files

#### `config/mcp_monitoring.yaml.example` (110+ lines)
**Location:** `/home/divix/divtools/config/mcp_monitoring.yaml.example`

**Purpose:** Fully annotated YAML configuration template for mcp_host_monitor.py

**Sections:**
- **MCPs:** Server configurations for SSH, Config, Slack, Filesystem
- **Hosts:** Host definitions with criticality levels and check intervals
- **Monitoring:** Change collection settings and check frequency
- **LLM:** Provider, model, temperature, and max tokens
- **Notifications:** Slack and email notification settings
- **Audit:** Log location, retention, and formatting
- **Analysis:** Severity thresholds and check types
- **Security:** Credential strategies and encryption options

**How to use:**
1. Copy to `/home/divix/divtools/config/mcp_monitoring.yaml`
2. Edit to add your hosts and MCPs
3. Configure credentials according to chosen strategy
4. Reference in mcp_host_monitor.py invocations

---

### Documentation

#### Architecture & Design Guides

##### `MCP_ARCHITECTURE_GUIDE.md` (25 KB)
**Location:** `/home/divix/divtools/scripts/util/MCP_ARCHITECTURE_GUIDE.md`

**Content:**
- Comprehensive explanation of Model Context Protocol
- 100+ MCP clients evaluated and categorized
- Required MCPs for monitoring (SSH, Config, Slack, Filesystem)
- Complete Python code examples with explanations
- Credential management patterns (4+ strategies)
- Resource requirements and performance considerations
- Troubleshooting guide
- Integration with Anthropic Claude API

**Key Sections:**
1. What is MCP? (Definition, benefits, comparison to alternatives)
2. MCP Clients (Cline, mcp-use, fast-agent, VS Code Copilot, Continue, mcp-agent, etc.)
3. Required MCPs for monitoring
4. Complete Python implementation
5. Credential management patterns
6. Performance and scaling

---

##### `MCP_QUICK_START.md` (13 KB)
**Location:** `/home/divix/divtools/scripts/util/MCP_QUICK_START.md`

**Content:**
- Executive summary of all three solutions
- Decision framework for choosing approach
- Quick-start paths for each solution
- File organization and location guide
- Architecture diagrams
- Getting started in 5 minutes

**Best for:** Making a quick decision and starting immediately

---

#### Solution-Specific Guides

##### `LOCAL_LLM_GUIDE.md` (16 KB)
**Location:** `/home/divix/divtools/scripts/util/host_chg_mon/LOCAL_LLM_GUIDE.md`

**Content:**
- Complete Ollama setup instructions
- Model recommendations (phi3, llama3.2, mistral, llama3.1)
- Resource requirements per model
- Performance benchmarks
- Integration with host_change_analyzer.sh
- Prompt optimization
- Troubleshooting guide

**Best for:** Choosing local LLM approach and optimizing Ollama

---

##### `N8N_MONITORING_GUIDE.md` (8 KB)
**Location:** `/home/divix/divtools/scripts/util/host_chg_mon/N8N_MONITORING_GUIDE.md`

**Content:**
- n8n workflow setup instructions
- HTTP node configuration examples
- Webhook integration patterns
- Database node setup for audit logging
- Slack/email notification nodes
- Scheduling and error handling
- Example workflows

**Best for:** Choosing n8n centralized approach

---

#### Comparison & Planning

##### `SOLUTION_COMPARISON.md` (11 KB)
**Location:** `/home/divix/divtools/scripts/util/host_chg_mon/SOLUTION_COMPARISON.md`

**Content:**
- Side-by-side feature matrix of three solutions
- Pros and cons for each approach
- Cost comparison (infrastructure, maintenance)
- Complexity assessment
- Scalability characteristics
- Security considerations
- Decision matrix with use case recommendations

**Best for:** Evaluating all options and choosing the best fit

---

##### `QUICKSTART.md` (9 KB)
**Location:** `/home/divix/divtools/scripts/util/host_chg_mon/QUICKSTART.md`

**Content:**
- 5-minute quick start for each solution
- Copy-paste setup commands
- Minimal configuration
- Testing and validation
- Next steps after initial setup

**Best for:** Getting started immediately with minimal setup

---

##### `HOST_MONITORING_README.md` (12 KB)
**Location:** `/home/divix/divtools/scripts/util/host_chg_mon/HOST_MONITORING_README.md`

**Content:**
- Overview of entire monitoring architecture
- What gets monitored (apt, docker, history, logs)
- How each solution works
- Architecture diagrams
- Data flow explanations
- Common use cases

**Best for:** Understanding the big picture

---

## Directory Structure

```
/home/divix/divtools/
├── config/
│   ├── mcp_monitoring.yaml.example          ← Configuration template
│   ├── frigate/
│   ├── monitor/
│   ├── starship/
│   ├── syncthing/
│   ├── telegraf/
│   ├── tmux/
│   └── unbound/
│
├── scripts/
│   ├── util/
│   │   ├── mcp_host_monitor.py              ← Main Python MCP app
│   │   ├── MCP_ARCHITECTURE_GUIDE.md        ← MCP comprehensive guide
│   │   ├── MCP_QUICK_START.md              ← MCP quick start
│   │   ├── logging.sh                       ← Logging utilities
│   │   ├── host_chg_mon/
│   │   │   ├── host_change_log.sh          ← Host setup script
│   │   │   ├── host_change_analyzer.sh     ← Local LLM analyzer
│   │   │   ├── example_n8n_checks.sh       ← n8n command examples
│   │   │   ├── FILE_MANIFEST.md            ← This file
│   │   │   ├── HOST_MONITORING_README.md   ← Overview
│   │   │   ├── QUICKSTART.md               ← 5-min quick start
│   │   │   ├── LOCAL_LLM_GUIDE.md          ← Ollama setup
│   │   │   ├── N8N_MONITORING_GUIDE.md     ← n8n integration
│   │   │   ├── SOLUTION_COMPARISON.md      ← Feature comparison
│   │   │   └── QUICKSTART.md               ← Minimal setup
│   │   └── [other utilities]
│   │
│   ├── [other scripts]
│   └── frigate/, pbs/, pve/, etc.
│
└── [other divtools directories]
```

## Which File Should I Read First?

### If you want to make a quick decision:
1. **MCP_QUICK_START.md** (5 min) - Decision tree and quick start options
2. **SOLUTION_COMPARISON.md** (5 min) - Feature matrix
3. Choose solution and follow its quick start path

### If you want MCP-based solution (RECOMMENDED):
1. **MCP_QUICK_START.md** (5 min) - Get overview
2. **MCP_ARCHITECTURE_GUIDE.md** (15 min) - Understand MCPs
3. **mcp_host_monitor.py** (10 min) - Review code
4. **config/mcp_monitoring.yaml.example** (5 min) - Configure
5. Run: `python3 mcp_host_monitor.py --config config/mcp_monitoring.yaml --all`

### If you want Local LLM solution:
1. **QUICKSTART.md** (5 min) - Minimal setup
2. **LOCAL_LLM_GUIDE.md** (15 min) - Ollama optimization
3. **host_change_analyzer.sh** (10 min) - Review code
4. Run: `./host_chg_mon/host_change_analyzer.sh analyze`

### If you want n8n solution:
1. **QUICKSTART.md** (5 min) - Minimal setup
2. **N8N_MONITORING_GUIDE.md** (10 min) - Workflow setup
3. **example_n8n_checks.sh** (5 min) - Review commands
4. Create n8n workflow using provided examples

## Key Statistics

| Solution | Files | Language | Complexity | Recommended For |
|----------|-------|----------|-----------|-----------------|
| MCP-Based | 3 (py, yaml, docs) | Python | Medium | Code-driven, AI-friendly, scalable |
| Local LLM | 2 (sh, docs) | Bash | Low | Simple, autonomous, no dependencies |
| n8n | 2 (sh, docs) | Bash + GUI | Low-High | Visual workflows, centralized |

## Getting Help

Each file contains inline documentation:
- Bash scripts: Comments explain each section
- Python code: Docstrings and inline comments
- YAML config: Extensive annotations
- Markdown guides: Full explanations and examples

## Next Steps

1. **Read:** MCP_QUICK_START.md or HOST_MONITORING_README.md
2. **Choose:** One of three solutions based on your needs
3. **Configure:** Copy template and edit with your hosts
4. **Deploy:** Follow solution-specific quick start
5. **Verify:** Run test mode or report command
6. **Automate:** Add to cron for continuous monitoring

## File Sizes & Checksums

For quick reference:
- `host_change_log.sh`: ~17 KB
- `host_change_analyzer.sh`: ~20 KB
- `example_n8n_checks.sh`: ~14 KB
- `mcp_host_monitor.py`: ~17 KB
- `mcp_monitoring.yaml.example`: ~110 lines (~5 KB)
- Documentation: ~100 KB total across 8 files

**Total Package Size:** ~200 KB (very lightweight, can be deployed on any host)

---

**Last Updated:** 2024
**Status:** Production-ready
**Support:** See individual file comments for troubleshooting
