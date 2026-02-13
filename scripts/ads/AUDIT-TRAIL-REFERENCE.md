# dt_ads_setup.sh - Audit Trail Reference

## Overview

The `dt_ads_setup.sh` script now provides a complete, production-grade audit trail of all operations performed during ADS setup and management.

## What Gets Logged

### 1. Script Lifecycle

#### Script Start
```
[2025-12-06 22:45:30 CST] HEAD: ================================
[2025-12-06 22:45:30 CST] HEAD: ADS Setup Script Started
[2025-12-06 22:45:30 CST] HEAD: ================================
[2025-12-06 22:45:30 CST] INFO: Log file: /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
[2025-12-06 22:45:30 CST] DEBUG: Test Mode: 0
[2025-12-06 22:45:30 CST] DEBUG: Debug Mode: 0
[2025-12-06 22:45:30 CST] DEBUG: Current Directory: /home/divix/divtools
[2025-12-06 22:45:30 CST] DEBUG: User: divix
```

#### Script Exit
```
[2025-12-06 23:15:45 CST] HEAD: ╔════════════════════════════════════════════════════════╗
[2025-12-06 23:15:45 CST] HEAD: ║ Script execution completed - Exiting
[2025-12-06 23:15:45 CST] HEAD: ╚════════════════════════════════════════════════════════╝
```

### 2. Menu Selection Tracking

Every user interaction is logged with clear visual separators:

```
[2025-12-06 22:45:30 CST] HEAD: ╔════════════════════════════════════════════════════════╗
[2025-12-06 22:45:30 CST] HEAD: ║ MENU SELECTION: Option 1 - ADS Setup (folders, files, network)
[2025-12-06 22:45:30 CST] HEAD: ╚════════════════════════════════════════════════════════╝

[2025-12-06 22:46:15 CST] HEAD: ╔════════════════════════════════════════════════════════╗
[2025-12-06 22:46:15 CST] HEAD: ║ MENU SELECTION: Option 2 - Start Samba Container
[2025-12-06 22:46:15 CST] HEAD: ╚════════════════════════════════════════════════════════╝

[2025-12-06 22:47:30 CST] HEAD: ╔════════════════════════════════════════════════════════╗
[2025-12-06 22:47:30 CST] HEAD: ║ MENU SELECTION: Option 4 - ADS Status Check (run tests)
[2025-12-06 22:47:30 CST] HEAD: ╚════════════════════════════════════════════════════════╝
```

### 3. Pre-Flight Checks

#### systemd-resolved Detection
```
[2025-12-06 22:45:32 CST] INFO: Checking for systemd-resolved on port 53...
```

**If NOT running:**
```
[2025-12-06 22:45:33 CST] INFO: ✓ systemd-resolved is not running
```

**If running:**
```
[2025-12-06 22:45:32 CST] WARN: systemd-resolved is currently running and listening on port 53
[2025-12-06 22:45:32 CST] WARN: Samba AD DC requires exclusive access to port 53 for DNS
[2025-12-06 22:45:32 CST] WARN: systemd-resolved is enabled and will start on reboot
```

**If user stops it:**
```
[2025-12-06 22:45:34 CST] DEBUG: User confirmed systemd-resolved stop
[2025-12-06 22:45:34 CST] INFO: Stopping systemd-resolved...
[2025-12-06 22:45:35 CST] INFO: ✓ Stopped systemd-resolved
[2025-12-06 22:45:36 CST] INFO: ✓ Masked systemd-resolved (will not auto-start)
```

**If user declines:**
```
[2025-12-06 22:45:32 CST] WARN: User opted not to stop systemd-resolved
[2025-12-06 22:45:32 CST] WARN: ⚠️  Samba AD DC may fail to start if port 53 is in use
```

### 4. Environment Variable Management

```
[2025-12-06 22:45:35 CST] INFO: Loading environment from /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
[2025-12-06 22:45:35 CST] INFO: Prompting for environment variables...
[2025-12-06 22:45:40 CST] DEBUG: User entered domain: avctn.lan
[2025-12-06 22:45:43 CST] DEBUG: User entered realm: AVCTN.LAN
[2025-12-06 22:45:46 CST] DEBUG: User entered workgroup: AVCTN
[2025-12-06 22:45:50 CST] DEBUG: User entered host IP: 10.1.1.98
[2025-12-06 22:45:54 CST] DEBUG: User entered DNS forwarder: 8.8.8.8 8.8.4.4
[2025-12-06 22:45:55 CST] INFO: Saving environment variables to /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/.env.ads1-98
```

### 5. Folder Operations

