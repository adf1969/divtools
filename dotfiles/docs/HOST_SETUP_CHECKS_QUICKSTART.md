# Host Setup Checks - Quick Start Guide

## TL;DR - Getting Started

### 1. Enable Host Setup Checks

Add these environment variables to one of your `.env` files:

**For the whole site** (`docker/sites/mysite/.env.mysite`):
```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

**For a specific host** (`docker/sites/mysite/MYHOST/.env.MYHOST`):
```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

**For the current user** (`~/.env`):
```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
```

### 2. Start a New Interactive Shell

```bash
bash -i
```

Or just open a new terminal session. You should see the setup checks menu on your next login.

## What Happens

1. When you open an interactive bash shell, `host_setup_checks()` runs automatically
2. For each enabled setup type, it checks if that setup has been completed
3. If any setups are incomplete, you'll see a whiptail menu with a list of available setups
4. All incomplete setups are pre-selected by default
5. You can uncheck any you don't want to run, then click OK
6. Each selected setup runs with `sudo` (you may be prompted for password)

## Supported Setups

### DT_INCLUDE_HOST_SETUP
**Setup**: `dt_host_setup.sh`
**Purpose**: Configures host environment variables and paths
**Completion Check**: Looks for `SITE_NAME` in `~/.env`
**Runs**: Whiptail-based interactive configuration wizard

### DT_INCLUDE_HOST_CHANGE_LOG
**Setup**: `host_change_log.sh setup`
**Purpose**: Sets up host change monitoring and logging
**Completion Check**: Looks for monitoring manifest at `/var/log/divtools/monitor/monitoring_manifest.json`
**Runs**: Automated setup script with logging configuration

## Common Tasks

### Skip checks for a one-time command
```bash
export DIVTOOLS_SKIP_CHECKS=1 && bash -i
```

### Manually run setup checks
```bash
# Source and run the checks manually
source $DIVTOOLS/scripts/util/host_setup_checks.sh
host_setup_checks
```

### Force checks to run even if already completed
Edit the status check functions in `host_setup_checks.sh` or delete the completion indicator files:
```bash
# For dt_host_setup - delete SITE_NAME from ~/.env
# For host_change_log - delete the manifest
rm /var/log/divtools/monitor/monitoring_manifest.json
```

### Check if setups are enabled
```bash
echo "Host Setup: $DT_INCLUDE_HOST_SETUP"
echo "Change Log: $DT_INCLUDE_HOST_CHANGE_LOG"
```

## Whiptail Menu Shortcuts

When the whiptail menu appears:
- **Arrow keys** or **Tab**: Navigate between options
- **Space**: Toggle a checkbox on/off
- **Enter**: Select OK (runs selected setups)
- **Esc**: Cancel (skips all setups)

## Troubleshooting

**Q: The menu doesn't appear when I open a new shell**
- Check that variables are enabled: `echo $DT_INCLUDE_HOST_SETUP`
- Verify you're in an interactive shell (not a login script)
- Check that the setup is actually incomplete

**Q: I see "Permission denied" errors**
- The setup scripts need `sudo` access
- Try running: `sudo echo` to test sudo access
- You may need to configure passwordless sudo for these scripts

**Q: Whiptail menu doesn't appear, just prompts**
- Whiptail isn't installed on your system
- Install it: `sudo apt install whiptail` (Debian/Ubuntu)
- The system will use simple yes/no prompts instead

**Q: I want to enable checks but not run them every time**
- Use `export DIVTOOLS_SKIP_CHECKS=1` in your interactive shell
- Or disable the variable in your `.env` files

## File Locations

- **Script**: `/home/divix/divtools/scripts/util/host_setup_checks.sh`
- **Called from**: `/home/divix/divtools/dotfiles/.bash_profile`
- **Documentation**: `/home/divix/divtools/dotfiles/docs/HOST_SETUP_CHECKS.md`
- **Environment variables**: Set in `.env` files at various levels

## For Administrators

If you want to enable these checks across your entire infrastructure:

1. **Add to shared env** (`docker/sites/s00-shared/.env.s00-shared`):
   ```bash
   export DT_INCLUDE_HOST_SETUP=1
   export DT_INCLUDE_HOST_CHANGE_LOG=1
   ```

2. **Override per host** if needed by setting in host-level `.env` files

3. **Skip for CI/CD** in automation by setting `DIVTOOLS_SKIP_CHECKS=1`

4. **Monitor completion** by checking for indicator files

## Color Coding

- **Cyan** - Information and prompts
- **Yellow** - Warnings and pending tasks  
- **Green** - Success messages
- **Red** - Error messages

All colors are ANSI-compatible and work in modern terminals.
