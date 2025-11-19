# Host Setup Checks - Visual Reference

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      .bash_profile (Login)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Load exports and basic config                               │
│  2. Load ~/.env (user-level overrides)                          │
│  3. Initialize Starship/Prompt                                  │
│  4. Configure TMUX                                              │
│  5. Load environment files                                      │
│  6. ┌────────────────────────────────────────────────────┐      │
│     │  Host Setup Checks (MUST BE LAST)                │      │
│     ├────────────────────────────────────────────────────┤      │
│     │  ✓ Only runs if [[ $- == *i* ]] (interactive)    │      │
│     │  ✓ Checks DT_INCLUDE_* env vars                   │      │
│     │  ✓ Detects setup completion status               │      │
│     │  ✓ Shows whiptail menu if needed                 │      │
│     │  ✓ Executes selected setups                       │      │
│     └────────────────────────────────────────────────────┘      │
│  7. Update profile timestamp                                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Variable Flow

```
┌──────────────────────────────────┐
│  Shared Environment              │
│  s00-shared/.env.s00-shared      │
│  (Lowest Priority)               │
└────────────┬─────────────────────┘
             │
             ↓
┌──────────────────────────────────┐
│  Site Environment                │
│  <site>/.env.<site>              │
│  (Overrides Shared)              │
└────────────┬─────────────────────┘
             │
             ↓
┌──────────────────────────────────┐
│  Host Environment                │
│  <site>/<host>/.env.<host>       │
│  (Overrides Site)                │
└────────────┬─────────────────────┘
             │
             ↓
┌──────────────────────────────────┐
│  User Environment                │
│  ~/.env                          │
│  (Highest Priority)              │
└──────────────────────────────────┘
```

## Setup Execution Flow

```
Start Interactive Shell
        │
        ↓
Check: [[ $- == *i* ]] ?
        │
        ├─ NO → Exit (non-interactive)
        │
        └─ YES
            │
            ↓
    Check: DIVTOOLS_SKIP_CHECKS ?
            │
            ├─ YES → Skip all checks, exit
            │
            └─ NO
                │
                ↓
        Check DT_INCLUDE_HOST_SETUP ?
                │
                ├─ NO → Skip this check
                │
                └─ YES
                    │
                    ↓
            Check ~/.env has SITE_NAME ?
                    │
                    ├─ YES → Setup complete, skip
                    │
                    └─ NO → Add to menu
                        │
                        ↓
        Check DT_INCLUDE_HOST_CHANGE_LOG ?
                │
                ├─ NO → Skip this check
                │
                └─ YES
                    │
                    ↓
            Check monitoring_manifest.json exists ?
                    │
                    ├─ YES → Setup complete, skip
                    │
                    └─ NO → Add to menu
                        │
                        ↓
        Any incomplete setups ?
                │
                ├─ NO → Exit (all complete)
                │
                └─ YES
                    │
                    ↓
            Display warning banner
            Show whiptail menu (or fallback prompts)
                    │
                    ↓
            User selects setups
                    │
                    ├─ Clicked Cancel → Exit
                    │
                    └─ Clicked OK
                        │
                        ↓
                For each selected setup:
                    ├─ Run dt_host_setup
                    └─ Run host_change_log
                        │
                        ↓
                Show completion banner
```

## Whiptail Menu Visual

