# Host Setup Checks Feature

## Overview

The `host_setup_checks()` function provides an interactive, user-friendly way to verify and execute required host setup tasks when a bash shell starts in interactive mode. This system is designed to be the **last thing that runs in `.bash_profile`** after all other initialization is complete.

## How It Works

### Basic Flow

1. **Detection**: When an interactive bash shell starts, the `host_setup_checks()` function runs
2. **Status Check**: For each enabled setup, the system checks if it has been completed
3. **Notification**: If any setups are incomplete, the user is notified with a whiptail menu
4. **Selection**: The user can select which setups to run
5. **Execution**: Selected setups are executed in sequence

### Environment Variables

Each setup type is controlled by a corresponding environment variable:

| Variable | Setup | Description |
|----------|-------|-------------|
| `DT_INCLUDE_HOST_SETUP` | `dt_host_setup.sh` | Enables checking/running host environment setup (site name, paths, variables) |
| `DT_INCLUDE_HOST_CHANGE_LOG` | `host_change_log.sh setup` | Enables checking/running host change log monitoring setup |
| `DIVTOOLS_SKIP_CHECKS` | All | Set to 1 to skip all setup checks (useful for automation) |

### Variable Precedence

Environment variables can be set at multiple levels, with precedence from highest to lowest:

1. **User level** (highest): `~/.env`
2. **Host level**: `docker/sites/<site-name>/<hostname>/.env.<hostname>`
3. **Site level**: `docker/sites/<site-name>/.env.<site-name>`
4. **Shared level** (lowest): `docker/sites/s00-shared/.env.s00-shared`

## Configuration Examples

### Enable All Checks at Site Level

```bash
# In docker/sites/mysite/.env.mysite
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

### Enable Checks at Host Level

```bash
# In docker/sites/mysite/MYHOST/.env.MYHOST
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

### Enable Checks at User Level

```bash
# In ~/.env
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

### Skip Checks for Automated Deployments

```bash
# For one-time use during automation
export DIVTOOLS_SKIP_CHECKS=1 && source ~/.bash_profile

# Or add to a deployment script
DIVTOOLS_SKIP_CHECKS=1 bash -i -c "your command here"
```

## Whiptail Menu Interface

When a setup is incomplete and whiptail is available, you'll see:

```
════════════════════════════════════════════════════════════════
⚠️  Pending Host Setup Tasks Detected
════════════════════════════════════════════════════════════════
  • Host Setup (Environment & Variables)
  • Host Change Log Monitoring

These setups have not been completed on this host.
Would you like to run them now?
```

The whiptail interface:
- Displays a checklist of incomplete setups
- Has all items checked by default
- Uses the same color scheme as `dt_host_setup.sh` for consistency
- Allows you to uncheck items you don't want to run
- Supports OK/Cancel buttons

### Fallback to Simple Prompts

If whiptail is not available or you're not in an interactive terminal, the system falls back to simple yes/no prompts for each setup.

## Completion Detection

### dt_host_setup Completion
The system considers `dt_host_setup` complete when:
- `~/.env` file exists
- `~/.env` contains a `SITE_NAME` variable

### host_change_log Completion
The system considers `host_change_log` complete when:
- The monitoring manifest file exists at `${DT_LOG_DIR}/monitoring_manifest.json`
- Default `DT_LOG_DIR` is `/var/log/divtools/monitor`

## Implementation Details

### Function Location
```
/home/divix/divtools/scripts/util/host_setup_checks.sh
```

### Sourcing in .bash_profile
In the `.bash_profile` interactive shell section (after all other initialization), the function is:
1. Sourced from the script file
2. Called immediately after sourcing

```bash
if [[ $- == *i* ]]; then
    # ... other initialization ...
    
    # MUST BE LAST in interactive shell initialization
    if [ -f "$DIVTOOLS/scripts/util/host_setup_checks.sh" ]; then
        source "$DIVTOOLS/scripts/util/host_setup_checks.sh"
        host_setup_checks
    fi
fi
```

## Security Considerations

- The scripts require `sudo` to execute (for root-level configuration)
- The check system respects the user's choice - no changes happen without explicit action
- Failed setup attempts don't block future attempts
- All color output follows standard ANSI conventions

## Troubleshooting

### No whiptail menu appears
- Check that whiptail is installed: `which whiptail`
- Verify you're in an interactive terminal
- The system will fall back to simple prompts if whiptail is unavailable

### Checks don't appear even though I set the variables
- Verify variables are set: `echo $DT_INCLUDE_HOST_SETUP`
- Check that you're in an interactive shell (not running a script with `bash -c`)
- Try: `DIVTOOLS_SKIP_CHECKS=0 bash -i` to force interactive mode

### Setup scripts fail with permission errors
- The setup scripts require `sudo` access
- Ensure your user can run `sudo` commands
- Check that the setup scripts exist at the correct paths

### Variable not being picked up from .env files
- Verify the .env file path is correct
- Check that variables are exported: `export DT_INCLUDE_HOST_SETUP=1`
- Source the file manually to debug: `source ~/.env && echo $DT_INCLUDE_HOST_SETUP`

## Adding New Setups

To add a new setup check to the system:

1. **Create the setup script** following the pattern of existing scripts
2. **Add detection function** to check completion status
3. **Add run function** to execute the setup
4. **Update host_setup_checks.sh** to include:
   - New environment variable check (e.g., `DT_INCLUDE_NEW_SETUP`)
   - Call to detection function
   - Call to run function
5. **Update .bash_profile** if needed (usually not required)
6. **Document** in this README

Example addition:

```bash
# In host_setup_checks.sh

# Check if new_setup has been run
check_new_setup_status() {
    # Check for completion indicator
    if [ -f ~/.new_setup_completed ]; then
        return 0  # Setup completed
    else
        return 1  # Setup not completed
    fi
}

# Run new_setup.sh
run_new_setup() {
    local dt_home=$(get_divtools_path)
    local setup_script="$dt_home/scripts/util/new_setup.sh"
    
    if [ -f "$setup_script" ]; then
        echo ""
        echo -e "\033[36m[INFO] Running new_setup.sh...\033[0m"
        echo ""
        sudo "$setup_script"
        local exit_code=$?
        echo ""
        if [ $exit_code -eq 0 ]; then
            echo -e "\033[32m[SUCCESS] new_setup.sh completed successfully.\033[0m"
        else
            echo -e "\033[31m[ERROR] new_setup.sh failed with exit code $exit_code.\033[0m"
        fi
        return $exit_code
    else
        echo -e "\033[31m[ERROR] new_setup.sh not found at: $setup_script\033[0m"
        return 1
    fi
}

# In host_setup_checks() function, add:
if [ "${DT_INCLUDE_NEW_SETUP:-0}" == "1" ] || [ "${DT_INCLUDE_NEW_SETUP:-0}" == "true" ]; then
    if ! check_new_setup_status; then
        setups_to_show+=("new_setup")
        setup_descriptions+=("New Setup Description")
    fi
fi

# And in the run section:
case "$setup" in
    "new_setup")
        run_new_setup
        ;;
esac
```

## Color Scheme

The system uses ANSI color codes consistent with divtools standards:

- **Cyan** (`\033[36m`): Informational messages and prompts
- **Yellow** (`\033[33m`): Warnings and pending tasks
- **Green** (`\033[32m`): Success messages
- **Red** (`\033[31m`): Error messages
- **Reset** (`\033[0m`): Resets color to terminal default

Whiptail colors match `dt_host_setup.sh` exactly for visual consistency.

## Last Updated

2025-11-11
