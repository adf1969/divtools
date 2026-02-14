# Divtools Workspace Instructions

## Summary MD Files

- NEVER create SUMMARY.MD files UNLESS I REQUEST THEM.
- If you get to a point where you think they are useful, ASK ME FIRST, and I will answer "Yes" if I want them.
- If you do create them, always put them in a sub-folder of the folder you are working in, named docs/.

## Test Scripts

- If you write a Test script to test a main script, those scripts should go in a sub-folder under the main script called .'test'.
- Example, if working on a script in the scripts/frigate/ folder, the test script should go in the scripts/frigate/test folder.
- When writing tests for python, use the pytest framework.
- When writing tests for node.js, use the vitest framework.
- When writing any test, use the test descriptions options for that framework to adequately and clearly define what the test is testing. Attempt as much as possible to adhere to a 1-function:1-test methodology. This means when testing MCP servers, test one tool with one test. Ensure that the test reflects the tool name in either the test name, or the test description.
- When writing tests that modify, ensure there is an appropriate "tear-down" method that returns the system back to the prior state. Always ensure the User knows when you are writing tests that could affect the permanence of the system. Ensure those tests are NOTED to the user before running them.

## Workspace Overview

**divtools** is a comprehensive collection of tools and configurations for Unix/Linux host management, including:

- Docker container configurations and compose files
- System administration scripts
- Configuration files (dotfiles, monitoring, networking)
- Ansible playbooks
- QNAP NAS configurations

## Context-Aware File Inclusion Rules

### General Divtools Development

When working on general divtools development, **always include**:

- `dotfiles/` folder - shell configurations, profiles, rc files
- `scripts/` folder - all administrative scripts and utilities
- `divtools_install.sh` - main installation script
- `docker/sites/**/.env.*` files - environment variable definitions for each host

### Docker Development

When working on Docker containers, compose files, or container configurations, **include**:

- `docker/sites/*/` folders - site-specific configurations
- `docker/docker-compose-*.yml` files - compose file templates
- `docker/sites/**/.env.*` files - environment variables for containers
- `docker/include/` folder - shared include files
- `docker/config/` folder - container-specific config files
- `dotfiles/` folder - shell configurations, profiles, rc files
When building docker files, always include the labels section which is used by the docker_ps.sh file.
Example:
    labels:
      - "divtools.group=moodle"
When EVER you run a code like this:
 PGPASSWORD='directpsqlpass2' psql -h localhost -U testuser -d postgres -c "SELECT 'Direct psql env var password update verified!';"
 NEVER include the "!" at the end. That BREAKS the bash prompt. Just use a simple period, or nothing all. NEVER include ! in any sort of psql command.

### Scripts Development

When working on scripts, **include**:

- `scripts/` root folder - main scripts
- `scripts/util/` folder - utility functions (especially `logging.sh`)
- `scripts/*/` subfolders relevant to the task (e.g., `scripts/pve/`, `scripts/frigate/`)
- Related config files from `config/` if the script uses them
- When writing scripts, be aware that you CANNOT use the "local" keyword OUTSIDE of a function. It MUST be in a function to be used.
- When updating scripts or any code, always add a recently modified indicator at the top of the function, formatted as follows:
  <comment-marker> Last Updated: <timestamp> <TZ>
Example: # Last Updated: 11/20/2025 11:00:00 AM CDT
The timestamp used, should be the CORRECT time for that Timezone.

#### Script Path References - CRITICAL RULE

**ALWAYS use `$DIVTOOLS` environment variable or relative paths for script references**, never hardcoded absolute paths like `/home/divix/divtools/...`

**Why:**
- Divtools can be installed in different locations on different systems
- Using `$DIVTOOLS` ensures portability across environments
- Relative paths work within the divtools directory structure

**How to Reference Other Scripts:**

```bash
#!/bin/bash
# Correct way to reference other divtools scripts
source "$DIVTOOLS/scripts/util/logging.sh"
source "$(dirname "$0")/../util/logging.sh"  # Relative (also acceptable)

# Calling other divtools scripts
python3 "$DIVTOOLS/scripts/smtp/send_email.py" --to user@example.com ...
"$DIVTOOLS/scripts/postgres/pg_backrest_backup.sh" -incr -email

# WRONG - never do this:
python3 /home/divix/divtools/scripts/smtp/send_email.py ...  # ❌ Hardcoded path
```

**Key Points:**
- Use `$DIVTOOLS` variable for absolute path references
- Use relative `$(dirname "$0")/...` for accessing sibling scripts/utilities
- Both methods are acceptable; choose based on context
- Always ensure `$DIVTOOLS` is set before calling other scripts (usually via `load_env_files()`)

#### Credential Storage (REQUIRED)

