# Host Setup Checks Configuration Examples

## Example 1: Enable at Shared Level

This enables checks for all hosts and sites that don't override it.

**File**: `docker/sites/s00-shared/.env.s00-shared`

```bash
# ============================================================================
# HOST SETUP CHECKS - Enable automatic verification of host configuration
# Last Updated: 2025-11-11
# ============================================================================

# Enable dt_host_setup checks for all hosts
# This ensures environment variables and paths are properly configured
export DT_INCLUDE_HOST_SETUP=1

# Enable host_change_log setup checks for all hosts  
# This ensures change monitoring is properly configured
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Other shared env vars...
export SITE_NAME="s00-shared"
export DT_LOG_DIR="/var/log/divtools/monitor"
```

## Example 2: Enable at Site Level

This enables checks for all hosts within a specific site.

**File**: `docker/sites/mysite/.env.mysite`

```bash
# ============================================================================
# SITE: MyDeploy Site
# HOST SETUP CHECKS CONFIGURATION
# Last Updated: 2025-11-11
# ============================================================================

# Enable host setup checks - ensures environment is configured
export DT_INCLUDE_HOST_SETUP=1

# Enable change log monitoring setup
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Site-specific environment variables
export SITE_NAME="mysite"
export SITE_NUM="01"
export SITE_NETWORK="192.168.1.0/24"
export DT_LOG_DIR="/var/log/divtools/monitor"
export DT_LOG_MAXDAYS="30"
```

## Example 3: Enable at Host Level

This enables checks only for a specific host, overriding site/shared settings.

**File**: `docker/sites/mysite/TNHL01/.env.TNHL01`

```bash
# ============================================================================
# HOST: TNHL01
# HOST SETUP CHECKS CONFIGURATION
# Last Updated: 2025-11-11
# ============================================================================

# Enable host setup checks specifically for TNHL01
export DT_INCLUDE_HOST_SETUP=1

# Enable change log monitoring for TNHL01
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Host-specific environment variables
export SITE_NAME="mysite"
export HOSTNAME_CUSTOM="TNHL01"
export DT_LOG_DIR="/var/log/divtools/monitor"
```

## Example 4: Mixed Configuration

Enable checks at site level but disable for a specific host.

**File**: `docker/sites/mysite/.env.mysite`

```bash
# Site-wide settings
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
export SITE_NAME="mysite"
```

**File**: `docker/sites/mysite/TEST-SERVER/.env.TEST-SERVER`

```bash
# Override for test server - skip checks to avoid interruptions
export DT_INCLUDE_HOST_SETUP=0
export DT_INCLUDE_HOST_CHANGE_LOG=0
```

## Example 5: User-Level Override

Users can override site/host settings with their own preferences.

**File**: `~/.env`

```bash
# ============================================================================
# USER: divix
# PERSONAL ENVIRONMENT OVERRIDES
# Last Updated: 2025-11-11
# ============================================================================

# Skip setup checks - I've already run them and don't want prompts
export DT_INCLUDE_HOST_SETUP=0
export DT_INCLUDE_HOST_CHANGE_LOG=0

# Or enable them if you want
# export DT_INCLUDE_HOST_SETUP=1
# export DT_INCLUDE_HOST_CHANGE_LOG=1

# Other personal settings...
export DT_VERBOSE=2
```

## Example 6: Automation/CI/CD

For deployment scripts and automation that shouldn't prompt users:

**Deployment Script**: `deploy.sh`

```bash
#!/bin/bash
# Automated deployment script

# Skip all interactive setup checks during automation
export DIVTOOLS_SKIP_CHECKS=1

# Source the profile without interactive prompts
DIVTOOLS_SKIP_CHECKS=1 bash -i -c "your deployment commands here"
```

Or in Docker:

```dockerfile
FROM ubuntu:22.04

# ... your setup ...

# Skip setup checks when running in container
ENV DIVTOOLS_SKIP_CHECKS=1

# When running the container
CMD ["bash", "-i", "-c", "your application start command"]
```

