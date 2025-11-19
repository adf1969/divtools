# Host Setup Checks - Quick Reference Card

## One-Line Test

```bash
/home/divix/divtools/scripts/test_host_setup_checks.sh
```

## Manual Tests

### With Debug Output (shows what's happening)
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug
host_setup_checks
```

### With Test Mode (dry-run, no changes)
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -test
host_setup_checks
```

### With Both (debug + test)
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug -test
host_setup_checks
```

### Test from Shell Startup
```bash
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1
bash -i
# New shell should show menu
```

## Enable Permanently

### User Level (just you)
```bash
echo "export DT_INCLUDE_HOST_SETUP=1" >> ~/.env
echo "export DT_INCLUDE_HOST_CHANGE_LOG=1" >> ~/.env
```

### Site Level (all hosts in a site)
```bash
echo "export DT_INCLUDE_HOST_SETUP=1" >> docker/sites/SITE_NAME/.env.SITE_NAME
echo "export DT_INCLUDE_HOST_CHANGE_LOG=1" >> docker/sites/SITE_NAME/.env.SITE_NAME
```

### Shared Level (all hosts everywhere)
```bash
echo "export DT_INCLUDE_HOST_SETUP=1" >> docker/sites/s00-shared/.env.s00-shared
echo "export DT_INCLUDE_HOST_CHANGE_LOG=1" >> docker/sites/s00-shared/.env.s00-shared
```

## What Each Flag Does

| Flag | Effect | Use Case |
|------|--------|----------|
| `-debug` | Shows [DEBUG] messages | Troubleshooting why checks don't run |
| `-test` | Dry-run, no actual changes | Testing logic safely |
| Both | Shows everything, no changes | Full validation before production |
| Neither | Normal operation | Production use |

## Expected Debug Output (on incomplete system)

```
[DEBUG] host_setup_checks() started
[DEBUG] DT_INCLUDE_HOST_SETUP=1
[DEBUG] DT_INCLUDE_HOST_CHANGE_LOG=1
[DEBUG] Checking dt_host_setup status...
[DEBUG]   ~/.env does not exist - setup is INCOMPLETE
[DEBUG] dt_host_setup is NOT complete, adding to menu
[DEBUG] Checking host_change_log status...
[DEBUG]   Manifest NOT found - setup is INCOMPLETE
[DEBUG] host_change_log is NOT complete, adding to menu
[DEBUG] Found 2 incomplete setup(s)
```

Then the whiptail menu appears!

## Completion Indicators

### dt_host_setup Complete
- ✅ `~/.env` exists
- ✅ `~/.env` contains `SITE_NAME=`

### dt_host_setup Incomplete
- ❌ `~/.env` doesn't exist
- ❌ `SITE_NAME` not in `~/.env`

### host_change_log Complete
- ✅ `/var/log/divtools/monitor/monitoring_manifest.json` exists

### host_change_log Incomplete
- ❌ Manifest file doesn't exist

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Menu doesn't appear | Variables not set | `export DT_INCLUDE_HOST_SETUP=1` |
| No debug output | Not using -debug flag | Add `-debug` when sourcing |
| Scripts execute in test mode | Not using -test flag | Add `-test` when sourcing |
| Only runs in login shell | Design choice (interactive only) | Use `bash -i` |
| Nothing happens | Not in interactive shell | Use `bash -i` to test |

## File Locations

```
Main Script:
  /home/divix/divtools/scripts/util/host_setup_checks.sh

Test Script:
  /home/divix/divtools/scripts/test_host_setup_checks.sh

Documentation:
  /home/divix/divtools/dotfiles/docs/HOST_SETUP_CHECKS_*.md

Integration Point:
  /home/divix/divtools/dotfiles/.bash_profile (line ~1895)
```

## Key Points to Remember

1. **Variables Required**: `DT_INCLUDE_HOST_SETUP` and/or `DT_INCLUDE_HOST_CHANGE_LOG` must be set (=1)
2. **Interactive Shells Only**: Only runs in `bash -i`, not in scripts
3. **Test First**: Always use `-test` flag before running for real
4. **Debug Helps**: Use `-debug` to see exactly what's happening
5. **Precedence Matters**: User > Host > Site > Shared level for variables

## Common Scenarios

### Test New System (TNHL01)
```bash
/home/divix/divtools/scripts/test_host_setup_checks.sh
```

### Enable and Test
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
bash -i
# New shell shows menu
```

### Debug Why It's Not Working
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug
host_setup_checks
# See debug output explaining each step
```

### Dry-Run Before Production
```bash
export DT_INCLUDE_HOST_SETUP=1 DT_INCLUDE_HOST_CHANGE_LOG=1
source /home/divix/divtools/scripts/util/host_setup_checks.sh -debug -test
host_setup_checks
# See what would happen without changes
```

## Documentation Quick Links

- **Testing Guide**: `HOST_SETUP_CHECKS_TESTING.md`
- **Debug/Test Features**: `HOST_SETUP_CHECKS_DEBUG_TEST.md`
- **Full Reference**: `HOST_SETUP_CHECKS.md`
- **Quick Start**: `HOST_SETUP_CHECKS_QUICKSTART.md`
- **Configuration Examples**: `HOST_SETUP_CHECKS_CONFIG_EXAMPLES.md`

---

**Pro Tip**: Keep this card handy when testing. The test script is the easiest way to verify everything is working!

*Last Updated: 2025-11-11*