**REQUIREMENT:** Any `mcp-server` or script must never contain hardcoded credentials. Store credentials outside source files — preferably in a `.env` (or `.env.$HOSTNAME`) loaded via `load_env_files()`, or in a `secrets/` subfolder adjacent to the script/server (for example `mcp-servers/<server>/secrets/.env.secret` or `scripts/<tool>/secrets/.env`).

Guidelines:
- Do not commit secret files to git. Ensure `.gitignore` includes patterns such as `mcp-servers/**/secrets/*` and `scripts/**/secrets/*`.
- Load secrets at runtime rather than hardcoding them. Example pattern for shell scripts:

```bash
# Load secrets from external file (if present)
SECRETS_FILE="$SCRIPT_DIR/secrets/.env.secret"
if [[ -f "$SECRETS_FILE" ]]; then
  source "$SECRETS_FILE"
fi

# Use environment variables (no hardcoded fallback credentials)
NODE_RED_AUTH="${NODE_RED_AUTH:-}"
```

- Prefer using environment variables in code (e.g. `DB_PASSWORD=${DB_PASSWORD:-}`) and avoid default fallback values that contain real credentials.
- If a secret must be referenced by name, prefer clearly suffixed filenames such as `.jwt_secret`, `.bin_secret`, or place them under `secrets/` to make them easy to ignore.

Rationale: centralizing secrets prevents accidental commits, simplifies secret rotation, and keeps repositories safe.

#### Environment Variable Loading in Divtools Scripts

**CRITICAL RULE**: ALL divtools scripts must use `load_env_files()` from `.bash_profile`
for environment variable management. This ensures consistent, centralized environment
handling across the entire workspace.

**Why:**

- Single source of truth for environment variables (`.bash_profile`)
- Changes to environment loading logic only need to be made in one place
- Consistent behavior across all scripts and tools
- Avoids duplicate environment loading logic scattered throughout scripts

**How to Implement:**

Use the pattern demonstrated in `scripts/vscode/vscode_host_colors.sh`:

```bash
#!/bin/bash
# Your script description
# Last Updated: MM/DD/YYYY HH:MM:SS AM/PM TZ

# Source logging utilities
source "$(dirname "$0")/../util/logging.sh"

# Load environment files using .bash_profile function
# This ensures consistent environment variable management across all divtools
load_environment() {
    # Try to source .bash_profile if load_env_files is not yet available
    if ! declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "load_env_files not found, sourcing .bash_profile..."
        if [[ -f "$HOME/.bash_profile" ]]; then
            source "$HOME/.bash_profile" 2>/dev/null
        fi
    fi

    # Call the standard divtools environment loader
    if declare -f load_env_files >/dev/null 2>&1; then
        log "DEBUG" "Calling load_env_files() to load environment..."
        load_env_files
        log "DEBUG" "Environment loaded: SITE_NAME=$SITE_NAME"
    else
        log "ERROR" "load_env_files function not found"
        return 1
    fi
}

# Call the environment loader early in script execution
load_environment || exit 1

# Now use environment variables loaded by .bash_profile
echo "Site: $SITE_NAME, Host: $HOSTNAME"
```

**Key Points:**

- Call `load_environment()` (or `load_env_files()`) early in execution
- Use pattern above to handle both interactive and non-interactive shells
- Environment variables available: `$SITE_NAME`, `$HOSTNAME`, `$DOCKER_HOSTDIR`
- Never implement custom environment loading logic
- This applies to: main scripts, helper scripts, setup scripts, utilities

**Real-World Example** (`dt_ads_setup.sh`):

```bash
# Load environment variables with defaults for ADS-specific variables
load_env_vars() {
    # Use the standard divtools environment loader
    load_environment

    # Load ADS-specific defaults from .env file if it exists
    if [[ -f "$ENV_FILE" ]]; then
        log "DEBUG" "Loading ADS defaults from $ENV_FILE"
        # Source variables from the auto-managed section
        eval "$(grep -E '^(ADS_|SITE_NAME)' "$ENV_FILE" 2>/dev/null | \
            sed 's/^/export /')"
    fi
}
```

This approach:

- Leverages `load_env_files()` for core environment variables
- Adds script-specific variable loading on top
- Maintains separation of concerns
- Single point of maintenance for divtools environment logic

#### Whiptail Color Scheme for Interactive Menus

**STANDARD RULE**: ALL divtools scripts using whiptail for interactive menus must use
the standard high-contrast color scheme with enhanced button highlighting. This ensures
consistent user experience across all tools.

**Color Configuration:**

Use the `set_whiptail_colors()` function in all scripts with interactive whiptail menus:

