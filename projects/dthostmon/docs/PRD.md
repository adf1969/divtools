# Product Requirements Document (PRD) - System Monitoring and Analysis Application

## Overview
**Product Name:** dthostmon (DivTools Host Monitor)

**Version:** 1.0.0

**Date:** November 13, 2025

**Author:** OpenCode CLI Agent

## Executive Summary
A cron-job based system monitoring application that uses LLM-powered analysis to review system status, detect changes, and report findings via email. The application connects to remote systems via SSH, pulls log data, and integrates with monitoring systems (Prometheus, InfluxDB, Glances) for comprehensive system health analysis.

## Goals and Objectives
- **Primary Goal:** Automated system monitoring with intelligent analysis and email reporting
- **Secondary Goals:**
  - Early detection of system issues and changes
  - Centralized monitoring across multiple remote systems
  - AI-powered log analysis and anomaly detection
  - Cron-based automation with minimal human intervention

## Target Audience
- System administrators
- DevOps engineers
- IT operations teams
- Infrastructure monitoring teams

## Technical Requirements

### Core Architecture
**Language:** Python 3.11+

**Database Type:** PostgreSQL 12+ (host: 10.1.1.74:5432)

**AI Model Integration:** OpenCode Server with Multi-Model Support
  - Primary: Grok Code Fast 1 (via OpenCode)
  - Fallback: Anthropic Claude 3.5 Sonnet
  - Fallback: OpenAI GPT-4
  - Local: Ollama llama3.1
  - Server: OpenCode Server running in headless mode (port 4096)
  - Auth: ~/.local/share/opencode/auth.json credentials copied from host to container
  - Configuration: Managed by `opencode auth login` on host, automatically available to container

**Operating Agent:** Python-based monitoring service with OpenCode Server integration

**Deployment Platform:** Docker Container (K3s-ready)
  Base Image: python:3.11-slim
  System Dependencies: postgresql-client, openssh-client, curl (for OpenCode installation)
  Services in Container:
    - OpenCode Server (headless, port 4096)
    - Monitor worker (scheduled or cron-based)
    - REST API server (FastAPI/Flask on port 8080)
    - Health check endpoint
  
**Volume Mounts:**
  Config Volume:
    Host: /opt/dthostmon/config/
    Container: /opt/dthostmon/config/ (read-write for live reload)
  Logs Volume:
    Host: /opt/dthostmon/logs/
    Container: /opt/dthostmon/logs/
  Web UI Configuration Volume (Phase 5+):
    Host: /opt/dthostmon/webui-config/
    Container: /opt/dthostmon/webui-config/ (read-write for live persistence)

**Exposed Ports:**
  8080: REST API and future Web UI dashboard

**Container Orchestration:**
  Development: docker compose up
  Production/HA: K3s Deployment with health checks and restart policy

### System Integration

#### Remote System Access
- **SSH Connection:** Secure remote access to target systems
- **Authentication:** SSH key-based authentication
- **Multi-host Support:** Concurrent monitoring of multiple systems

#### Monitoring Data Sources
- **Log Files:** System logs, application logs, security logs
- **Prometheus:** Metrics collection and querying
- **InfluxDB:** Time-series data storage and retrieval
- **Glances:** Real-time system monitoring (CPU, memory, disk, network)

#### AI Integration - OpenCode Server Architecture
**Design Decision:** Use OpenCode Server in headless mode to enable multi-model AI analysis without managing individual API keys.

**How It Works:**
1. OpenCode CLI installed in Docker container and runs headless server (`opencode serve --port 4096`)
2. Authentication credentials pre-configured on host (`opencode auth login` for each provider)
3. Credentials stored in `~/.local/share/opencode/auth.json` on host
4. Docker container mounts auth file read-only to `/root/.local/share/opencode/auth.json`
5. dthostmon application calls OpenCode Server REST API endpoints to send prompts
6. OpenCode Server routes requests to authenticated models based on availability

**Benefits:**
- Single credential management point (host-level authentication)
- Supports any model that OpenCode supports (no code changes needed to add models)
- Automatic fallback between multiple AI providers
- No direct API key exposure in application code or config files
- Works offline for local models (Ollama) when remote APIs unavailable

**Supported Models (via OpenCode):**
- Grok Code Fast 1 (primary, via x.ai)
- Anthropic Claude 3.5 Sonnet (fallback)
- OpenAI GPT-4 (fallback)
- Ollama llama3.1 (local fallback, no internet needed)

**API Endpoints Used:**
- `GET /config/providers` - List available authenticated models
- `POST /session` - Create analysis session
- `POST /session/:id/message` - Send prompt to specific model

- **Analysis Capabilities:**
  - Log anomaly detection
  - System health assessment
  - Change impact analysis
  - Predictive alerting

### Configuration Management

#### Configuration File Structure
**Primary Config File:** `config/dthostmon.yaml`

