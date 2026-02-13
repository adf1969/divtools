# Local LLM Host Monitoring Solution

## Overview

This is a **100% self-contained** host monitoring solution that runs entirely on each host using a local LLM (Large Language Model). No external services required!

### Key Features

✅ **Fully Local** - Everything runs on the host, no cloud dependencies  
✅ **AI-Powered Analysis** - Uses Ollama or LM Studio for intelligent change detection  
✅ **Persistent Audit Log** - Complete history of all analyses and findings  
✅ **Portable** - Single script solution, easy to deploy  
✅ **Privacy** - Your data never leaves your infrastructure  
✅ **Offline Capable** - Works without internet once model is downloaded  

## Components

### 1. `host_change_analyzer.sh` - AI Analysis Script

Combines change collection with local LLM analysis to provide intelligent monitoring.

**What it does:**
- Collects changes (history, packages, docker, security events)
- Sends data to local LLM for analysis
- Gets back structured security assessment
- Appends results to persistent audit log
- Highlights concerns requiring attention

### 2. Supported LLM Providers

#### Ollama (Recommended)
- **Easiest to setup**: One-line install
- **Best integration**: Built-in API
- **Resource efficient**: Runs well on modest hardware
- **Models available**: llama3.2, mistral, phi3, and more

#### LM Studio
- **GUI interface**: Easy model management
- **Cross-platform**: Windows, Mac, Linux
- **Compatible API**: OpenAI-style endpoints

## Quick Start

### Step 1: Initial Setup (One-time per host)

```bash
# First, run the host setup from earlier
sudo /home/divix/divtools/scripts/util/host_change_log.sh setup

# Then setup the AI analyzer
sudo /home/divix/divtools/scripts/util/host_change_analyzer.sh setup
```

**What `setup` does:**
1. Installs Ollama (if not present)
2. Starts Ollama service
3. Downloads recommended model (llama3.2 - ~2GB)
4. Creates audit log directory

**Time:** 5-10 minutes (mostly downloading model)

**Requirements:**
- 4GB RAM minimum (8GB recommended)
- 5GB disk space for model
- curl, jq installed

### Step 2: Run Your First Analysis

```bash
# Run analysis manually
sudo /home/divix/divtools/scripts/util/host_change_analyzer.sh analyze
```

**Output example:**
```
================================================================================
HOST CHANGE ANALYSIS REPORT
================================================================================
Hostname:    myserver
Timestamp:   Mon Nov  4 12:30:45 EST 2025
Severity:    LOW
Summary:     Normal system activity, no security concerns

Concerns:
  [LOW] operational: High disk usage on /var partition (85%)

Recommendations:
  - Monitor /var disk usage and clean old logs if needed
  - Consider rotating or archiving logs more frequently

Details:
  System shows normal operational patterns. Recent package updates were
  security patches from official repositories. Command history shows typical
  administrative tasks. No unauthorized access attempts detected.
================================================================================
```

### Step 3: Automate with Cron

Add to root's crontab:

```bash
# Run analysis daily at 2 AM
0 2 * * * /home/divix/divtools/scripts/util/host_change_analyzer.sh analyze >> /var/log/divtools/analyzer.log 2>&1

# Or run every 6 hours for more frequent monitoring
0 */6 * * * /home/divix/divtools/scripts/util/host_change_analyzer.sh analyze >> /var/log/divtools/analyzer.log 2>&1
```

## Usage Examples

### Analyze Recent Changes
```bash
./host_change_analyzer.sh analyze
```

### View Last 5 Reports
```bash
./host_change_analyzer.sh report 5
```

### View Complete Audit History
```bash
./host_change_analyzer.sh history
```

### Test LLM Connection
```bash
./host_change_analyzer.sh test-llm
```

### Use Different Model
```bash
LLM_MODEL=mistral ./host_change_analyzer.sh analyze
```

### Use LM Studio Instead of Ollama
```bash
LLM_PROVIDER=lmstudio ./host_change_analyzer.sh analyze
```

## Model Recommendations

### For Most Users: `llama3.2` (3B parameters)
- **Size:** ~2GB
- **RAM:** 4-6GB
- **Speed:** Fast analysis (10-30 seconds)
- **Quality:** Good security analysis
- **Best for:** Daily/hourly checks on production systems

```bash
ollama pull llama3.2
```