```bash
# Function to set whiptail colors
# Last Updated: 12/7/2025 12:00:00 AM CDT
set_whiptail_colors() {
    # Set whiptail color environment variables for high-contrast theme
    # with clear button selection
    export NEWT_COLORS='
        root=,black
        window=,black
        border=white,black
        textbox=white,black
        button=black,white
        actbutton=white,blue
        compactbutton=black,white
        title=cyan,black
        label=cyan,black
        entry=white,black
        checkbox=cyan,black
        actcheckbox=black,cyan
        listbox=white,black
        actlistbox=black,cyan
        sellistbox=black,cyan
        actsellistbox=white,blue
    '
    log "DEBUG" "Applied custom whiptail color scheme..."
} # set_whiptail_colors

# Call at script start (after logging.sh is sourced)
set_whiptail_colors
```

**Whiptail Call Standard:**

ALL whiptail calls must include the `--fb` flag for full buttons:

```bash
# Good - uses --fb flag and NEWT_COLORS
whiptail --fb --title "My Menu" --menu "Choose option:" 20 70 10 \
    "1" "Option 1" \
    "2" "Option 2" \
    3>&1 1>&2 2>&3

# Good - input box with --fb
whiptail --fb --inputbox "Enter value:" 10 60 "default" 3>&1 1>&2 2>&3

# Good - confirmation dialog with --fb
whiptail --fb --yesno "Confirm action?" 10 60

# Good - message box with --fb
whiptail --fb --msgbox "Operation complete!" 10 60

# Bad - missing --fb flag
whiptail --title "My Menu" --menu "Choose option:" 20 70 10 ...
```

**Implementation Checklist:**

- [ ] Define `set_whiptail_colors()` function in script
- [ ] Call `set_whiptail_colors` early in script execution (after logging.sh)
- [ ] Add `--fb` flag to EVERY whiptail call
- [ ] Use consistent dialogue dimensions (most common: 10 60 for inputs, 20 70 10 for menus)
- [ ] Test colors display correctly on target systems

**Real-World Example** (from `dt_ads_setup.sh`):

```bash
#!/bin/bash
# Source logging
source "$SCRIPT_DIR/../util/logging.sh"

# Define color function
set_whiptail_colors() {
    export NEWT_COLORS='...' # (full color scheme as above)
    log "DEBUG" "Applied custom whiptail color scheme..."
}

# Call at start
set_whiptail_colors

# Use in code
whiptail --fb --yesno "Continue?" 10 60
whiptail --fb --inputbox "Enter value:" 10 60 "default" 3>&1 1>&2 2>&3
whiptail --fb --menu "Choose:" 20 70 10 "1" "Option 1" "2" "Option 2" 3>&1 1>&2 2>&3
```

**Color Scheme Details:**

| Element | Colors | Purpose |
|---------|--------|---------|
| `root` | ,black | Root window background |
| `window` | ,black | Window background |
| `border` | white,black | Window border |
| `button` | black,white | Inactive button text/bg |
| `actbutton` | white,blue | Active button (focused) |
| `title` | cyan,black | Window title text |
| `entry` | white,black | Input field |
| `checkbox` | cyan,black | Unchecked checkbox |
| `actcheckbox` | black,cyan | Checked checkbox |
| `listbox` | white,black | List items |
| `actlistbox` | black,cyan | Highlighted list item |
| `actsellistbox` | white,blue | Selected list item |

### Projects Development

When working in the ./projects folder or any sub-folder of it, **include**:

- The specific project folder you are working in (e.g., `projects/home_automation/`, `projects/web_dev/`)
- Any relevant scripts from `scripts/` that pertain to the project
- Assume that configuration files for the project (AGENTS.md) are included in the projects/<sub-folder>. That would include package.json or any other files needed for the project.
- The project should be developed to run from the projects/<sub-folder> itself, so any paths should be relative to that.
- Include the .github/.copilot-instructions.md file in context for the project as well.
- Documentation files in the projects/<sub-folder>/docs/ folder.
- Test files in the projects/<sub-folder>/test/ folder.
- When building Docker images using docker-compose.yml and Dockerfile, name the files as follows:
  - dca-<appname>.yml: for the docker-compose.yml file (Docker Compose App)
  - <appname>.Dockerfile: for the Dockerfile

#### Project Documentation Standard

Every new project should have two core documentation files in `projects/<project-name>/docs/`:

**1. PRD.md (Product Requirements Document)**

- Functional, non-functional, and system requirements
- Technical architecture and design decisions
- Implementation phases with clear deliverables
- Requirements table with Phase column for tracking scope
- Use format: `| Requirement ID | Phase | Description | User Story | Expected Behavior/Outcome |`

**2. PROJECT-HISTORY.md (Development Tracking & Decisions)**

- Project origin and evolution
- Architectural decisions with rationale
- Outstanding Questions marked with `❓ OUTSTANDING` comment markers (for VS Code TODO tracking)
  - Questions include multiple options with recommendations
  - Each question has a dedicated **Answer** section below it
  - Empty Answer sections indicate questions still awaiting decisions
  - When answered, Answer sections are filled with decision rationale and implementation notes
  - Sub-questions can be added below main questions for ongoing discussion history
- Chat session history tracking progress
- Implementation status and next steps