```
[2025-12-06 22:45:57 CST] INFO: Creating folder structure...
[2025-12-06 22:45:57 CST] DEBUG: Created /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba
[2025-12-06 22:45:58 CST] DEBUG: Created /opt/samba directories
[2025-12-06 22:45:58 CST] INFO: ✓ Folder structure created successfully

[2025-12-06 22:45:59 CST] INFO: Checking folder structure...
[2025-12-06 22:45:59 CST] INFO: ✓ All folders exist with correct permissions
```

### 6. Docker Compose Deployment

```
[2025-12-06 22:46:00 CST] INFO: Deploying docker-compose files...
[2025-12-06 22:46:01 CST] INFO: [TEST] Would copy: dci-samba.yml → /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/
[2025-12-06 22:46:02 CST] INFO: [TEST] Would copy: dc-ads1-98.yml → /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/
[2025-12-06 22:46:03 CST] INFO: [TEST] Would copy: entrypoint.sh → /home/divix/divtools/docker/sites/s01-7692nw/ads1-98/samba/
[2025-12-06 22:46:04 CST] INFO: ✓ Docker compose files deployed successfully
```

### 7. Bash Aliases Installation

```
[2025-12-06 22:46:05 CST] INFO: Offering to install bash aliases...
[2025-12-06 22:46:07 CST] DEBUG: User confirmed bash aliases installation
[2025-12-06 22:46:07 CST] INFO: ✓ Bash aliases installed
```

Or:
```
[2025-12-06 22:46:05 CST] INFO: Offering to install bash aliases...
[2025-12-06 22:46:07 CST] DEBUG: User declined bash aliases installation
```

### 8. Docker Network Operations

```
[2025-12-06 22:46:08 CST] INFO: Checking Docker network...
[2025-12-06 22:46:09 CST] WARN: Docker network 's01-7692nw_network' does not exist
[2025-12-06 22:46:10 CST] DEBUG: User confirmed network creation
[2025-12-06 22:46:12 CST] INFO: ✓ Network 's01-7692nw_network' created
```

Or:
```
[2025-12-06 22:46:08 CST] INFO: Checking Docker network...
[2025-12-06 22:46:09 CST] INFO: ✓ Docker network 's01-7692nw_network' exists
```

### 9. Container Start Operations

```
[2025-12-06 22:46:15 CST] HEAD: === Start Samba Container ===
[2025-12-06 22:46:15 CST] INFO: [MENU SELECTION] Container Start initiated
[2025-12-06 22:46:16 CST] DEBUG: Container 'samba-ads' is not running, will start it
[2025-12-06 22:46:17 CST] INFO: Starting container with docker compose...
[2025-12-06 22:46:25 CST] INFO: ✓ Container started successfully
[2025-12-06 22:46:27 CST] INFO: User requested to watch logs (Ctrl+C to stop)
```

### 10. Container Stop Operations

```
[2025-12-06 22:50:30 CST] HEAD: === Stop Samba Container ===
[2025-12-06 22:50:30 CST] INFO: [MENU SELECTION] Container Stop initiated
[2025-12-06 22:50:31 CST] DEBUG: User confirmed container stop
[2025-12-06 22:50:32 CST] INFO: Stopping container 'samba-ads'...
[2025-12-06 22:50:33 CST] INFO: ✓ Container stopped
```

### 11. DNS Configuration

```
[2025-12-06 22:51:00 CST] HEAD: === Configure DNS on Host ===
[2025-12-06 22:51:00 CST] INFO: [MENU SELECTION] DNS Configuration initiated
[2025-12-06 22:51:01 CST] INFO: Current DNS configuration:
[2025-12-06 22:51:01 CST] DEBUG: nameserver 8.8.8.8
[2025-12-06 22:51:02 CST] DEBUG: User confirmed DNS configuration update
[2025-12-06 22:51:03 CST] INFO: Backing up /etc/resolv.conf to /etc/resolv.conf.backup-20251206-225103...
[2025-12-06 22:51:03 CST] DEBUG: Backup created at /etc/resolv.conf.backup-20251206-225103
[2025-12-06 22:51:04 CST] INFO: Updating /etc/resolv.conf with nameserver 127.0.0.1...
[2025-12-06 22:51:04 CST] INFO: ✓ /etc/resolv.conf updated
[2025-12-06 22:51:05 CST] INFO: systemd-resolved is running, updating configuration...
[2025-12-06 22:51:06 CST] INFO: ✓ systemd-resolved configured and restarted
[2025-12-06 22:51:06 CST] INFO: ✓ DNS configuration update completed
```

### 12. Status Checks