### For Better Analysis: `mistral` (7B parameters)
- **Size:** ~4.1GB
- **RAM:** 8GB+
- **Speed:** Moderate (20-60 seconds)
- **Quality:** More detailed, nuanced analysis
- **Best for:** Daily checks with deeper investigation

```bash
ollama pull mistral
```

### For Low Resources: `phi3` (3.8B parameters)
- **Size:** ~2.2GB
- **RAM:** 4GB
- **Speed:** Fast
- **Quality:** Good reasoning, efficient
- **Best for:** Resource-constrained systems

```bash
ollama pull phi3
```

### For Maximum Quality: `llama3.1` (8B parameters)
- **Size:** ~4.7GB
- **RAM:** 10GB+
- **Speed:** Slower (30-90 seconds)
- **Quality:** Excellent, thorough analysis
- **Best for:** Critical systems, weekly deep dives

```bash
ollama pull llama3.1
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Host: myserver                                           │
│                                                          │
│  ┌────────────────────────────────────────────┐         │
│  │ 1. Collect Changes                          │         │
│  │    - Command history                        │         │
│  │    - Package installations                  │         │
│  │    - Docker config changes                  │         │
│  │    - Security events                        │         │
│  │    - System health                          │         │
│  └──────────────┬──────────────────────────────┘         │
│                 │                                         │
│                 ▼                                         │
│  ┌────────────────────────────────────────────┐         │
│  │ 2. Local LLM Analysis (Ollama)             │         │
│  │    Model: llama3.2                         │         │
│  │    Port: 11434                             │         │
│  │    Context: Last 24 hours of changes       │         │
│  └──────────────┬──────────────────────────────┘         │
│                 │                                         │
│                 ▼                                         │
│  ┌────────────────────────────────────────────┐         │
│  │ 3. Structured Analysis                      │         │
│  │    {                                        │         │
│  │      "severity": "low",                     │         │
│  │      "concerns": [...],                     │         │
│  │      "recommendations": [...]               │         │
│  │    }                                        │         │
│  └──────────────┬──────────────────────────────┘         │
│                 │                                         │
│                 ▼                                         │
│  ┌────────────────────────────────────────────┐         │
│  │ 4. Persistent Audit Log                     │         │
│  │    /var/log/divtools/monitor/audit/         │         │
│  │    - change_audit.log                       │         │
│  │    - analyses/changes_*.json                │         │
│  └────────────────────────────────────────────┘         │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Key Difference from n8n Solution:**
- Everything happens ON THE HOST
- No network dependencies
- No central orchestration needed
- Each host is self-sufficient

## Audit Log Format

The audit log (`/var/log/divtools/monitor/audit/change_audit.log`) contains:

```
================================================================================
AUDIT ENTRY: 2025-11-04T17:30:45Z
================================================================================
Hostname: myserver
Severity: medium
Summary: Unauthorized package installation detected

Analysis File: /var/log/divtools/monitor/audit/analyses/changes_20251104_173045_analysis.json
Changes File: /var/log/divtools/monitor/audit/analyses/changes_20251104_173045.json

- [MEDIUM] security: Package 'netcat-traditional' installed without approval
- [LOW] operational: Disk usage approaching threshold on /var

Recommendations:
- Investigate why netcat was installed and by whom
- Review /var partition and clean old logs
- Verify package came from trusted repository

Requires Immediate Action: true
Suspicious Activity Detected: true

Details:
The package 'netcat-traditional' was installed at 15:23 by user 'john'.
This is a network tool that can be used for both legitimate administration
and potentially malicious purposes. Command history shows it was installed
manually via apt. Recommend verifying with user and reviewing intended use.
```

## What the AI Analyzes

### 1. Security Concerns
- **Unauthorized access attempts** - Failed SSH logins, suspicious IPs
- **Privilege escalation** - Unusual sudo usage patterns
- **Suspicious commands** - `curl | sh`, `rm -rf`, base64 encoding
- **Unauthorized changes** - Package installs, config modifications
- **Attack patterns** - Port scanning, brute force attempts

### 2. Configuration Drift
- **Docker changes** - Modified compose files, container changes
- **Package drift** - Unplanned installations/removals
- **Service changes** - New daemons, modified systemd units
- **File integrity** - Modified critical system files

### 3. Operational Issues
- **Resource problems** - Low disk, high memory, failing services
- **System errors** - Critical errors in logs
- **Service failures** - Failed systemd units
- **Performance degradation** - High load, slow responses

### 4. Compliance & Policy
- **Unapproved software** - Non-standard packages
- **Configuration violations** - Settings outside policy
- **Audit trail gaps** - Missing or tampered logs
- **User violations** - Unauthorized user accounts

## Advanced Configuration

### Custom Model Selection

Create a config file: `/etc/divtools/analyzer.conf`

```bash
# LLM Configuration
LLM_PROVIDER="ollama"
LLM_MODEL="mistral"
LLM_TEMPERATURE="0.3"
OLLAMA_HOST="http://localhost:11434"