**Outstanding Questions Format:**
Structure each question with this pattern:

```markdown
### ❓ OUTSTANDING - Qn: Question Title
**Question:** Clear statement of the decision needed
- **Option A:** First option with brief description
- **Option B:** Alternative option
- **Option C:** Another alternative

**Context/Impact:** Why this decision matters

### Answer
**Decision:** Selected option letter and title

Detailed explanation of the decision, rationale, and any implementation notes. 
This can be multiple paragraphs as needed.

---
```

**Key Points for Answer Sections:**

- Use `### Answer` as a structural heading (easily searchable)
- Include `**Decision:**` prefix with the chosen option
- Explanation can span multiple paragraphs
- Empty Answer section = question still awaiting decision (no status marker needed)
- Filled Answer section = question resolved
- Makes questions auto-discoverable in VS Code outline view

**Recommended VS Code Extensions for Project Tracking:**

- `gruntfuggly.todo-tree` - Shows TODO/FIXME items in a tree view sidebar
  - Automatically highlights `# ❓ OUTSTANDING` markers
  - Jump directly to questions from tree view
  - Helpful for rapid navigation between outstanding decisions
- `aaron-bond.better-comments` - Enhanced comment highlighting
  - Can configure `❓` as custom tag with special color/icon

### Frigate Development

When working on Frigate (video surveillance), **include**:

- `docker/sites/**/frigate*/` folders - Frigate configurations across all sites
- `scripts/frigate/` folder - Frigate-related scripts
- `docker/sites/**/.env.*` files containing `FRIGATE_*` variables
- Frigate compose files: `docker/docker-compose-frigate*.yml`

### Python Development

**ALL Python projects in divtools use the shared `dtpyutil` virtual environment.**

#### dtpyutil - Divtools Python Utilities

**Location**: `projects/dtpyutil/`
**Venv**: `scripts/venvs/dtpyutil/`
**Source**: `projects/dtpyutil/src/dtpyutil/` (package root)
**Purpose**: Centralized Python environment and shared libraries for all divtools Python code

**Key Principles**:
1. **Single Shared Venv** - One Python environment for ALL divtools Python utilities
2. **Editable Install** - Changes to `dtpyutil` source code take effect immediately
3. **Importable Libraries** - Shared code (menu, logging, CLI helpers) importable by all projects
4. **File-Based IPC** - Menu system uses files for bash integration (fixes Textual centering issues)

#### Installation

```bash
cd $DIVTOOLS/projects/dtpyutil
bash scripts/install_dtpyutil_deps.sh
```

This creates:
- Venv at `$DIVTOOLS/scripts/venvs/dtpyutil/`
- Installs Textual, pytest, and other dependencies
- Installs dtpyutil in editable mode (`pip install -e`)

#### Using dtpyutil in Projects

**From Python Projects**:

```python
#!/usr/bin/env python3
# File: projects/myproject/my_script.py

import sys
from pathlib import Path

# Add dtpyutil to Python path
dtpyutil_path = Path(__file__).parent.parent / "dtpyutil" / "src"
sys.path.insert(0, str(dtpyutil_path))

# Now import from dtpyutil
from menu.dtpmenu import DtpMenuApp

# Or with editable install (after install_dtpyutil_deps.sh):
from dtpyutil.menu import DtpMenuApp
```

**From Bash Scripts**:

```bash
#!/bin/bash
# Source the dtpyutil menu wrapper
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# Set centering flags
export PMENU_H_CENTER=1
export PMENU_V_CENTER=1

# Use menu functions (with file-based IPC for proper centering)
choice=$(pmenu_menu "Main Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit")

if [[ $? -eq 0 ]]; then
    echo "Selected: $choice"
fi
```

**Running Python Scripts**:

```bash
# Use dtpyutil venv for execution
PYTHON_CMD="$DIVTOOLS/scripts/venvs/dtpyutil/bin/python"
"$PYTHON_CMD" "$DIVTOOLS/projects/myproject/my_script.py"
```

#### Critical: Textual TUI + Bash Integration

**⚠️ NEVER use command substitution with Textual TUIs directly** (it breaks centering)

**The Problem**:
```bash
# ❌ BROKEN - stdout piped to buffer, Textual can't detect screen size
choice=$(python3 dtpmenu.py menu --title "Choose" tag1 "Option 1")
# Result: Menu appears at top-left instead of centered
```

**The Solution (dtpyutil bash_wrapper.sh uses file-based IPC)**:
```bash
# ✅ WORKS - bash_wrapper.sh uses --output-file internally
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"
choice=$(pmenu_menu "Choose" tag1 "Option 1")  # Centers properly!
```

See `projects/dtpyutil/docs/BASH-INTEGRATION.md` for full details on why this happens and how file-based IPC solves it.

#### Project Structure Guidelines