```
[2025-12-06 22:52:00 CST] HEAD: === ADS Status Checks ===
[2025-12-06 22:52:00 CST] INFO: [MENU SELECTION] Status Checks initiated
[2025-12-06 22:52:01 CST] INFO: ✓ Container 'samba-ads' is running
[2025-12-06 22:52:02 CST] INFO: Running pytest test suite from: /home/divix/divtools/scripts/ads/test...
[2025-12-06 22:52:03 CST] DEBUG: Using existing virtual environment
[2025-12-06 22:52:04 CST] INFO: Executing pytest with verbose output...
[2025-12-06 22:52:15 CST] INFO: Test suite completed with exit code: 0
```

## Log Levels

### INFO Level Messages
High-level operational messages, shown in all modes:
- Script start/stop
- Function entry points
- Configuration actions
- Successful operations
- User confirmations
- Completion status

### DEBUG Level Messages
Detailed debugging information, shown with `--debug` flag:
- Variable values
- File paths and operations
- User responses to prompts
- Function details
- Configuration snippets
- System command output

### WARN Level Messages
Warning conditions that don't stop execution:
- Missing configurations
- Service conflicts
- User opted-out operations
- Port conflicts

### ERROR Level Messages
Critical errors that stop execution:
- Failed system calls
- Missing required files
- Invalid configurations
- Command execution failures

### HEAD Level Messages
Important section headers and visual separators:
- Script lifecycle markers
- Menu selections
- Function headers
- Start/end indicators

## Analyzing Logs

### View Complete Setup Session
```bash
tail -500 /opt/ads-setup/logs/dt_ads_setup-20251206-224530.log
```

### Search for Specific Operations
```bash
# All DNS operations
grep "DNS" /opt/ads-setup/logs/dt_ads_setup-*.log

# All user confirmations
grep "User" /opt/ads-setup/logs/dt_ads_setup-*.log

# All warnings
grep "WARN" /opt/ads-setup/logs/dt_ads_setup-*.log

# All errors
grep "ERROR" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Find When Specific Menu Option Was Executed
```bash
grep "MENU SELECTION: Option 2" /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Extract Timeline of All Operations
```bash
grep "INFO\|WARN\|ERROR" /opt/ads-setup/logs/dt_ads_setup-*.log | cut -d']' -f1-2 | sort
```

### Count Operations by Type
```bash
grep -o "\[.*\]" /opt/ads-setup/logs/dt_ads_setup-*.log | cut -d' ' -f2 | sort | uniq -c | sort -rn
```

## Retention Policy

### Current Setup
- Logs stored in: `/opt/ads-setup/logs/`
- Format: `dt_ads_setup-YYYYMMDD-HHMMSS.log`
- Retention: Manual (no automatic cleanup)

### Recommended Retention
- Keep last 30 days of logs
- Archive older logs to separate location
- Consider compression for long-term storage

## Integration with Other Tools

### View logs in real-time
```bash
tail -f /opt/ads-setup/logs/dt_ads_setup-*.log
```

### Monitor for errors
```bash
grep "ERROR" /opt/ads-setup/logs/dt_ads_setup-*.log | mail -s "ADS Setup Errors" admin@example.com
```

### Parse for metrics
```bash
# Count successful operations
grep "✓" /opt/ads-setup/logs/dt_ads_setup-*.log | wc -l

# Count failures
grep "✗" /opt/ads-setup/logs/dt_ads_setup-*.log | wc -l

# Total runtime
head -1 /opt/ads-setup/logs/dt_ads_setup-*.log
tail -1 /opt/ads-setup/logs/dt_ads_setup-*.log
```

## Troubleshooting

### If logs not created
1. Check directory permissions: `ls -ld /opt/ads-setup/logs`
2. Verify write access: `touch /opt/ads-setup/logs/test.log`
3. Check disk space: `df -h /opt/`

### If timestamps show wrong timezone
1. Verify system timezone: `timedatectl`
2. Check TZ environment variable
3. Run: `TZ=America/Chicago ./dt_ads_setup.sh`

### If systemd-resolved check fails
1. Verify systemctl available: `which systemctl`
2. Check sudo access: `sudo systemctl status systemd-resolved`
3. Review logs for permission errors

## Best Practices

1. **Always preserve logs** after running setup
2. **Archive logs** from completed setups
3. **Review logs** after each operation to verify success
4. **Use --debug** when troubleshooting issues
5. **Use --test** for dry-run operations before real setup
6. **Share logs** when reporting issues
7. **Monitor logs** in real-time during setup
8. **Correlate logs** with system events (check syslog for context)