```
┌─────────────────────────────────────────────────────────────────┐
│                 Host Setup Configuration             [X] [─] [□] │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Select which host setups to run:                               │
│                                                                   │
│  [x] dt_host_setup        Host Setup (Environment & Variables)   │
│  [x] host_change_log      Host Change Log Monitoring             │
│                                                                   │
│                         < OK >    < Cancel >                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Color Reference

```
CYAN (\033[36m)
├─ [INFO] messages
├─ Prompts and questions
├─ Title and section headers
└─ Menu titles

YELLOW (\033[33m)
├─ ⚠️  Warnings
├─ Pending task indicators
└─ Non-critical alerts

GREEN (\033[32m)
├─ [SUCCESS] messages
└─ Completion confirmations

RED (\033[31m)
├─ [ERROR] messages
└─ Failed operations

RESET (\033[0m)
└─ Returns to terminal default
```

## Example Output Sequence

```
════════════════════════════════════════════════════════════════
⚠️  Pending Host Setup Tasks Detected
════════════════════════════════════════════════════════════════
  • Host Setup (Environment & Variables)
  • Host Change Log Monitoring

These setups have not been completed on this host.
Would you like to run them now?

(Whiptail menu appears)

[User selects both and clicks OK]

[INFO] Starting selected host setups...

[INFO] Running dt_host_setup.sh...

(dt_host_setup wizard runs with user interaction)

[SUCCESS] dt_host_setup.sh completed successfully.

[INFO] Running host_change_log.sh setup...

(host_change_log setup runs)

[SUCCESS] host_change_log.sh setup completed successfully.

[SUCCESS] Host setup tasks completed.

user@host:~$
```

## File Organization

```
divtools/
├── scripts/
│   ├── util/
│   │   ├── host_setup_checks.sh  ← Main script
│   │   └── host_chg_mon/
│   │       └── host_change_log.sh
│   └── dt_host_setup.sh
│
└── dotfiles/
    ├── .bash_profile              ← Modified to call host_setup_checks()
    └── docs/
        ├── HOST_SETUP_CHECKS.md                    ← Full reference
        ├── HOST_SETUP_CHECKS_QUICKSTART.md         ← Quick start
        ├── HOST_SETUP_CHECKS_CONFIG_EXAMPLES.md    ← Configuration examples
        └── (this file)                             ← Visual reference
```

## Configuration Decision Tree

```
Do you want to enable setup checks?
│
├─ No → Don't set any DT_INCLUDE_* variables
│
└─ Yes
   │
   ├─ For all hosts/sites globally?
   │  └─ Set in docker/sites/s00-shared/.env.s00-shared
   │
   ├─ For a specific site?
   │  └─ Set in docker/sites/<site>/.env.<site>
   │
   ├─ For a specific host only?
   │  └─ Set in docker/sites/<site>/<host>/.env.<host>
   │
   └─ For yourself only?
      └─ Set in ~/.env
```

## Integration Points

```
.bash_profile (line ~1895)
    │
    ├─ Calls host_setup_checks()
    │
    └─ host_setup_checks.sh
        │
        ├─ Reads environment variables
        │   └─ DT_INCLUDE_HOST_SETUP
        │   └─ DT_INCLUDE_HOST_CHANGE_LOG
        │   └─ DIVTOOLS_SKIP_CHECKS
        │
        ├─ Checks completion status
        │   ├─ check_host_setup_status()
        │   └─ check_host_change_log_status()
        │
        ├─ Builds whiptail menu
        │
        ├─ Runs selected setups
        │   ├─ run_host_setup()
        │   └─ run_host_change_log_setup()
        │
        └─ Provides feedback
```

## Status Indicators

### dt_host_setup Complete
```
✓ ~/.env exists
✓ SITE_NAME variable is set
→ Setup considered complete
```

### dt_host_setup Incomplete
```
✗ ~/.env missing or
✗ SITE_NAME not set
→ Setup check triggered, menu shown
```

### host_change_log Complete
```
✓ /var/log/divtools/monitor/monitoring_manifest.json exists
→ Setup considered complete
```

### host_change_log Incomplete
```
✗ monitoring_manifest.json not found
→ Setup check triggered, menu shown
```

## Quick Command Reference

```bash
# Check if variables are set
echo "Host Setup: $DT_INCLUDE_HOST_SETUP"
echo "Change Log: $DT_INCLUDE_HOST_CHANGE_LOG"

# Enable checks
export DT_INCLUDE_HOST_SETUP=1
export DT_INCLUDE_HOST_CHANGE_LOG=1

# Run checks in new shell
bash -i

# Skip checks temporarily
export DIVTOOLS_SKIP_CHECKS=1 && bash -i

# Manual invocation
source $DIVTOOLS/scripts/util/host_setup_checks.sh
host_setup_checks

# View documentation
cat $DIVTOOLS/dotfiles/docs/HOST_SETUP_CHECKS.md
cat $DIVTOOLS/dotfiles/docs/HOST_SETUP_CHECKS_QUICKSTART.md
cat $DIVTOOLS/dotfiles/docs/HOST_SETUP_CHECKS_CONFIG_EXAMPLES.md
```

## Error Handling

```
Setup Script Not Found
│
└─ Error message displayed
   └─ User continues with shell
      (no blocking)

Setup Script Failed
│
├─ Error message shown
└─ User continues
   (can retry later)

Permission Denied
│
├─ Usually sudo password prompt
└─ If sudo fails
   └─ Error message shown
      (user continues)
```

## Supported Environments

```
✓ Bash shells (interactive mode)
✓ With whiptail menu (preferred)
✓ Fallback text prompts (if no whiptail)
✓ Non-interactive shells (skipped gracefully)
✓ CI/CD environments (skipped with flag)
✓ SSH sessions (works normally)
✓ Terminal emulators (all ANSI-compatible)
```

## Security Considerations

```
┌─────────────────────────────────────────┐
│  Setup Execution                        │
├─────────────────────────────────────────┤
│                                         │
│  All setup scripts run with:            │
│  $ sudo ./setup_script.sh               │
│                                         │
│  User is NOT forced to run              │
│  ✓ Interactive menu selection           │
│  ✓ Cancel option available              │
│  ✓ No automatic execution               │
│                                         │
│  Password handling:                     │
│  ✓ System sudo, not stored in script   │
│  ✓ User prompted if needed              │
│  ✓ Sudo session respected               │
│                                         │
└─────────────────────────────────────────┘
```

## Troubleshooting Visual

```
Checks don't appear
│
├─ Variable not set?
│  └─ Check: echo $DT_INCLUDE_HOST_SETUP
│
├─ Non-interactive shell?
│  └─ Use: bash -i
│
├─ Setup already complete?
│  └─ Check completion indicators
│
└─ DIVTOOLS_SKIP_CHECKS=1?
   └─ Unset or set to 0

No whiptail menu (just prompts)
│
├─ Whiptail not installed?
│  └─ Install: sudo apt install whiptail
│
├─ Not in interactive terminal?
│  └─ Open proper terminal session
│
└─ System falls back gracefully
   └─ Text prompts work fine

Setup script fails
│
├─ Permission denied?
│  └─ Check sudo access
│
├─ Script not found?
│  └─ Verify DIVTOOLS path
│
└─ Internal failure?
   └─ Run script manually to debug
```
