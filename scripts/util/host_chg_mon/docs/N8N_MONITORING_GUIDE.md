# n8n Host Change Monitoring Guide

## Overview

This guide explains how to configure n8n to monitor host changes using the `host_change_log.sh` script setup.

## Prerequisites

1. Run `host_change_log.sh setup` on each target host (as root)
2. Ensure n8n can SSH into the target hosts
3. Install the SSH node in n8n

## Monitoring Manifest

After running the setup script, each host will have a monitoring manifest at:
```
/var/log/divtools/monitor/monitoring_manifest.json
```

This manifest contains all the files and paths that should be monitored.

## n8n Workflow Design

### Option 1: Simple Daily Check (Recommended)

**Nodes:**
1. **Schedule Trigger** - Runs daily at your preferred time
2. **SSH Node** - Connect to each host
3. **Read Manifest** - Cat the monitoring manifest
4. **Check Files** - Execute monitoring checks
5. **AI Agent** - Analyze changes and determine significance
6. **Notification** - Send alerts for important changes

### Option 2: Real-time with Webhooks

For more immediate notification, configure hosts to send webhooks when changes occur.

## Sample n8n Workflow Structure

```
[Schedule: Daily 6 AM]
    ↓
[Loop: Each Host]
    ↓
[SSH: Connect to Host]
    ↓
[Execute: Read Manifest]
    ↓
[SSH: Check History Files]
    ↓
[SSH: Check Docker Checksums]
    ↓
[SSH: Check APT Logs]
    ↓
[AI Agent: Analyze Changes]
    ↓
[Decision: Significant?]
    ↓
[Notify: Pushover/Email/Slack]
```

## SSH Commands for n8n

### 1. Read the Monitoring Manifest
```bash
cat /var/log/divtools/monitor/monitoring_manifest.json
```

### 2. Check Bash History Changes (Last 24 hours)
```bash
# Root user history (last 50 commands)
tail -50 /var/log/divtools/monitor/history/root.bash_history.latest

# Divix user history (last 50 commands)
tail -50 /var/log/divtools/monitor/history/divix.bash_history.latest

# Get commands from last 24 hours (with timestamps)
find /var/log/divtools/monitor/history -name "*.latest" -exec sh -c '
  echo "=== {} ==="
  grep "$(date -d "yesterday" +%Y-%m-%d)" "{}" || echo "No entries from yesterday"
' \;
```

### 3. Check APT Package Changes
```bash
# Get last 10 package operations
grep "^Start-Date:" /var/log/apt/history.log | tail -10

# Get package installs from last 7 days
awk -v date="$(date -d '7 days ago' +%Y-%m-%d)" '/^Start-Date:/ {if ($0 > date) print}' /var/log/apt/history.log

# Full recent install details
tail -100 /var/log/dpkg.log | grep " install "
```

### 4. Check Docker Config Changes
```bash
# Verify docker-compose files haven't changed
cd /home/divix/divtools && \
sha256sum -c /var/log/divtools/monitor/checksums/docker_configs.sha256 2>&1 | grep -v "OK$"

# If changes detected, show what changed
cd /home/divix/divtools && \
for file in docker/*.yml; do
  echo "=== $file ==="
  git diff HEAD "$file" 2>/dev/null || echo "No git repo or no changes"
done
```

### 5. Check System Log Events
```bash
# Critical errors in syslog (last 24 hours)
journalctl --since "24 hours ago" --priority=err

# Failed SSH attempts
grep "Failed password" /var/log/auth.log | tail -20

# Docker events
docker events --since 24h --until 1s 2>/dev/null || echo "Docker not running"
```

### 6. Run Verification
```bash
# Verify monitoring is working correctly
/home/divix/divtools/scripts/util/host_change_log.sh status
```

## AI Agent Prompt for n8n

Use an AI agent node to analyze the collected data. Here's a sample prompt:

```
You are a system administrator assistant monitoring host changes.

Analyze the following data from host: {{ $json.hostname }}

**Bash History Changes:**
{{ $json.history_data }}

**APT Package Changes:**
{{ $json.apt_data }}

**Docker Config Changes:**
{{ $json.docker_data }}

**System Log Events:**
{{ $json.syslog_data }}

Determine:
1. Are there any security concerns? (unauthorized access, suspicious commands)
2. Are there unexpected configuration changes?
3. Are there new packages that could impact system stability?
4. Is immediate action required?

Respond in JSON format:
{
  "severity": "low|medium|high|critical",
  "summary": "Brief description",
  "concerns": ["list of issues"],
  "recommendations": ["suggested actions"],
  "notify": true/false
}
```

## Workflow JSON (n8n Import)

You can create this workflow structure in n8n:

```json
{
  "name": "Host Change Monitoring",
  "nodes": [
    {
      "name": "Schedule Daily",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [{
            "field": "hours",
            "hoursInterval": 24
          }]
        }
      }
    },
    {
      "name": "Host List",
      "type": "n8n-nodes-base.set",
      "parameters": {
        "values": {
          "string": [
            {"name": "hosts", "value": "host1,host2,host3"}
          ]
        }
      }
    },
    {
      "name": "Split Hosts",
      "type": "n8n-nodes-base.splitInBatches"
    },
    {
      "name": "SSH Check",
      "type": "n8n-nodes-base.ssh",
      "parameters": {
        "command": "cat /var/log/divtools/monitor/monitoring_manifest.json"
      }
    }
  ]
}
```

## Monitoring Frequency Recommendations

| Item | Frequency | Reason |
|------|-----------|--------|
| Bash History | Daily | Commands accumulate gradually |
| APT Packages | Daily | Installs are infrequent but important |
| Docker Configs | Daily | Manual changes should be rare |
| System Logs | Daily | Errors need timely response |
| Security Events | Hourly/Real-time | Use journalctl for critical events |

## File Persistence Answers

### Q: Are monitored files deleted on reboot?
**A: No.** All monitored files persist across reboots:
- `/var/log/apt/history.log` - Rotated but persists
- `/var/log/divtools/monitor/` - Created in persistent location
- User history files - Preserved with PROMPT_COMMAND configuration
- Docker configs - Static files in home directory

### Q: How far back do history files go?
**A:** With the script configuration:
- **10,000 commands** in memory (HISTSIZE)
- **20,000 commands** in file (HISTFILESIZE)
- With daily usage, this is approximately **several months** of history
- The script also creates timestamped backups for longer retention

### Q: Is daily monitoring enough?
**A: Yes, for most cases:**
- Changes are typically deliberate and infrequent
- Daily checks catch unauthorized changes within 24 hours
- For critical security events, supplement with real-time alerting
- Consider hourly checks only for high-security environments

## Tips for n8n Configuration

1. **Use SSH Key Authentication**: Set up passwordless SSH for n8n
2. **Store Credentials Securely**: Use n8n's credential system
3. **Error Handling**: Add error notification nodes
4. **Rate Limiting**: Don't overwhelm hosts with rapid checks
5. **Batch Processing**: Check multiple hosts in parallel but with limits
6. **Data Retention**: Store analysis results in n8n's database
7. **Testing**: Start with one host before scaling to all

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH from n8n host
ssh user@target-host "cat /var/log/divtools/monitor/monitoring_manifest.json"
```

### Missing Manifest
```bash
# Re-run setup on target host
sudo /home/divix/divtools/scripts/util/host_change_log.sh setup
```

### Permission Denied
```bash
# Ensure n8n user can read monitoring files
sudo chmod -R 755 /var/log/divtools/monitor
```

## Advanced: Real-time Monitoring with inotify

For immediate change detection, you could add:

```bash
#!/bin/bash
# Watch for changes and send webhooks to n8n
inotifywait -m -r /home/divix/divtools/docker -e modify,create,delete |
while read path action file; do
    curl -X POST https://your-n8n.domain/webhook/host-change \
         -H "Content-Type: application/json" \
         -d "{\"host\":\"$(hostname)\",\"path\":\"$path\",\"action\":\"$action\",\"file\":\"$file\"}"
done
```

## Support

For issues or questions:
1. Run `host_change_log.sh verify` on the target host
2. Check `/var/log/divtools/monitor/verify.log`
3. Review n8n execution logs