```yaml
# Example configuration structure
dthostmon:
  version: "1.0.0"
  monitoring:
    interval: 3600  # seconds
    timeout: 300    # seconds
    max_concurrent_hosts: 5

  hosts:
    - name: "web-server-01"
      hostname: "192.168.1.100"
      ssh_key: "~/.ssh/id_rsa"
      user: "monitor"
      log_paths:
        - "/var/log/syslog"
        - "/var/log/auth.log"
      prometheus_url: "http://localhost:9090"
      influxdb_url: "http://localhost:8086"
      glances_port: 61208

  alerting:
    smtp_server: "smtp.gmail.com"
    smtp_port: 587
    smtp_user: "alerts@company.com"
    smtp_password: "${SMTP_PASSWORD}"
    recipients:
      - "admin@company.com"
      - "ops@company.com"
    thresholds:
      cpu_warning: 80
      memory_warning: 85
      disk_warning: 90

  ai:
    model: "gpt-4"
    api_key: "${OPENAI_API_KEY}"
    temperature: 0.3
    max_tokens: 2000
    analysis_prompts:
      log_analysis: "Analyze these logs for anomalies..."
      system_health: "Assess overall system health..."

  database:
    type: "postgresql"
    host: "10.1.1.74"
    port: 5432
    name: "dthostmon"
    user: "dthostmon"
    password: "${DB_PASSWORD}"
    retention_days: 30
```

**Environment Variables:**
- `DB_PASSWORD`: PostgreSQL dthostmon user password (default: `1114-Avcdth`)
- `SMTP_PASSWORD`: Email server password
- `OPENAI_API_KEY`: AI model API key
- `SSH_PRIVATE_KEY`: SSH private key content
- `INFLUXDB_TOKEN`: InfluxDB authentication token

### Functional Requirements

#### Core Features
1. **Automated Monitoring**
   - Cron job execution
   - Configurable monitoring intervals
   - Parallel host processing

2. **Data Collection**
   - SSH-based log file retrieval
   - Prometheus metrics querying
   - InfluxDB data extraction
   - Glances real-time data capture

3. **AI-Powered Analysis**
   - Log anomaly detection
   - System health scoring
   - Change detection and impact analysis
   - Predictive alerting

4. **Reporting and Alerting**
   - HTML email reports
   - Severity-based alerting ([INFO], [WARN], [CRITICAL])
   - Historical trend analysis
   - Custom report templates

#### User Interface
- **CLI Interface:** Command-line operation for manual runs
- **Configuration:** YAML-based configuration management
- **Logging:** Structured logging with configurable levels
- **Status Output:** Real-time progress and error reporting

### Detailed Requirements List

The following table outlines the specific functional, non-functional, and system requirements for the dthostmon application. See **Open Questions** section below for outstanding decisions that will determine which Phase certain requirements will be implemented in.

When a Requirement has been implemented, add the implementation files to the final column labled "Implementation Files". The files added should indicate the relative path of each from the dthostmon project folder so they can be easily located.