**When to add code to dtpyutil**:
- ✅ Multiple projects need the same functionality
- ✅ Code is general-purpose and reusable
- ✅ Functionality is stable
- ✅ Minimal external dependencies

**When to keep code in project folder**:
- ✅ Project-specific business logic
- ✅ Rapidly evolving code during development
- ✅ Experimental features
- ✅ Tightly coupled to project data structures

**Migration Path**:
When project-specific code becomes reusable:
1. Copy to `projects/dtpyutil/src/newlib/`
2. Generalize (remove project assumptions)
3. Add tests to `projects/dtpyutil/test/`
4. Document API in `projects/dtpyutil/docs/`
5. Update project to import from dtpyutil

#### Documentation

- **PROJECT-DETAILS.md** - Architecture, design decisions, current status
- **PROJECT-HISTORY.md** - Development history, lessons learned from dtpmenu migration
- **BASH-INTEGRATION.md** - Critical guide for Textual + Bash integration (MUST READ)
- **README.md** - Quick start guide

#### Testing

```bash
# Test dtpyutil libraries
cd $DIVTOOLS/projects/dtpyutil
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/

# Test project using dtpyutil
cd $DIVTOOLS/projects/myproject
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/
```

#### Editable Install Mechanics

**Q: Can I still edit dtpyutil files after `pip install -e`?**
**A**: Yes! That's the point of editable install. Changes to `projects/dtpyutil/src/` take effect immediately without reinstalling.

**Q: How do I update dtpyutil after editing?**
**A**: No action needed! Editable install creates symlinks. Changes are live immediately.

**Q: How do I add new dependencies?**
**A**: Edit `projects/dtpyutil/scripts/install_dtpyutil_deps.sh`, add to `install_packages()`, then re-run the script.

### Postgres Development

When working on PostgreSQL backups and administration, **include**:

- `scripts/postgres/` folder - PostgreSQL-related scripts (backups, utilities)
- `docker/sites/**/postgres*/` folders - PostgreSQL container configurations
- `docker/sites/**/.env.*` files - PostgreSQL-related environment variables

**Key Constraints & Patterns:**

#### PostgreSQL in Docker Containers

- **PostgreSQL runs in Docker containers**, NOT on the host system
- Cannot SSH directly to PostgreSQL or execute host-level commands
- Must work with bind-mounted data directories (e.g., `/opt/postgres/pgdata` on host)
- Use `--no-online --force` flags in pgBackRest to backup without live DB connection
- Container must be running for backups to access bind-mounted files
- This is the **standard pattern** for all divtools PostgreSQL setups

#### Backup Notifications & Email

- **SMTP Server:** Use `$SMTP_SERVER` environment variable (default: `monitor`)
- **Email Sending:** Always use `$DIVTOOLS/scripts/smtp/send_email.py` utility for email
- **Priority Handling:**
  - Use `--high-priority` flag **ONLY** for actual failures
  - Informational emails (SUCCESS, NO CHANGES) should use normal priority
  - High priority headers should never be set for routine operational emails
- **Port Selection:**
  - Port 25: Open relay (recommended for internal mail servers)
  - Port 587: Submission with STARTTLS (requires authentication)
- **Load SMTP variables:** Use `load_env_files()` to get `SMTP_SERVER`, `SMTP_PORT`, `PGADMIN_DEFAULT_EMAIL`

**Example Pattern for Email Sending in Scripts:**

```bash
#!/bin/bash
source "$DIVTOOLS/scripts/util/logging.sh"
load_env_files

# For routine backups
python3 "$DIVTOOLS/scripts/smtp/send_email.py" \
    --to "$PGADMIN_DEFAULT_EMAIL" \
    --subject "Backup Success" \
    --body "Backup completed successfully" \
    --smtp-server "$SMTP_SERVER" \
    --smtp-port "${SMTP_PORT:-25}" \
    --from "root@$(hostname)"

# For failures only
python3 "$DIVTOOLS/scripts/smtp/send_email.py" \
    --to "$PGADMIN_DEFAULT_EMAIL" \
    --subject "Backup FAILED" \
    --body "Backup failed - check logs" \
    --smtp-server "$SMTP_SERVER" \
    --smtp-port "${SMTP_PORT:-25}" \
    --from "root@$(hostname)" \
    --high-priority  # ⚠️ ONLY for failures
```

### Configuration Management

When working on configurations (Telegraf, Prometheus, Unbound, etc.), **include**:

- `config/` folder and relevant subfolders
- Related scripts from `scripts/` that use these configs
- Relevant `.env.*` files if configs use environment variables

## ⚠️ CRITICAL: MCP Server Safety Rules

### Never Use "Replace All" / "Update All" Operations

**ABSOLUTE RULE:** When interacting with ANY MCP Server or external system:

**✅ ALWAYS Choose:**

- `update-flow` (update single flow)
- `update-node` (update single node)
- `update-item` (update one item)
- Operations that modify ONLY the specific item you're working on

