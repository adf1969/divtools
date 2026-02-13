# Divtools Workspace Instructions

## Summary MD Files
- NEVER create SUMMARY.MD files UNLESS I REQUEST THEM.
- If you get to a point where you think they are useful, ASK ME FIRST, and I will answer "Yes" if I want them.
- If you do create them, always put them in a sub-folder of the folder you are working in, named docs/.

## Test Scripts
- If you write a Test script to test a main script, those scripts should go in a sub-folder under the main script called .'test'.
- Example, if working on a script in the scripts/frigate/ folder, the test script should go in the scripts/frigate/test folder.

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
When writing scripts, be aware that you CANNOT use the "local" keyword OUTSIDE of a function. It MUST be in a function to be used.

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

### Configuration Management
When working on configurations (Telegraf, Prometheus, Unbound, etc.), **include**:
- `config/` folder and relevant subfolders
- Related scripts from `scripts/` that use these configs
- Relevant `.env.*` files if configs use environment variables

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

## File Naming Conventions
- Scripts: lowercase with underscores (e.g., `dt_host_setup.sh`)
- Docker compose: `docker-compose-[service].yml`
- Env files: `.env.[hostname]` or `.env.[site]`
- Config files: service-specific naming in respective `config/` subfolders

## Additional Notes
- This is a Linux-focused workspace (bash shell)
- Many scripts interface with Proxmox VE, Docker, QNAP NAS systems
- Security: Credentials stored in `.env.*` files (not committed to repo)
- Syncthing may create sync-conflict files - these can usually be ignored