| Requirement ID | Phase | Description | User Story | Expected Behavior/Outcome | Implementation Files |
|---|---|---|---|---|---|
| **FR-INIT-001** | 1 | **Initial Setup** | As an systems administrator, I want the installation and setup of the application to be simple and easy to deploy | System can be setup by calling a simple setup script `setup.sh` that provides user feedback and checks for pre-existing installed steps prior to re-installing. Setup outputs the setup choices to a date-stamped log file for review, as well as logs any errors and output to a log file. As the setup script executes, it checks for the status of the system prior to each next step, asking the user at each step if it should proceed to the next. Defaults are provided for each step. At any time, the user can cancel setup. Restarting the Setup later will not re-install or re-run steps that have already been executed unless the user requests to re-run a prior step. The Setup script doesn't record the steps, but determines the necessity of running a step based upon the system conditions would require it. | `setup.sh` |
| **FR-CORE-001** | 1 | **Automated Cron Job Execution** | As an administrator, I want the monitoring to run automatically on a schedule so I don't have to manually trigger it. | System executes monitoring cycle at configured intervals (e.g., every hour) without manual intervention. Successful runs are logged, failures trigger retry logic. | `dca-dthostmon.yml`, `docker-entrypoint.sh` |
| **FR-CORE-002** | 1 | **Multi-Host Concurrent Processing** | As an operations team managing 50+ hosts, I want monitoring to run in parallel so the total monitoring window stays under 5 minutes. | System connects to and monitors multiple hosts concurrently (up to 10 simultaneous). Each host is processed independently. If one fails, others continue. | `src/dthostmon/core/orchestrator.py` |
| **FR-SSH-001** | 1 | **SSH-Based Remote Log Retrieval** | As a system administrator, I want to securely retrieve logs from remote systems without installing agents. | System connects via SSH key authentication to target host, retrieves specified log files, and returns full log contents with integrity verification (checksums). Connection timeout is 10 seconds. | `src/dthostmon/core/ssh_client.py` |
| **FR-SSH-002** | 1 | **SSH Connection Error Handling** | As an operations engineer, I want clear alerts when a host becomes unreachable. | System attempts 3 SSH connections with exponential backoff (1s, 2s, 4s). After 3 failures, system logs the error and moves to next host. Alert is sent if the same host fails 3 times consecutively. | `src/dthostmon/core/ssh_client.py` |
| **FR-PROM-001** | 3 | **Prometheus Metrics Integration** | As a DevOps engineer, I want system metrics from Prometheus included in the analysis. | System queries Prometheus API for CPU, memory, disk, and network metrics for the past 1 hour. Results are included in AI analysis along with logs. | _Phase 3 - Not Yet Implemented_ |
| **FR-PROM-002** | 3 | **Custom Metric Queries** | As a user, I want to define custom Prometheus queries for my specific applications. | Configuration supports custom metric definitions. System evaluates queries and includes results in analysis. Query execution timeout is 30 seconds. | _Phase 3 - Not Yet Implemented_ |
| **FR-INFLUX-001** | 3 | **InfluxDB Time-Series Data** | As a monitoring specialist, I want historical time-series data included in trend analysis. | System queries InfluxDB for 7 days of historical data (configurable). Data is downsampled if needed. Results show trends (increasing memory usage, disk growth, etc.). | _Phase 3 - Not Yet Implemented_ |
| **FR-GLANCES-001** | 3 | **Real-Time System Monitoring** | As an operations team, I want real-time CPU, memory, and disk metrics at monitoring time. | System connects to Glances API on target host, retrieves current metrics, and includes in analysis and alert payload. Connection timeout is 5 seconds. | _Phase 3 - Not Yet Implemented_ |
| **FR-ANALYSIS-001** | 1 | **AI Log Anomaly Detection** | As a security administrator, I want unusual log entries automatically detected and flagged. | System sends logs to configured LLM with structured prompt including system context. LLM identifies anomalies (failed logins, permission errors, service crashes, etc.). Results include severity and recommended action. | `src/dthostmon/core/ai_analyzer.py` |
| **FR-ANALYSIS-002** | 1 | **System Health Scoring** | As a CTO reviewing infrastructure, I want a simple health score (0-100) for each system. | System analyzes logs and metrics, produces health score. Score 90-100 = healthy, 70-89 = issues present but minor, <70 = critical attention needed. Reasons for score are provided. | `src/dthostmon/core/ai_analyzer.py`, `src/dthostmon/models/database.py` |
| **FR-ANALYSIS-003** | 1 | **Change Detection** | As a compliance officer, I want to know when system configurations change. | System compares current logs/metrics against baseline from previous run. Detects new users, service changes, file modifications. Categorizes as expected or unexpected. | `src/dthostmon/core/orchestrator.py`, `src/dthostmon/models/database.py` |
| **FR-ANALYSIS-004** | 1 | **Host Report** | As a systems administrator, I want reports showing the status of a system with critical items highlighted and other non-critical items documented. | System produces a Host Status Report for each host in Markdown that reports the general status of the system, include changes made to the system from history logs, apt logs, filesystem review showing increase/decreased drive usage and why. Includes a review of all log files from syslog as well as /var/log log files. Includes a review of the log files of any running docker containers. The report highlights any critical issues from the logs that are seen, as well as the main changes made, along with general system health from CPU, Memory and Disk Storage. Non-critical items are reported and indicated in the logs lower down. | `src/dthostmon/core/host_report.py` |
| **FR-ANALYSIS-005** | 1 | **Site Report** | As a systems administrator, I want reports show the critical items of concern for a specific site. | System produces a Site Status Report for each site in Markdown that reports the general status of the site focusing on critical items of concern across all systems, as well as the main systems where changes were made from history logs, app installs. Also includes a table showing hosts with average CPU usage, Memory Usage and the storage system, highlighting any systems that are close to their storage limits. Configuration should exist to specify the % used to trigger Health, Info, Warning and Critical usages. These would be ranges like: Health: 0-30% and Critical 90+%. | `src/dthostmon/core/site_report.py` |
| **FR-ANALYSIS-006** | 1 | **Email Site+Host Reports** | As a systems administrator, I need Site/Host Reports emailed to me on a daily basis for review, or as configured by the system. | The System emails the produced Host & Site Reports as configured Globally or in the Site and Host configs. Frequency of the Reports should be configured at the Global, Site and Host level, with each lower level over-riding over-ride the frequency and report configuration of higher levels. | `src/dthostmon/core/report_scheduler.py`, `src/dthostmon/core/orchestrator.py`, `alembic/versions/002_add_last_report_sent.py` |
| **FR-ALERT-001** | 1 | **Email Alert Generation** | As an on-call engineer, I want to receive email alerts for critical issues. | System sends HTML email with issue summary, severity level, affected host, recommendations, and link to full report. Email sent within 5 minutes of analysis completion. | `src/dthostmon/core/email_alert.py`, `src/dthostmon/core/orchestrator.py` |
| **FR-ALERT-002** | 1.5 | **Pushover Alert Generation** | As an on-call engineer, I want to receive Pushover alerts for critical issues. | System sends abbreviated alerts, severity level, affected host. These are only for critical alerts of pending issues. More detail information will be sent in the Email alert. Pushover alerts sent within 5 minutes of analysis completion. | `src/dthostmon/core/pushover_alert.py`, `src/dthostmon/core/orchestrator.py` |
| **FR-ALERT-003** | 4 | **Severity-Based Routing** | As an operations team with tiered responsibilities, I want critical alerts to go to senior engineers and warnings to team leads. | Configuration supports severity levels (INFO, WARN, CRITICAL) with different recipient lists. CRITICAL issues also trigger SMS (optional). | _Phase 4 - Not Yet Implemented_ |
| **FR-API-001** | 1 | **REST API Endpoint (Read-Only)** | As a Web UI or external system, I want to query monitoring results programmatically. | System exposes HTTP REST API on port 8080. Endpoints include: `/health`, `/results/<host_id>`, `/logs/<host_id>`, `/history/<host_id>`. Authentication via API key. | `src/dthostmon/api/server.py` |
| **FR-REPORT-001** | 1 | **Comprehensive HTML Report** | As a system administrator reviewing the week's issues, I want a detailed report showing all findings. | System generates HTML report with graphs, tables, and trend analysis. Report includes host status, issues found, performance trends, and recommendations. Report is saved and can be emailed. | `src/dthostmon/core/email_alert.py` (HTML formatting) |
| **FR-REPORT-002** | 4 | **Historical Trend Analysis** | As capacity planning team, I want to see 30-day trends of resource usage. | System maintains database of historical metrics. Generates trend graphs showing CPU, memory, disk usage over 30 days. Identifies trending issues (disk filling up, memory growing). | _Phase 4 - Not Yet Implemented_ |
| **FR-CONFIG-001** | 1 | **YAML Configuration File** | As an operations team, I want to define all settings in a readable config file. | System reads `dthostmon.yaml` with all parameters (hosts, monitoring intervals, thresholds, AI settings). Changes take effect on next monitoring cycle. Syntax errors are reported clearly. | `src/dthostmon/utils/config.py`, `config/dthostmon.yaml.example` |
| **FR-CONFIG-002** | 1.5 | **YAML Configuration Update (Remote Self-Registration)** | As a systems maintainer, I want the ability for remote hosts to self-register in the monitoring system. | A remote script `dthostmon_add.sh` can be executed on remote systems. This system connects to the DTHostMon REST API endpoint and adds itself as a system to be monitored. SSH keys are transferred between systems. Multiple additions are idempotent (no duplicates). | `scripts/dthostmon_add.sh`, `src/dthostmon/api/server.py` |
| **FR-CONFIG-003** | 1 | **Environment Variable Substitution** | As a DevOps engineer using containers, I want to inject secrets via environment variables. | Configuration supports `${VAR_NAME}` syntax. System substitutes environment variables before processing. Useful for API keys, passwords in container environments. | `src/dthostmon/utils/config.py` |
| **FR-CONFIG-004** | 1 | **YAML Configuration Review** | As a systems maintainer, I want the system to review current YAML configuration. | System outputs current configuration to terminal showing monitored hosts, configuration per host, and expanded `${VAR_NAME}` values to verify variables load correctly. | `src/dthostmon_cli.py` (config command) |
| **FR-CONFIG-005** | 1 | **YAML Configuration Host Setup** | As a systems maintainer, I want automated SSH key validation and setup. | System tests all host connections and reports results in a table. For unreachable hosts, can automatically connect via SSH and push keys to enable future connections. Interactive process supports credential entry for one-time setup. | `src/dthostmon_cli.py` (setup command) |
| **FR-CONFIG-006** | 1 | **Host Configuration** | As a systems administrator, I need to be able to configure hosts for monitering and identify what site a host is in as well as tags for each host which can be used for filtering or grouping that host. | System configuration provides the ability to define a Host Name, ID, Site, Tags (multiple, for filtering). This configuration is used for reporting as well as recording monitor reports in the database. | `src/dthostmon/models/database.py`, `config/dthostmon.yaml.example` |
| **FR-CONFIG-007** | 1 | **Host Config From Divtools Docker** | As a systems administrator, I want the ability to load the YAML Configuration Hosts with existing Docker folders. | The $DIVTOOLS/docker/sites ($DOCKER_SITES_DIR) folder contains a folder structure of sites and hosts. The system should provide a script that can be used to update the existing YAML configuration with Sites and Hosts as represented by the $DOCKER_SITES_DIR) folder. If a Site already exists in the YAML folder, it should be updated with any configuration that exists in the $DOCKER_SITES_DIR. As with most scripts in divtools, it should provide both -test and -debug options. This script will be part of the dthostmon project.  | `scripts/dthostmon_sync_config.sh`, `tests/unit/test_config_sync.py` |
| **FR-CONFIG-010** | 1 | **Config Scaffold Generation** | As a systems administrator, I want utilities to quickly generate example `dthm-*.yaml` and `.env.*` files to seed my Docker site/host folders. | The sync script should provide options to output example YAML/ENV to stdout or create them in-place under `$DOCKER_SITES_DIR` for discovered hosts and sites, with interactive prompts on overwrite/append. This streamlines initial site/host onboarding. | `scripts/dthostmon_sync_config.sh`, `tests/unit/test_config_sync.py` |
| **FR-CONFIG-008** | 1 | **Host Config Script ENV Vars** | As a systems administrator, I want the ability to load the YAML Configuration Hosts with existing Docker folders, including configuration. | The script used for updating the dthostmon.yaml file from the $DOCKER_SITES_DIR should have the ability to read not just Sites and Hosts, but also configuration from the files. A set of env vars should be defined and identified that can be used to declare Site and Host Configuration to be loaded into the dthostmon.yaml file. These env vars would be defined in the various .env.$SITENAME and .env.$HOSTNAME files. When this script is run, it will update the dthostmon.yaml file with the configuration from those files. Every configuration item that can be defined in the YAML file should have an associated ENV Var that can also be set in the .env.* file to update the dthostmon.yaml configuration file. For multiple value vars (such as "tags") the env var should accept a comma delimited list. As with most scripts in divtools, it should provide both -test and -debug options. This script will be part of the dthostmon project.  | `scripts/dthostmon_sync_config.sh`, `tests/unit/test_config_sync.py` |
| **FR-CONFIG-009** | 1 | **Host Config Script Site + HOST YAML Files** | As a systems administrator, I want the ability to load the YAML Configuration Hosts with existing Docker folders, including configuration, from *.yaml files. | The script used for updating the dthostmon.yaml file from the $DOCKER_SITES_DIR should also look for files named dthm-*.yaml (Site/Host YAML file). These files would each include either Site or Host configuration that will be read and used to update the dthostmon.yaml file. Similar to the dthostmon.yaml files, env vars will be expanded to the values prior to updating the dthostmon.yaml file unless they are double delimited like this ${{ENV_VAR}}. Vars in the dthm-.yml file with env vars formatted in that way, would be copied to the dthostmon.yaml file as ${ENV_VAR} and will later be expanded when the dthostmon.yaml file is read. | `scripts/dthostmon_sync_config.sh`, `tests/unit/test_config_sync.py` |
| **FR-UI-001** | 2 | **Web UI Server Configuration Persistence** | As a system administrator managing the Web UI, I want Web UI configuration to persist externally. | Web UI configuration files (themes, display settings, user preferences, dashboard layouts) stored on host at `/opt/dthostmon/webui-config/`, mounted read-write in container. All changes persist to host filesystem and are editable via VSCode. | _Phase 2 - Not Yet Implemented_ |
| **FR-UI-002** | 2 | **Web UI Data Volume Separation** | As a DevOps operator, I want clear separation of application code, configuration, and data. | System maintains separate volume mounts: application code in container, configuration in `/opt/dthostmon/webui-config/` (host), database data in PostgreSQL, and logs in `/opt/dthostmon/logs/`. Each component managed independently. | _Phase 2 - Not Yet Implemented_ |
| **NR-PERF-001** | 1 | **Execution Time Performance** | As an operations team, I want monitoring not to impact system performance. | Complete monitoring cycle for 10 hosts completes in < 5 minutes. Single host monitoring < 60 seconds. Response time degrades gracefully with additional hosts. | `src/dthostmon/core/orchestrator.py` (concurrent processing) |
| **NR-PERF-002** | 1 | **Memory Efficiency** | As an administrator running this on modest hardware, I want low memory usage. | Process uses < 100MB memory during normal operation. Handles 50+ host configurations without swapping. Memory is released after each monitoring cycle completes. | `src/dthostmon/core/orchestrator.py` (streaming, cleanup) |
| **NR-REL-001** | 1 | **Uptime and Reliability** | As a critical infrastructure owner, I want minimal downtime. | System achieves 99.9% uptime (max 8.7 hours downtime/month). Failed monitoring cycles trigger alerts. Automatic restart on failure. Database maintains state across restarts. | `dca-dthostmon.yml` (restart policies), `docker-entrypoint.sh` |
| **NR-REL-002** | 1 | **Graceful Failure Handling** | As an operations engineer, I want the system to continue working even when external services fail. | If Prometheus unavailable, system continues with SSH logs + Glances. If Glances unavailable, system continues with SSH logs + Prometheus. If AI API fails, system saves logs for manual analysis. | `src/dthostmon/core/orchestrator.py`, `src/dthostmon/core/ai_analyzer.py` |
| **NR-SEC-001** | 1 | **SSH Key Security** | As a security officer, I want strong cryptographic security. | System requires Ed25519 or RSA-4096+ SSH keys. Keys loaded from files with 0600 permissions. Keys never logged or exposed in output. Supports encrypted key passphrases. | `src/dthostmon/core/ssh_client.py`, `setup.sh` |
| **NR-SEC-002** | 1 | **Credential Management** | As a compliance team, credentials must never appear in logs or config files. | All credentials (API keys, passwords) stored in environment variables, never in config files. No credentials logged. Sensitive data masked in output and reports. | `src/dthostmon/utils/config.py`, `.env.example` |
| **NR-SEC-003** | 1 | **Encrypted Communications** | As a security architect, all external communications must be encrypted. | SSH connections required. HTTPS/TLS required for Prometheus, InfluxDB APIs. SMTP uses STARTTLS or SMTPS. No unencrypted protocols used. | `src/dthostmon/core/ssh_client.py`, `src/dthostmon/core/email_alert.py` |
| **NR-SEC-004** | 1 | **Audit Trail** | As an auditor, I need to track all monitoring activities. | System logs all host connections, analyses run, alerts sent, with timestamps. Logs include actor/system info. Logs retained for 90 days. Cannot be modified after creation. | `src/dthostmon/models/database.py` (LogEntry model), `src/dthostmon/core/orchestrator.py` |
| **NR-SCALE-001** | 1 | **Host Scalability** | As an enterprise with growing infrastructure, I want to monitor 500+ hosts eventually. | Current design supports 50+ hosts with single agent. Architecture supports distributed agents for larger deployments. Concurrent processing scales linearly. | `src/dthostmon/core/orchestrator.py` (ThreadPoolExecutor) |
| **NR-SCALE-002** | 1 | **Data Volume Handling** | As infrastructure grows, I want to handle increasing log volume. | System handles 10GB+ daily log ingestion. Uses streaming processing (not loading entire logs into memory). Includes log rotation and compression for storage. | `src/dthostmon/core/ssh_client.py`, `src/dthostmon/core/orchestrator.py` |
| **SR-DB-001** | 1 | **State Persistence** | As a system, I need to remember host history and previous analyses. | System uses SQLite (small deployments) or PostgreSQL (large). Maintains baseline metrics and previous analyses. Supports historical queries and trending. | `src/dthostmon/models/database.py`, `src/dthostmon/models/__init__.py` |
| **SR-DB-002** | 1 | **Data Retention** | As a compliance team, we need audit data for 90 days minimum. | System retains 90 days of analysis results, logs, and metrics. Older data is automatically compressed and archived. Queries of historical data remain fast (< 1 second). | `src/dthostmon/models/database.py` (indexes, retention logic) |
| **SR-API-001** | 4 | **LLM Model Flexibility** | As an operations team evaluating AI providers, I want to switch models easily. | Configuration supports OpenAI GPT-4, Claude 3.5, local Ollama models. Switching models requires only config change. Prompts are model-agnostic. | _Phase 4 - Not Yet Implemented_ |
| **SR-API-002** | 4 | **AI Cost Optimization** | As a cost-conscious team, I want to minimize AI API spending. | System implements result caching (identical logs reuse same analysis within 24 hours). Rate limiting prevents over-consumption. Log aggregation reduces API calls. Estimated cost < $100/month for 50 hosts. | _Phase 4 - Not Yet Implemented_ |
| **SR-DEPLOY-001** | 1 | **Containerized Deployment** | As a DevOps engineer, I want to deploy via Docker with K3s readiness. | System includes `dthostmon.Dockerfile` and `dca-dthostmon.yml` for development. Docker image runs on python:3.11-slim base. Single command deployment: `docker compose up`. Supports environment variable injection. Kubernetes-ready with health checks and resource limits. | `dthostmon.Dockerfile`, `dca-dthostmon.yml` |
| **SR-DEPLOY-002** | 1 | **Kubernetes Integration** | As a platform engineer planning K3s deployment, I want HA and failover support. | System includes K3s manifests with health checks, restart policies, and resource limits. Supports horizontal scaling (multiple replicas). Config mounted via ConfigMap. Database and monitoring data persisted across pod restarts. | `k8s/` (manifests directory) |
| **SR-DEPLOY-003** | 1 | **Configuration as Code** | As an operator managing multiple environments, I want config stored externally. | Configuration files stored on host at `/opt/dthostmon/config/`, mounted read-write in container. Editable via VSCode. Changes take effect on next monitoring cycle without container restart. | `dca-dthostmon.yml` (volume mounts) |
| **SR-OPS-001** | 2 | **Structured Logging** | As an operations team, I want parseable logs for log aggregation. | System outputs JSON-formatted logs (optional human-readable format). Each log entry includes timestamp, level, component, message. Compatible with ELK, Splunk, CloudWatch. | _Phase 2 - Not Yet Implemented_ |
| **SR-OPS-002** | 1 | **Health Checks** | As a monitoring system, I want the application to be self-aware. | System exposes health check endpoint (HTTP or file). Returns status of database, external API connectivity, cron job execution. Used by external monitoring (Prometheus node-exporter scrape). | `src/dthostmon/api/server.py` (/health endpoint) |
| **TR-UNIT-001** | 1 | **Unit Test Framework Setup** | As a developer, I want automated testing to ensure code quality and catch regressions. | System includes unit tests for all core modules (SSH, config, database, email, API). Tests use pytest framework with fixtures and mocking. Test execution command: `pytest tests/unit/`. Minimum 80% code coverage target. | `pytest.ini`, `tests/unit/`, `tests/conftest.py` |
| **TR-UNIT-002** | 1 | **Component Mocking and Fixtures** | As a developer, I want to test components in isolation without external dependencies. | Unit tests include fixtures for mock PostgreSQL, mock SSH servers, mock email, and mock LLM API responses. Allows testing without real database or host connections. | `tests/conftest.py`, `tests/fixtures/` |
| **TR-INTEG-001** | 1 | **Integration Test Scenarios** | As a QA engineer, I want end-to-end testing of complete monitoring workflows. | Integration tests cover: (1) SSH connection → log retrieval → database persistence → email generation, (2) Configuration parsing and variable substitution, (3) Multi-host concurrent execution, (4) Error handling and retry logic. Tests run against containerized PostgreSQL and mock SSH servers. | `tests/integration/` |
| **TR-INTEG-002** | 1 | **Test Data and Seed Data** | As a developer, I want reproducible test scenarios with consistent test data. | Test suite includes seed files with sample logs, metrics, and configurations. Docker Compose includes test container with pre-populated PostgreSQL schema. Tests can be run locally or in CI/CD pipeline with identical results. | `tests/fixtures/` |
| **TR-PERF-001** | 1 | **Performance Benchmarking** | As a DevOps engineer, I want to track performance improvements over time. | System includes performance tests measuring execution time for 1, 5, 10, and 50 host monitoring runs. Benchmarks stored in database for trending. CI/CD pipeline fails if new code degrades performance >10%. | `src/dthostmon/core/orchestrator.py` (timing metrics) |
| **TR-CI-001** | 1 | **Automated CI/CD Testing** | As a developer, I want tests to run automatically on every code commit. | GitHub Actions workflow (or equivalent) runs on every push to develop/main branches. Workflow runs: unit tests, integration tests, code coverage check (minimum 80%), linting (pylint/flake8), and security scanning. Pull requests blocked if any test fails. | `.github/workflows/` |
| **TR-TEST-001** | 1 | **Test Execution Documentation** | As a new team member, I want clear documentation on running tests locally and in CI/CD. | Project includes TESTING.md with sections: (1) Running tests locally (pytest commands), (2) Creating new tests (fixtures, mocking patterns), (3) Adding test data, (4) Debugging test failures, (5) CI/CD pipeline overview. Examples provided for each test type. | `docs/TESTING.md` |
| **TR-TEST-002** | 1 | **Test Coverage Reporting** | As a QA lead, I want visibility into test coverage and gaps. | Each test run generates coverage report (pytest-cov). Coverage report uploaded to CodeCov for tracking trends. Dashboard shows which files/functions lack coverage. Reports available in CI/CD artifacts and as HTML report. | `pytest.ini` (coverage config), `requirements-dev.txt` |
| **TR-TEST-003** | 1 | **Test Execution** | As a QA lead, I want the execution of tests to be simple and easy to execute. | Unit tests can be run using a test script `testmenu.sh` which displays a menu of tests which can be run. The menu of tests is implented using Whiptail, Dialog or YAD. The menu is structured with each section showing a set of tests which can be selected with checkboxes and then executed. As new tests and sections are added, this menu should be updated to included every test. Selecting which tests to run would be easiest to implement using a tree-view structure with sections functioning as root nodes and sub-tests as sub nodes. Selecting the root-node selects all the sub-tests. The tests runner should have two modes: <ul><li>**external:** runs outside of the Docker container, executing the tests using docker exec.</li><li>**internal:** launches the script from inside of the Docker container such that executing each test runs it from inside of the Docker container.</li></ul> | `tests/testmenu.sh` |

