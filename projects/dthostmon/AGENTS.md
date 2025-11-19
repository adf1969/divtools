# AGENTS.md - Agentic Coding Guidelines for divtools

## Build/Lint/Test Commands

This is a bash/shell scripting project with Python utilities. No standard build system used.

### Testing
- **Run script tests**: Use `-test` flag on individual scripts (e.g., `./script.sh -test`)
- **Debug mode**: Use `-debug` flag for verbose output (e.g., `./script.sh -debug`)
- **Combined**: `./script.sh -test -debug` for dry-run with debug output
- **Python tests**: Run Python scripts directly (e.g., `python3 script.py`)

### Linting
- **Shell scripts**: Use `shellcheck` if available: `shellcheck script.sh`
- **Python**: Use `flake8` or `pylint` if available: `flake8 script.py`

## Code Style Guidelines

### General
- **Documentation**: Every code block must include one-line comment and date stamp: `# Last Updated: MM/DD/YYYY H:MM:SS AM/PM CDT`
- **Logging**: Never use bare `echo`; use `log()` function from `scripts/util/logging.sh`
- **Test flags**: All new scripts must support `-test` and `-debug` flags

### Shell Scripts
- **Naming**: lowercase with underscores (e.g., `dt_host_setup.sh`)
- **Local variables**: Use `local` keyword only inside functions
- **Error handling**: Check command success with `||` or `if` statements
- **PSQL commands**: Never include `!` at end of psql commands (breaks bash prompt)

### Python Scripts
- **Imports**: Standard library first, then third-party, then local
- **Type hints**: Use typing module for function parameters and return types
- **Error handling**: Use try/except blocks with specific exceptions
- **Docstrings**: Use triple quotes for module and function documentation

### Docker
- **Labels**: Include `divtools.group` labels in docker-compose files
- **Compose files**: `docker-compose-[service].yml` for templates, site-specific overrides in `sites/`

### File Naming
- Scripts: `lowercase_with_underscores.sh`
- Docker compose: `docker-compose-[service].yml`
- Env files: `.env.[hostname]` or `.env.[site]`
- Config files: service-specific naming in respective `config/` subfolders

## Monitoring and Reporting Applications

### Cron Job System Monitor
Create apps that run from cron jobs to review system status and changes, then report via email.

#### Core Components
- **System Status Checks**: Monitor disk usage, memory, CPU, service status, log files
- **Change Detection**: Compare current state vs. previous snapshots (use file timestamps, checksums)
- **Email Reporting**: Use `mail` command or SMTP libraries for notifications
- **Cron Integration**: Ensure scripts handle environment variables, paths, and run non-interactively

#### Implementation Patterns
- **State Persistence**: Store previous states in `/var/log/divtools/` or `/opt/divtools/state/`
- **Threshold Alerts**: Define warning/critical thresholds for system metrics
- **Report Formatting**: Use HTML email format for better readability
- **Error Handling**: Continue monitoring even if individual checks fail

#### Email Configuration
- **SMTP Settings**: Configure via environment variables (SMTP_SERVER, SMTP_PORT, etc.)
- **Recipient Lists**: Support multiple email addresses for different alert types
- **Subject Lines**: Include severity indicators ([WARN], [CRITICAL], [INFO])

#### Example Cron Entry
```bash
# Daily system health check at 6 AM
0 6 * * * /opt/divtools/scripts/system_monitor.sh --email-reports
```

## Copilot Instructions
See `.github/copilot-instructions.md` for detailed workspace conventions including:
- Context-aware file inclusion rules
- Script template with required flags
- Logging requirements with color coding
- Environment variable patterns
- File naming conventions</content>
<parameter name="filePath">/opt/divtools/projects/dthostmon/AGENTS.md