# Analysis Configuration
CHECK_INTERVAL="6h"  # For cron
KEEP_ANALYSES_DAYS="90"  # Cleanup old files
```

Source it in the script or use environment variables:

```bash
source /etc/divtools/analyzer.conf
./host_change_analyzer.sh analyze
```

### Remote Ollama Server

If you have a dedicated LLM server:

```bash
# Point to remote Ollama instance
OLLAMA_HOST="http://ollama-server.local:11434" \
./host_change_analyzer.sh analyze
```

This allows:
- Lighter weight on monitored hosts
- Centralized model management
- Shared compute resources
- Still fully local to your infrastructure

### Multiple Models for Different Severity

You could create a wrapper that uses different models based on initial findings:

```bash
#!/bin/bash
# quick_check.sh - Fast initial scan with phi3

# Fast scan
LLM_MODEL=phi3 ./host_change_analyzer.sh analyze

# If high severity, deep dive with larger model
if grep -q "Severity: high\|critical" /var/log/divtools/monitor/audit/change_audit.log | tail -1; then
    echo "High severity detected, running deep analysis..."
    LLM_MODEL=llama3.1 ./host_change_analyzer.sh analyze
fi
```

## Performance Considerations

### CPU Usage
- **During analysis:** 50-100% CPU for 10-60 seconds
- **At rest:** 0% CPU
- **Impact:** Minimal if scheduled during off-hours

### Memory Usage
| Model | RAM Required | Typical Usage |
|-------|-------------|---------------|
| phi3 (3.8B) | 4GB | 3.5GB |
| llama3.2 (3B) | 4GB | 3.2GB |
| mistral (7B) | 8GB | 6.5GB |
| llama3.1 (8B) | 10GB | 8GB |

### Disk Usage
- **Per model:** 2-5GB
- **Per analysis:** ~50KB (JSON files)
- **Audit log:** Grows ~10KB per entry
- **Total:** Plan for 10GB (model + logs + overhead)

### Analysis Speed
- **Small model (phi3, llama3.2):** 10-30 seconds
- **Medium model (mistral):** 20-60 seconds  
- **Large model (llama3.1):** 30-120 seconds

**Recommendation:** Use llama3.2 for daily automated checks, mistral for weekly deep analysis.

## Integration Options

### Email Notifications

Add to the script or wrapper:

```bash
#!/bin/bash
# analyze_and_notify.sh

RESULT=$(./host_change_analyzer.sh analyze 2>&1)
EXIT_CODE=$?

# If critical or requires action
if [[ $EXIT_CODE -eq 2 ]] || echo "$RESULT" | grep -q "IMMEDIATE ACTION REQUIRED"; then
    echo "$RESULT" | mail -s "[CRITICAL] $(hostname) Security Alert" admin@example.com
fi
```

### Slack/Discord Webhooks

```bash
#!/bin/bash
# analyze_and_post.sh

RESULT=$(./host_change_analyzer.sh analyze 2>&1)

if echo "$RESULT" | grep -q "Severity: high\|critical"; then
    SEVERITY=$(echo "$RESULT" | grep "Severity:" | awk '{print $2}')
    SUMMARY=$(echo "$RESULT" | grep "Summary:" | cut -d: -f2-)
    
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \"⚠️ *Security Alert on $(hostname)*\",
            \"attachments\": [{
                \"color\": \"danger\",
                \"fields\": [
                    {\"title\": \"Severity\", \"value\": \"$SEVERITY\", \"short\": true},
                    {\"title\": \"Summary\", \"value\": \"$SUMMARY\", \"short\": false}
                ]
            }]
        }"
