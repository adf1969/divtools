# dtpyutil - Divtools Python Utilities

A centralized Python utilities library for all divtools Python-based scripts and projects.

## What is dtpyutil?

**dtpyutil** provides:

- **Single Shared Venv**: One Python environment for ALL divtools Python code
- **Importable Libraries**: Reusable components (TUI menus, logging, CLI helpers)
- **Reduced Overhead**: Install dependencies once, use everywhere
- **Consistent Environment**: Same library versions across all tools

## Quick Start

### Installation

```bash
cd $DIVTOOLS/projects/dtpyutil
bash scripts/install_dtpyutil_deps.sh
```

This creates the shared venv at `$DIVTOOLS/scripts/venvs/dtpyutil/` with Textual, pytest, and other common dependencies.

### Using the Menu System (from Bash)

```bash
#!/bin/bash
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# Show menu (uses file-based IPC for return values)
pmenu_menu "Main Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit"
```

### Using the Menu System (from Python)

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

# Add dtpyutil to path
sys.path.insert(0, str(Path(__file__).parent.parent / "dtpyutil"))

from src.menu.dtpmenu import DtpMenuApp

# Use the menu
app = DtpMenuApp(...)
app.run()
```

### Using the Shared Venv in Your Project

```bash
#!/bin/bash
# Use dtpyutil venv for Python execution
PYTHON_CMD="$DIVTOOLS/scripts/venvs/dtpyutil/bin/python"

# Run your script
"$PYTHON_CMD" "$DIVTOOLS/projects/myproject/my_script.py"
```

## What's Included

### Libraries

- **Menu System** (`src/menu/`) - Textual-based TUI menus, dialogs, input boxes
- **Logging** (`src/logging/`) - Python logging utilities (coming soon)
- **CLI Helpers** (`src/cli/`) - Common argparse patterns (coming soon)
- **Common Utilities** (`src/common/`) - Shared helper functions (coming soon)

### Examples

- **menu_demo.sh** (`examples/`) - Interactive bash demo of all menu modes

### Documentation

- **PROJECT-DETAILS.md** - Current project structure and architecture
- **PROJECT-HISTORY.md** - Development history and lessons learned
- **BASH-INTEGRATION.md** - Critical guide for calling Textual TUIs from bash

## Why dtpyutil Exists

### The Problem

During development of dtpmenu (Python TUI menu system), we discovered:

1. **Command Substitution Breaks Textual**: `choice=$(python menu.py ...)` pipes stdout to a buffer, breaking Textual's terminal detection and centering
2. **Multiple Venvs = Pain**: Each Python tool had its own venv, requiring separate installations
3. **Code Duplication**: Menu logic, logging, helpers duplicated across projects

### The Solution

**dtpyutil** provides:

- **File-Based IPC**: Menu results written to files (no command substitution needed)
- **Single Shared Venv**: Install once, use everywhere
- **Importable Libraries**: Share code across projects without duplication

See [PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md) for full development story.

## Project Structure

```
dtpyutil/
├── README.md              # This file
├── src/                   # Shared library code
│   ├── menu/              # TUI menu system
│   ├── logging/           # Logging utilities
│   ├── cli/               # CLI helpers
│   └── common/            # Misc utilities
├── scripts/               # Utility scripts
│   └── install_dtpyutil_deps.sh
├── test/                  # Test suite
├── docs/                  # Documentation
│   ├── PROJECT-DETAILS.md
│   ├── PROJECT-HISTORY.md
│   └── BASH-INTEGRATION.md
└── examples/              # Example usage
    └── menu_demo.sh
```

## Using in Other Projects

### Example: ADS Project

```bash
# File: projects/ads/run_ads.sh
PYTHON_CMD="$DIVTOOLS/scripts/venvs/dtpyutil/bin/python"
"$PYTHON_CMD" "$DIVTOOLS/projects/ads/native/ads_menu.py"
```

```python
# File: projects/ads/native/ads_menu.py
import sys
from pathlib import Path

# Add dtpyutil to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "dtpyutil"))

from src.menu.dtpmenu import show_menu
from src.logging.logger import setup_logger

# Use the libraries
logger = setup_logger("ads")
result = show_menu("ADS Menu", ["Option 1", "Option 2"])
```

## Documentation

- **[PROJECT-DETAILS.md](docs/PROJECT-DETAILS.md)** - Full architecture, design decisions, usage guidelines
- **[PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md)** - Development history, critical lessons learned. Review comments/Outstanding items here to direct future dev.
- **[BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md)** - How to call Textual TUIs from bash (CRITICAL READ)

## Testing

```bash
cd $DIVTOOLS/projects/dtpyutil
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/
```

## Contributing

When adding shared utilities:

1. Add code to `src/newlib/`
2. Add tests to `test/test_newlib.py`
3. Document API in `docs/API-NEWLIB.md`
4. Update this README with new library

See [PROJECT-DETAILS.md](docs/PROJECT-DETAILS.md) for contribution guidelines.

## Critical Warning: Command Substitution

⚠️ **NEVER use command substitution with Textual TUI applications!**

```bash
# ❌ BROKEN - Breaks centering
choice=$(pmenu_menu "Title" "opt1" "Option 1")

# ✅ WORKS - File-based IPC
pmenu_menu --output-file /tmp/result.txt "Title" "opt1" "Option 1"
choice=$(cat /tmp/result.txt)
```

See [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) for full explanation.

## License

Part of divtools - internal use only.

## History

**Created**: January 14, 2026  
**Origin**: Migration from dtpmenu project  
**Reason**: Architectural issues with bash + Python TUI integration

See [PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md) for complete history.