**❌ NEVER Choose:**

- `update-flows` (replaces ALL flows)
- `update-all` (replaces entire configuration)
- `replace-all` operations
- Any operation that affects items NOT being explicitly worked on

### Why This Matters

Using "replace all" operations **DELETES ALL OTHER DATA** that's not explicitly included in the replacement set. Example:

```
BAD (DESTRUCTIVE):
update-flows([shop_light_motion.json, bug_zapper_plug.json])
Result: All other flows deleted permanently

GOOD (SAFE):
update-flow("shop_light_motion_tab", {...corrected node data...})
update-flow("bug_zapper_plug_tab", {...corrected node data...})
Result: Only specified flows updated, all others preserved
```

### Implementation Steps

**BEFORE using any "replace" or "update all" operation:**

1. ✅ Check if a single-item update option exists
2. ✅ If yes, use it instead of replace-all
3. ✅ If no single-item option exists, you MUST:
   - Retrieve ALL existing items first
   - Merge your changes into the complete set
   - Only then update with the complete merged data
   - Verify all existing items are preserved in the merge

**Example Safe Pattern:**

```javascript
// SAFE approach for Node-RED flows
const allFlows = mcp_nodered_get_flows();  // Get ALL existing flows
const updated_shop_light = { ...corrected_shop_light_flow };
const updated_bug_zapper = { ...corrected_bug_zapper_flow };

// Merge: keep all existing flows + update only our two
const mergedFlows = [
  ...allFlows.filter(f => f.id !== "shop_light_motion_tab" && f.id !== "bug_zapper_night_tab"),
  updated_shop_light,
  updated_bug_zapper
];

mcp_nodered_update_flows(mergedFlows);  // Now safe to use update-flows
```

### MCP Tools Checklist

For each MCP Server tool you use, verify:

- [ ] Tool is for a **single item** operation (preferred), OR
- [ ] Tool is for **merge/update** with explicit preservation of existing items, OR
- [ ] You have retrieved ALL existing items first and included them in the replacement

---

## Coding Conventions & Standards

### Code Documentation Requirements

**Every code block must include**:

1. **One-line comment** describing what the code does
2. **Date stamp** in this format: `# Last Updated: 11/4/2025 1:37:45 PM CDT`

Example:

```bash
#!/bin/bash
# Backs up Docker volumes to NFS storage
# Last Updated: 11/4/2025 2:30:00 PM CDT
```

### Script Flags - Required for New Scripts

All new scripts **must** include these flags:

- **`-test` or `--test`**: Runs the script in test mode
  - Permanent actions are stubbed with logging output instead of execution
  - Shows what *would* happen without making changes
- **`-debug` or `--debug`**: Enables debug mode
  - Adds `[DEBUG]` output lines showing variables and actions
  - Makes troubleshooting easier

#### Handling Existing Scripts

When user provides existing scripts **without** these flags:

- **Ask the user** if they want `-test` and `-debug` flags added
- Wait for confirmation before adding them
- Don't assume - let the user decide

### Logging Requirements

**Never use bare `echo` commands** for output. Instead:

- Use the logging function from `scripts/util/logging.sh`
- Source it at the beginning: `source "$(dirname "$0")/util/logging.sh"`

#### Logging Function Usage

```bash
log "LEVEL" "message"
log "LEVEL:TAG" "message"
log "LEVEL:!ts" "message"      # No timestamp
log "LEVEL:raw" "message"      # No timestamp, no tag
```

#### Required Log Level Colors

- **DEBUG**: White (`\033[37m`)
  - Suppressed unless `DEBUG_MODE=1`
- **INFO**: Blue/Cyan (`\033[36m`)
- **WARN**: Yellow (`\033[33m`)
- **ERROR**: Red (`\033[31m`)

Additional available colors in `logging.sh`:

- **HEAD/GREEN**: Green (`\033[32m`)
- **BLUE**: Blue (`\033[34m`)
- **RED**: Red (`\033[31m`)

### Script Template Example

```bash
#!/bin/bash
# [One-line description of what this script does]
# Last Updated: 11/4/2025 2:30:00 PM CDT

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/logging.sh"

# Default flags
TEST_MODE=0
DEBUG_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -test|--test)
            TEST_MODE=1
            log "INFO" "Running in TEST mode - no permanent changes will be made"
            shift
            ;;
        -debug|--debug)
            DEBUG_MODE=1
            log "DEBUG" "Debug mode enabled"
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "INFO" "Script execution started"
log "DEBUG" "TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

# Your code here...
```

## Environment Variable Patterns

- Site-level env files: `docker/sites/[site]/.env.[site]`
- Host-level env files: `docker/sites/[site]/[hostname]/.env.[hostname]`
- Shared env file: `docker/sites/s00-shared/.env.s00-shared`

## Common Task Patterns