fi

./host_change_analyzer.sh analyze
```

### Centralized Log Aggregation

Use rsyslog or similar to aggregate audit logs:

```bash
# /etc/rsyslog.d/divtools-audit.conf
$ModLoad imfile
$InputFileName /var/log/divtools/monitor/audit/change_audit.log
$InputFileTag divtools-audit:
$InputFileStateFile divtools-audit-state
$InputFileSeverity info
$InputFileFacility local7
$InputRunFileMonitor

# Forward to central syslog server
local7.* @@syslog-server.local:514
```

## Comparison: Local LLM vs n8n

| Feature | Local LLM | n8n |
|---------|-----------|-----|
| **Setup Complexity** | Simple (one script) | Moderate (workflow config) |
| **Dependencies** | Ollama only | n8n server + SSH |
| **Network Required** | No (after model download) | Yes (for SSH) |
| **Central Management** | Per-host | Centralized |
| **Scalability** | One host at a time | Many hosts at once |
| **Resource Usage** | 4-8GB RAM per host | Light on hosts, heavy on n8n server |
| **Portability** | Very high | Moderate |
| **Offline Operation** | Yes | No |
| **Privacy** | Maximum | Depends on n8n deployment |
| **Real-time Alerts** | Via cron + wrappers | Built-in |
| **Best For** | Independent hosts, privacy, simplicity | Fleet management, orchestration |

## Troubleshooting

### "Ollama not installed"
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### "Ollama service not running"
```bash
sudo systemctl start ollama
# OR
ollama serve &
```

### "Model not found"
```bash
ollama pull llama3.2
ollama list  # verify it's there
```

### "Out of memory"
```bash
# Use smaller model
LLM_MODEL=phi3 ./host_change_analyzer.sh analyze

# Or increase system swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### "Analysis taking too long"
```bash
# Use faster model
LLM_MODEL=phi3 ./host_change_analyzer.sh analyze

# Or reduce temperature (faster but less creative)
LLM_TEMPERATURE=0.1 ./host_change_analyzer.sh analyze
```

### "LLM response is not valid JSON"
This usually means the model hallucinated. Try:
1. Using a better model (mistral instead of phi3)
2. Lowering temperature (0.2 instead of 0.3)
3. The script tries to extract JSON from markdown - check raw response files

## Best Practices

### 1. Regular Schedule
```bash
# Daily analysis at 2 AM (low traffic time)
0 2 * * * /home/divix/divtools/scripts/util/host_change_analyzer.sh analyze
```

### 2. Log Rotation
```bash
# /etc/logrotate.d/divtools-audit
/var/log/divtools/monitor/audit/change_audit.log {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
}
```

### 3. Cleanup Old Analyses
```bash
# Weekly cleanup of analyses older than 90 days
0 3 * * 0 find /var/log/divtools/monitor/audit/analyses -name "*.json" -mtime +90 -delete
```

### 4. Review Reports
```bash
# Weekly review of all medium+ severity findings
./host_change_analyzer.sh report 50 | grep -E "medium|high|critical"
```

### 5. Baseline Period
Run for 1-2 weeks to establish baseline before alerting on all findings.

## Next Steps

1. **Test it:**
   ```bash
   sudo ./host_change_analyzer.sh setup
   sudo ./host_change_analyzer.sh analyze
   ```

2. **Review results:**
   ```bash
   ./host_change_analyzer.sh report
   ```

3. **Add to cron:**
   ```bash
   (crontab -l; echo "0 2 * * * /home/divix/divtools/scripts/util/host_change_analyzer.sh analyze") | crontab -
   ```

4. **Deploy to other hosts:**
   ```bash
   for host in server1 server2 server3; do
       scp host_change_analyzer.sh root@$host:/usr/local/bin/
       ssh root@$host "/usr/local/bin/host_change_analyzer.sh setup"
   done
   ```

5. **Monitor the audit logs!**

## Future Enhancements

- [ ] Web UI for viewing audit history
- [ ] Severity-based email/webhook notifications
- [ ] Comparison between hosts (detect drift)
- [ ] Machine learning on historical patterns
- [ ] Integration with Prometheus metrics
- [ ] Automated remediation suggestions
- [ ] Compliance report generation

---

**You now have a fully self-contained, AI-powered host monitoring solution!** 🎉