### Non-Functional Requirements

#### Performance
- **Execution Time:** Complete monitoring cycle < 5 minutes for 10 hosts
- **Resource Usage:** < 100MB memory, minimal CPU impact
- **Concurrent Processing:** Support for 5+ simultaneous host connections

#### Reliability
- **Error Handling:** Graceful failure handling with retry logic
- **Data Persistence:** State preservation across restarts
- **Monitoring:** Self-monitoring capabilities

#### Security
- **SSH Security:** Key-based authentication only
- **Credential Management:** Environment variable-based secrets
- **Network Security:** Encrypted communications (SSH, HTTPS)
- **Access Control:** Minimal required permissions on target systems

#### Scalability
- **Host Count:** Support for 50+ monitored systems
- **Data Volume:** Handle 1GB+ daily log volume
- **Storage:** Efficient data retention and cleanup

### Dependencies and Prerequisites

#### System Requirements
- **Operating System:** Linux (Ubuntu 20.04+, CentOS 7+)
- **Python Version:** 3.8+ (if Python-based)
- **Memory:** 512MB minimum, 1GB recommended
- **Storage:** 1GB for application, variable for data retention
- **Database:** PostgreSQL 12+ running at 10.1.1.74:5432

#### External Dependencies
- **PostgreSQL:** 12+ (required, for data storage at 10.1.1.74:5432)
- **SSH Client:** OpenSSH 7.0+
- **Prometheus:** 2.0+ (optional, for metrics)
- **InfluxDB:** 1.8+ (optional, for time-series data)
- **Glances:** 3.0+ (optional, for real-time monitoring)
- **Email Server:** SMTP-compatible server