- **Host setup**: Check `scripts/dt_host_setup.sh` and related `dt_*.sh` scripts
- **Docker deployments**: Look at `docker/docker-compose-*.yml` templates and site-specific overrides
- **Permission fixes**: Check `scripts/fix_dt_perms.sh` and ACL scripts
- **Monitoring**: Prometheus, Telegraf configs in `config/` folder
- **Backup operations**: PBS (Proxmox Backup Server) scripts in `scripts/pbs/`

## MCP Server Integration Strategy

### When to Create MCP Servers vs Bash Wrappers

**PRIORITY: Bash wrappers over direct MCP client usage in VS Code**

Reason: MCP tool integration via VS Code is complex and unreliable. Using bash scripts as an intermediary is more practical.

#### Use Bash Wrapper Scripts When

1. **Interfacing with REST APIs** (Home Assistant, Node-RED)
   - Create bash scripts in `scripts/` that call APIs directly
   - Return JSON that can be parsed and used by other tools
   - Example: `/home/divix/divtools/scripts/hass_api_wrapper.sh`

2. **Querying external systems** for data needed in other workflows
   - Device IDs, entity names, service lists from Home Assistant
   - Flow information from Node-RED
   - Use jq for JSON parsing and filtering

3. **Building automation workflows** that need data from multiple sources
   - Call bash wrappers from other scripts
   - Parse results and use in Node-RED flow creation, testing, etc.

#### Create MCP Servers When

1. **Complex tool orchestration** needed (not just data retrieval)
   - Multiple interdependent operations
   - Stateful interactions
   - Transaction-like behavior

2. **Testing MCP Server Functionality** in isolation
   - Use vitest framework for Node.js MCP servers
   - Organize tests in `<mcp-server>/test/` folder
   - Test one tool per test using descriptive test names

3. **Providing an abstraction layer** for multiple downstream clients
   - If multiple tools need the same set of operations
   - Can defer this until proven necessary

### Existing MCP Servers

**Node-RED MCP Server** (`/mcp-servers/nodered/`)

- Status: ✅ Implemented and tested (20 tests passing)
- Tools: create-flow, delete-flow, update-flow, get-flow, inject, etc.
- Test Suite: `/mcp-servers/nodered/test/*.test.js` (run with `npm test`)

**Home Assistant Integration**

- Status: ⚠️ No dedicated MCP server
- Solution: Use bash wrapper script instead
- Location: `/home/divix/divtools/scripts/hass/hass_api_wrapper.sh`
- Functions: `hass_get_entities`, `hass_get_devices`, `hass_entity_exists`, etc.
- Usage: Call from other bash scripts or Node.js code via child_process
- **IMPORTANT:** For ANY Home Assistant queries (entity lists, device info, state checks, etc.), you MUST use the `hass_api_wrapper.sh` script, NOT any MCP tools. The wrapper is more reliable and should be your default interface.

#### Home Assistant API Wrapper Usage

When a user asks for Home Assistant queries or data retrieval, **ALWAYS**:

1. **Use the bash wrapper** at `/home/divix/divtools/scripts/hass/hass_api_wrapper.sh`
2. **Do NOT write new scripts for each query** - use the wrapper's built-in commands with output formatting options
3. **Call wrapper commands with appropriate flags** to get data in needed formats (json, csv, text/markdown)
4. **Parse and process results** using jq, grep, and standard bash tools as needed to format output
5. **Never attempt** to use an MCP client to interact with Home Assistant tools

**Home Assistant API Wrapper Commands:**

The wrapper supports flexible output formats. Always use the most appropriate format for your needs:

**Basic Commands:**

- `./hass_api_wrapper.sh entities-by-type <type>` - List entity IDs of a type (e.g., light, switch)
  - Add `--area <area>` to filter by area (e.g., shop, office, bedroom)
  - Add `--format json|csv|text` for different output formats

- `./hass_api_wrapper.sh entity-details <type> [--area <area>] [--format json|csv|text]` - Get full details with state, brightness, color
  - Returns entity ID, friendly name, state, brightness, color_temp, rgb_color
  - **text format outputs markdown table** (perfect for reports)
  - **json format** outputs raw data for programmatic processing
  - **csv format** for spreadsheet import

- `./hass_api_wrapper.sh entity-state <entity_id>` - Get full state and attributes for one entity

- `./hass_api_wrapper.sh entities-by-type <type> --area <area> --format text` - Simple list of entity IDs in an area

**Output Format Examples:**

```bash
# Get markdown table of Shop lights (text format)
./hass_api_wrapper.sh entity-details light --area shop --format text

# Get JSON array of all lights for programmatic use
./hass_api_wrapper.sh entity-details light --format json

# Get CSV for spreadsheet analysis
./hass_api_wrapper.sh entity-details light --area office --format csv

# Just list light IDs in Shop area
./hass_api_wrapper.sh entities-by-type light --area shop
```

