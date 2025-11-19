# Virtual Environment Setup for dthostmon

## Overview
The `dthostmon` project uses a centralized virtual environment management system located in `$DIVTOOLS/scripts/venvs/`. This makes venvs easily portable across all synced divtools hosts and provides convenient shell functions/aliases for management.

## Quick Start

### Check if python3-venv is installed
```bash
python3 -m venv --help
```

If the command fails, you need to install python3-venv:
```bash
sudo apt install python3-venv
# or for Python 3.12 specifically:
sudo apt install python3.12-venv
```

### Create the dthostmon venv

**Option 1: Using the setup script (recommended)**
```bash
cd /home/divix/divtools/projects/dthostmon
./scripts/setup_venv.sh
```

**Option 2: Using the shell function**
```bash
# Create the venv
python_venv_create dthostmon
# OR
pvcr dthostmon

# Activate it
python_venv_activate dthostmon
# OR
pvact dthostmon

# Install requirements
pip install -r $DIVTOOLS/projects/dthostmon/requirements.txt
pip install -r $DIVTOOLS/projects/dthostmon/requirements-dev.txt
```

## Available Shell Functions

These functions are defined in `$DIVTOOLS/dotfiles/.bash_profile`:

| Function | Alias | Description |
|----------|-------|-------------|
| `python_venv_create <name>` | `pvcr <name>` | Create a new venv in `$DIVTOOLS/scripts/venvs/<name>` |
| `python_venv_delete <name>` | `pvdel <name>` | Delete an existing venv (with confirmation) |
| `python_venv_activate <name>` | `pvact <name>` | Activate a venv |
| `python_venv_ls` | `pvls` | List all available venvs |

## Usage Examples

```bash
# List all venvs
pvls

# Activate dthostmon venv
pvact dthostmon

# Run tests with pytest
pytest

# Deactivate when done
deactivate
```

## Integration with Scripts

The `dthostmon_sync_config.sh` script automatically attempts to activate the `dthostmon` venv if it exists:

```bash
# It looks for: $DIVTOOLS/scripts/venvs/dthostmon/bin/activate
# If not found, it provides helpful instructions for creating it
```

## Benefits of Centralized Venvs

1. **Portability**: Venvs are in the synced divtools directory, available on all hosts
2. **Consistency**: All projects follow the same pattern
3. **Easy Management**: Simple shell functions for common operations
4. **Discovery**: `pvls` shows all available venvs across all projects
5. **No Clutter**: Project directories stay clean (no local `venv/` folders)

## Troubleshooting

### "python3-venv not installed" error
Install it with:
```bash
sudo apt install python3-venv
```

### Venv activation fails
Check if the venv exists:
```bash
pvls
```

If missing, create it:
```bash
pvcr dthostmon
pvact dthostmon
pip install -r $DIVTOOLS/projects/dthostmon/requirements.txt
pip install -r $DIVTOOLS/projects/dthostmon/requirements-dev.txt
```

### Want to recreate a broken venv
```bash
pvdel dthostmon  # Confirm deletion
pvcr dthostmon   # Recreate
pvact dthostmon  # Activate
pip install -r $DIVTOOLS/projects/dthostmon/requirements.txt
pip install -r $DIVTOOLS/projects/dthostmon/requirements-dev.txt
```

## Running Tests

Once the venv is set up and activated:

```bash
# Activate the venv
pvact dthostmon

# Run all tests
pytest

# Run specific test file
pytest tests/test_sync_config.py

# Run with verbose output
pytest -v

# Run with coverage
pytest --cov=src --cov-report=html
```

## Notes

- The venv name should match the project name for consistency
- Always activate the venv before running tests or installing packages
- The sync script will warn if the venv is missing and provide setup instructions
- Venvs are synced via Syncthing, so creating it once makes it available on all hosts