#### Python Packages (in requirements.txt)
```
requests>=2.25.0
paramiko>=2.7.0
pyyaml>=5.4.0
psycopg2-binary>=2.9.0
influxdb-client>=1.18.0
prometheus-api-client>=0.4.0
openai>=1.0.0
rich>=10.0.0
schedule>=1.1.0
sqlalchemy>=1.4.0
fastapi>=0.100.0
uvicorn>=0.23.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
```

#### System Packages (in Dockerfile)
```
postgresql-client          # Remote psql connections
openssh-client             # SSH connectivity to remote systems
curl                       # Health checks and API calls
```

### Implementation Plan

#### Phase 1: Core Infrastructure & Docker Setup
- Docker image creation (dthostmon.Dockerfile with Python 3.11)
- SSH connectivity and log retrieval
- Configuration management (YAML parsing with env var substitution)
- PostgreSQL database setup (user: dthostmon, auto-created on first run)
- Database schema initialization for host_monitoring table
- Basic email reporting
- REST API foundation (health check endpoint)
- dca-dthostmon.yml for containerized deployment

#### Phase 2: Monitoring Integration
- Prometheus integration
- InfluxDB integration
- Glances integration
- Multi-host concurrent processing

#### Phase 3: AI Analysis
- MCP implementation
- LLM integration
- Analysis prompt development
- Anomaly detection algorithms