## Example 7: Selective Enable

Enable only one check type per host.

**File**: `docker/sites/mysite/PROD-01/.env.PROD-01`

```bash
# Only check host setup, but not change log monitoring
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=0
export SITE_NAME="mysite"
```

## Example 8: Environment-Aware Configuration

Different settings for different environments.

**File**: `.env` (dynamically sourced by deployment)

```bash
# Load based on environment
case "${DEPLOY_ENV:-dev}" in
    production)
        # Strict checking in production
        export DT_INCLUDE_HOST_SETUP=1
        export DT_INCLUDE_HOST_CHANGE_LOG=1
        ;;
    staging)
        # Less strict in staging
        export DT_INCLUDE_HOST_SETUP=0
        export DT_INCLUDE_HOST_CHANGE_LOG=1
        ;;
    development)
        # Skip checks in development
        export DT_INCLUDE_HOST_SETUP=0
        export DT_INCLUDE_HOST_CHANGE_LOG=0
        ;;
esac
```

## Configuration Precedence Reference

When multiple `.env` files exist, they're sourced in this order (lowest to highest priority):

1. **Shared** (`docker/sites/s00-shared/.env.s00-shared`)
   - Sets defaults for entire infrastructure
   
2. **Site** (`docker/sites/<site-name>/.env.<site-name>`)
   - Overrides shared settings for all hosts in that site
   
3. **Host** (`docker/sites/<site-name>/<hostname>/.env.<hostname>`)
   - Overrides site settings for specific host
   
4. **User** (`~/.env`)
   - Overrides all others for current user
   - Personal preferences take highest priority

**Example**: If shared enables both checks, site disables change log, and host enables it back:
```
Shared: DT_INCLUDE_HOST_SETUP=1, DT_INCLUDE_HOST_CHANGE_LOG=1
Site:   DT_INCLUDE_HOST_CHANGE_LOG=0  (overrides shared)
Host:   DT_INCLUDE_HOST_CHANGE_LOG=1  (overrides site)
Result: DT_INCLUDE_HOST_SETUP=1, DT_INCLUDE_HOST_CHANGE_LOG=1
```

## Valid Values

All configuration options use the same valid values:

```bash
# These are equivalent (enabled):
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_SETUP=true
export DT_INCLUDE_HOST_SETUP="1"

# These are equivalent (disabled):
export DT_INCLUDE_HOST_SETUP=0
export DT_INCLUDE_HOST_SETUP=false
export DT_INCLUDE_HOST_SETUP=""

# Skip all checks (disable prompts):
export DIVTOOLS_SKIP_CHECKS=1
```

## Testing Your Configuration

To verify your settings are working:

```bash
# Check which variables are set
echo "Host Setup: $DT_INCLUDE_HOST_SETUP"
echo "Change Log: $DT_INCLUDE_HOST_CHANGE_LOG"
echo "Skip Checks: $DIVTOOLS_SKIP_CHECKS"

# Manually source and run checks
source ~/.env  # or relevant .env file
source $DIVTOOLS/scripts/util/host_setup_checks.sh
host_setup_checks
```

## Recommended Configurations

### For Small Deployments
**Shared level only** - everyone gets same defaults:
```bash
# docker/sites/s00-shared/.env.s00-shared
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

### For Large Infrastructure
**Shared + Site + Host** - layered approach:
```bash
# Shared defaults
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Site-specific overrides (if needed)
# docker/sites/<site>/.env.<site>

# Host-specific overrides (if needed)
# docker/sites/<site>/<host>/.env.<host>
```

### For CI/CD
**Disable in automation**:
```bash
# In CI/CD scripts or Docker images
export DIVTOOLS_SKIP_CHECKS=1
```

### For Development
**Mix of enabled and disabled**:
```bash
# ~/.env for developer
export DT_INCLUDE_HOST_SETUP=0      # Developer already set up
export DT_INCLUDE_HOST_CHANGE_LOG=1  # Want to monitor changes
export DT_VERBOSE=3                 # More debug output
```