**When User Asks For:**

- "List all lights in Shop area with their state and brightness" → Use `entity-details light --area shop --format text`
- "Get JSON data for all switches" → Use `entity-details switch --format json`
- "Export lights to spreadsheet" → Use `entity-details light --format csv`

**Environment Setup:**

- Script automatically loads `HASS_API_TOKEN` from `docker/sites/$SITE_NAME/.env.$SITE_NAME`
- `HASS_URL` defaults to `http://10.1.1.215:8123` but can be overridden
- Ensure `SITE_NAME` environment variable is set before running (normally set by `load_env_files()`)

**API Documentation Reference:**
When writing or modifying Home Assistant API code, refer to these official documentation sources:

- **Endpoints**: <https://developers.home-assistant.io/docs/api/supervisor/endpoints/>
- **Models**: <https://developers.home-assistant.io/docs/api/supervisor/models>
- **Examples**: <https://developers.home-assistant.io/docs/api/supervisor/examples>
- **WebSocket API**: <https://developers.home-assistant.io/docs/api/websocket>

### Recommended Workflow for External System Integration

1. **Write bash wrapper** for REST API (e.g., Home Assistant, custom services)
   - Use curl for HTTP requests
   - Parse JSON with jq
   - Provide simple function interface
   - Document each function in script comments

2. **Test bash wrapper** manually or with shell script tests
   - Verify API calls work
   - Check JSON parsing
   - Document expected outputs

3. **Use wrapper from Node-RED creation/testing code**
   - Spawn child process or call directly in bash
   - Parse results for flow creation
   - Integrate with MCP server tests if needed

4. **Only create MCP server** if:
   - Multiple clients need access
   - Tool integration becomes too complex for bash
   - Performance requires in-process access

## File Naming Conventions

- Scripts: lowercase with underscores (e.g., `dt_host_setup.sh`)
- Docker compose: `docker-compose-[service].yml`
- Env files: `.env.[hostname]` or `.env.[site]`
- Config files: service-specific naming in respective `config/` subfolders

## Lessons Learned & Common Mistakes to Avoid

### Email Priority Headers

**MISTAKE:** Setting high priority (X-Priority: 1, X-MSMail-Priority: High) for ALL emails
- **WRONG:** Sends alerts for routine operations (backups, status checks, etc.)
- **IMPACT:** User inbox gets flooded with false alarms, making real failures invisible
- **FIX:** Only set high priority headers for actual failures/errors. Use normal headers for:
  - Successful operations
  - Status reports (even if unusual, like "no changes needed")
  - Informational messages

### Docker Container vs Host Assumptions

**MISTAKE:** Assuming you can SSH or directly connect to services running in Docker containers
- **WRONG:** Services like PostgreSQL run in Docker, not on the host system
- **IMPACT:** Backup scripts fail with connection errors, SSH can't reach the service
- **FIX:** 
  - Identify services running in Docker containers
  - Use bind-mounts to access data (e.g., `/opt/postgres/pgdata` on host)
  - Use special flags (`--no-online --force` for pgBackRest) for offline backups
  - Document container-specific requirements in the instructions

### SMTP Server Selection & Port Choice

**MISTAKE:** Using port 587 (submission port) for internal relay instead of port 25
- **WRONG:** Port 587 has strict validation and rejects external recipients without auth
- **IMPACT:** "Recipient address rejected: Access denied" errors, even when relay is configured
- **FIX:**
  - Use **port 25** for internal relay (less strict validation)
  - Use **port 587** only when SMTP authentication credentials are available
  - Document the difference and when to use each

### Hardcoded Paths vs $DIVTOOLS

**MISTAKE:** Using hardcoded absolute paths like `/home/divix/divtools/scripts/...`
- **WRONG:** Paths differ on different systems; breaks portability
- **IMPACT:** Scripts fail when divtools is installed in a different location
- **FIX:** Always use `$DIVTOOLS/scripts/...` or relative paths like `$(dirname "$0")/...`
- Verify `$DIVTOOLS` is set before using it (typically via `load_env_files()`)

### Exit Code Handling

**MISTAKE:** Treating all non-zero exit codes as failures
- **WRONG:** pgBackRest exit code 55 ("no files changed") is not an error, it's normal
- **IMPACT:** False negative alerts, user can't distinguish real failures from healthy conditions
- **FIX:** Check specific exit codes and treat expected non-error conditions appropriately
  - Document what each exit code means
  - Create distinct status messages (SUCCESS, SUCCESS - NO CHANGES, FAILED)
  - Only send high-priority alerts for actual failures

## Additional Notes

- This is a Linux-focused workspace (bash shell)
- Many scripts interface with Proxmox VE, Docker, QNAP NAS systems
- Security: Credentials stored in `.env.*` files (not committed to repo)
- Syncthing may create sync-conflict files - these can usually be ignored