#### Phase 4: Advanced Features
- Predictive alerting
- Custom report templates
- Historical trend analysis
- Performance optimization

#### Phase 5: Web UI and External Integration (Post-MVP)
- Web dashboard (FastAPI server in same container)
- Web UI configuration persistence (external volume at `/opt/dthostmon/webui-config/`)
- Log browsing and search interface
- Review tracking (checkbox to mark logs reviewed)
- Comment/note system for findings
- Plane project management integration (automatic issue creation)
- API expansion for external integrations
- User preference and dashboard customization storage

### Testing Strategy

#### Unit Testing
- Individual component testing
- Mock external service responses
- Configuration validation

#### Integration Testing
- End-to-end monitoring workflows
- Multi-host scenarios
- Email delivery verification

#### Performance Testing
- Load testing with multiple hosts
- Memory and CPU usage monitoring
- Execution time benchmarks

### Deployment and Operations

#### Installation
- Automated installation script
- Configuration file generation
- PostgreSQL user and database creation (if not exists)
- Database schema initialization
- Dependency management

#### Container Deployment

**Local Development:**
```bash
cd /path/to/dthostmon
docker compose up
```

**Production (Docker):**
```bash
docker run -d \
  --name dthostmon \
  -p 8080:8080 \
  -v /opt/dthostmon/config:/opt/dthostmon/config:rw \
  -v /opt/dthostmon/logs:/opt/dthostmon/logs \
  -v /opt/dthostmon/webui-config:/opt/dthostmon/webui-config:rw \
  -e DB_PASSWORD=$DB_PASSWORD \
  -e SMTP_PASSWORD=$SMTP_PASSWORD \
  dthostmon:latest
```

**Production (K3s - future):**
```bash
kubectl apply -f k3s/dthostmon-deployment.yaml
kubectl apply -f k3s/dthostmon-configmap.yaml
```

**Cron or Scheduler Inside Container:**
- Monitor worker runs on schedule (configurable intervals)
- REST API server runs continuously on port 8080
- Both services managed by container init system

#### Monitoring and Maintenance
- Log rotation and cleanup
- Database maintenance
- Configuration updates
- Performance monitoring

### Risk Assessment

#### Technical Risks
- SSH connection failures
- External service unavailability
- AI model API rate limits
- Large data volume handling

#### Mitigation Strategies
- Retry logic and circuit breakers
- Fallback monitoring modes
- Rate limiting and caching
- Data compression and archiving

### Success Metrics
- **Uptime:** 99.9% successful monitoring cycles
- **Detection Rate:** 95% of critical issues detected
- **Response Time:** < 10 minutes from issue detection to alert
- **False Positive Rate:** < 5% alert accuracy

## Open Questions and Assumptions

### Assumptions
- Docker runtime available on deployment host
- PostgreSQL accessible at 10.1.1.74:5432
- Target systems have SSH access enabled
- Monitoring accounts have read access to log files
- Email infrastructure is available and configured
- AI model APIs are accessible and affordable
- Future K3s cluster available for HA deployments

### Open Questions
- Specific AI model preferences and cost constraints?
- Detailed log analysis requirements?
- Custom alerting rules and thresholds?
- Integration with existing monitoring infrastructure?

## Approval and Sign-off

**Product Manager:** Andrew Fields Date: 11/14/2025

**Engineering Lead:** Andrew Fields Date: 11/14/2025

**QA Lead:** Andrew Fields Date: 11/14/2025

---

<parameter name="filePath">/opt/divtools/projects/dthostmon/docs/PRD.md