# dtpyutil - Divtools Python Utilities Project

## Project Overview

**dtpyutil** is a centralized Python utilities project that provides shared libraries, tools, and components for all divtools Python-based scripts and projects. It uses a single shared virtual environment to reduce installation overhead and simplify dependency management across the entire divtools ecosystem.

## Purpose & Scope

### Primary Goals

1. **Unified Python Environment**: Single venv (`dtpyutil`) for all divtools Python utilities
2. **Shared Libraries**: Common code (TUI menus, logging, etc.) accessible by all projects
3. **Reduced Installation Friction**: One-time venv setup instead of per-project environments
4. **Consistent Dependencies**: Shared versions of Textual, requests, etc. across all tools

### What Lives Here

- **TUI Menu System** (formerly dtpmenu) - Textual-based menu/dialog library
- **Common Utilities** - Logging, configuration, CLI helpers
- **Shared Libraries** - Code that multiple projects need (API wrappers, data parsers, etc.)
- **Test Frameworks** - Testing utilities and fixtures for Python scripts
- **Documentation** - Standards, best practices, API docs for shared components

### What Lives Elsewhere

- **Application-Specific Code**: Projects like `ads`, `hass`, `dthostmon` remain in their own folders
- **Application Documentation**: Project-specific PRDs, histories, and dev notes stay with the project
- **Application Tests**: Project-specific test suites remain in project test folders

## Architecture & Design Decisions

### Multi-Project Structure with Shared Venv

**Challenge**: How to maintain separate project development contexts while sharing a common Python environment and libraries?

**Solution**: Hybrid approach with clear separation of concerns:

```
projects/
├── dtpyutil/              # Shared utilities project (this project)
│   ├── venv/              # Shared Python environment (via scripts/venvs/dtpyutil)
│   ├── src/               # Shared library code
│   │   ├── menu/          # TUI menu system (formerly dtpmenu)
│   │   ├── logging/       # Logging utilities
│   │   ├── cli/           # CLI argument parsing helpers
│   │   └── common/        # Miscellaneous shared code
│   ├── test/              # Tests for shared libraries
│   ├── docs/              # Documentation for shared libraries
│   │   ├── PROJECT-DETAILS.md     # Current project status (this file)
│   │   └── PROJECT-HISTORY.md     # Development history and iterations
│   └── scripts/           # Utility scripts that use shared libs
│       └── install_dtpyutil_deps.sh
│
├── ads/                   # ADS application project (example)
│   ├── native/            # Python implementation using dtpyutil
│   ├── docs/              # ADS-specific PRDs, history
│   ├── test/              # ADS-specific tests
│   └── # Uses dtpyutil venv and imports from dtpyutil.src.menu
│
├── hass/                  # Home Assistant utilities project
│   └── # Uses dtpyutil venv, may import shared libs
│
└── dthostmon/             # Host monitoring project
    └── # Uses dtpyutil venv, may import shared libs
```

### Key Design Principles

#### 1. **Single Shared Venv**

- Location: `$DIVTOOLS/scripts/venvs/dtpyutil/`
- Managed by: `projects/dtpyutil/scripts/install_dtpyutil_deps.sh`
- Used by: ALL Python projects in divtools
- Benefits:
  - One-time installation of common dependencies (Textual, requests, etc.)
  - Consistent library versions across all projects
  - Reduced disk space (no duplicate venvs)
  - Simpler onboarding (one venv to activate/configure)

#### 2. **Importable Library Structure**

- Shared code in `projects/dtpyutil/src/` is importable by other projects
- Python path setup allows: `from dtpyutil.src.menu import pmenu_menu`
- Each project can add `projects/dtpyutil` to PYTHONPATH or use relative imports
- Standalone utilities in `projects/dtpyutil/scripts/` can be called directly

#### 3. **Separate Project Development Contexts**

- Each project (`ads`, `hass`, etc.) maintains its own:
  - `docs/` folder with PRD, PROJECT-HISTORY.md, PROJECT-DETAILS.md
  - `test/` folder with project-specific test suites
  - Development chat history and iteration notes
- Projects import from dtpyutil but don't modify dtpyutil code directly
- Clear separation enables independent chat contexts for each project

#### 4. **Documentation Separation**

- **dtpyutil/docs/**: API docs for shared libraries, usage guides
- **project/docs/**: PRDs, requirements, project-specific design decisions
- **dtpyutil/docs/PROJECT-HISTORY.md**: History of dtpyutil development (dtpmenu migration, library additions, etc.)
- **project/docs/PROJECT-HISTORY.md**: History of that project's development

## Folder Structure Details

### Recommended Directory Layout

```
projects/dtpyutil/
├── README.md                     # Quick start guide, what is dtpyutil
├── src/                          # Shared library source code
│   ├── __init__.py               # Makes src importable
│   ├── menu/                     # TUI menu system
│   │   ├── __init__.py
│   │   ├── dtpmenu.py            # Main Textual TUI app (migrated from dtpmenu/)
│   │   ├── bash_wrapper.sh       # Bash interface (dt_pmenu_lib.sh)
│   │   └── README.md             # Menu system API docs
│   ├── logging/                  # Logging utilities
│   │   ├── __init__.py
│   │   └── logger.py             # Python logging wrapper
│   ├── cli/                      # CLI helpers
│   │   ├── __init__.py
│   │   └── argparse_helpers.py   # Common argument patterns
│   └── common/                   # Miscellaneous shared utilities
│       ├── __init__.py
│       └── env_loader.py         # Environment variable loading
│
├── scripts/                      # Standalone utility scripts
│   ├── install_dtpyutil_deps.sh  # Venv setup (migrated from dtpmenu)
│   └── # Other standalone tools that use dtpyutil libraries
│
├── test/                         # Test suite for shared libraries
│   ├── test_menu.py              # Menu system tests
│   ├── test_logging.py           # Logging tests
│   └── fixtures/                 # Test fixtures and helpers
│
├── docs/                         # Documentation
│   ├── PROJECT-DETAILS.md        # Current project status (this file)
│   ├── PROJECT-HISTORY.md        # Development history
│   ├── API-MENU.md               # Menu system API reference
│   ├── BASH-INTEGRATION.md       # How to call from bash (migrated from dtpmenu)
│   └── PYTHON-INTEGRATION.md     # How to import in Python projects
│
└── examples/                     # Example usage
    ├── menu_demo.sh              # Bash demo (migrated from dtpmenu/demo_menu.sh)
    └── python_menu_demo.py       # Python demo
```

### Migration from dtpmenu

The following items will be migrated from `projects/dtpmenu/` to `projects/dtpyutil/`:

| From dtpmenu/ | To dtpyutil/ | Notes |
|---------------|--------------|-------|
| `dtpmenu.py` | `src/menu/dtpmenu.py` | Main TUI app |
| `install_dtpmenu_deps.sh` | `scripts/install_dtpyutil_deps.sh` | Renamed, manages dtpyutil venv |
| `docs/BASH-INTEGRATION.md` | `docs/BASH-INTEGRATION.md` | Copied, critical lessons learned |
| `demo_menu.sh` | `examples/menu_demo.sh` | Moved to examples |
| Relevant history | `docs/PROJECT-HISTORY.md` | Condensed summary of dtpmenu lessons |

**Note**: The original `projects/dtpmenu/` folder will be preserved for historical reference but deprecated in favor of dtpyutil.

## Using dtpyutil in Other Projects

### From Python Projects

#### Import Shared Libraries

```python
#!/usr/bin/env python3
# File: projects/ads/native/ads_menu.py

import sys
from pathlib import Path

# Add dtpyutil to Python path
dtpyutil_path = Path(__file__).parent.parent.parent / "dtpyutil" / "src"
sys.path.insert(0, str(dtpyutil_path))

# Now import from dtpyutil
from menu.dtpmenu import show_menu
from logging.logger import setup_logger

# Use the libraries
logger = setup_logger("ads")
result = show_menu("ADS Menu", ["Option 1", "Option 2"])
logger.info(f"User selected: {result}")
```

#### Use the Shared Venv

```bash
#!/bin/bash
# File: projects/ads/run_ads.sh

# Use dtpyutil venv for Python execution
PYTHON_CMD="$DIVTOOLS/scripts/venvs/dtpyutil/bin/python"

# Run the ADS script using shared venv
"$PYTHON_CMD" "$DIVTOOLS/projects/ads/native/ads_menu.py"
```

### From Bash Scripts

#### Call Menu System Directly

```bash
#!/bin/bash
# Source the dtpyutil menu wrapper
source "$DIVTOOLS/projects/dtpyutil/src/menu/bash_wrapper.sh"

# Use menu functions
pmenu_menu "Main Menu" \
    "opt1" "Option 1" \
    "opt2" "Option 2" \
    "exit" "Exit"
```

## Venv Management

### Location

- Venv stored in: `$DIVTOOLS/scripts/venvs/dtpyutil/`
- Symlink from: `projects/dtpyutil/venv/` → `../../scripts/venvs/dtpyutil/`

### Installation

```bash
cd $DIVTOOLS/projects/dtpyutil
bash scripts/install_dtpyutil_deps.sh
```

### Verification

```bash
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python --version
$DIVTOOLS/scripts/venvs/dtpyutil/bin/pip list
```

### Adding Dependencies

Edit `scripts/install_dtpyutil_deps.sh` and add to the `install_packages()` function:

```bash
install_packages() {
    log "INFO" "Installing Python packages..."
    "$PIP_CMD" install --upgrade pip
    "$PIP_CMD" install textual  # TUI framework
    "$PIP_CMD" install requests # HTTP library
    # Add new dependencies here
}
```

## Project-Specific vs Shared Code Guidelines

### When to Add Code to dtpyutil

Add code to `projects/dtpyutil/src/` when:

- ✅ **Multiple projects** need the same functionality
- ✅ Code is **general-purpose** and reusable (logging, menus, parsers)
- ✅ Functionality is **stable** and not rapidly changing
- ✅ Code has **minimal external dependencies** or shared dependencies

### When to Keep Code in Project Folder

Keep code in `projects/ads/`, `projects/hass/`, etc. when:

- ✅ **Project-specific** business logic or domain knowledge
- ✅ **Rapidly evolving** code during active development
- ✅ **Experimental** features being tested
- ✅ **Tightly coupled** to project-specific data structures

### Migration Path

When project-specific code becomes reusable:

1. Copy code from `projects/myproject/` to `projects/dtpyutil/src/newlib/`
2. Generalize the code (remove project-specific assumptions)
3. Add tests to `projects/dtpyutil/test/test_newlib.py`
4. Document API in `projects/dtpyutil/docs/API-NEWLIB.md`
5. Update project to import from dtpyutil instead of using local copy

## Documentation Standards

### Per-Project Documentation

Each project in `projects/*/` should have:

- `README.md` - Quick overview, what the project does, how to run it
- `docs/PRD.md` - Product Requirements Document (if applicable)
- `docs/PROJECT-DETAILS.md` - Current project status, architecture, design decisions
- `docs/PROJECT-HISTORY.md` - Development history, iterations, lessons learned

### dtpyutil Documentation

The `projects/dtpyutil/docs/` folder contains:

- **PROJECT-DETAILS.md** (this file) - Current project structure and status
- **PROJECT-HISTORY.md** - Development history, including dtpmenu migration
- **BASH-INTEGRATION.md** - Critical lessons about calling Textual from bash
- **API-*.md** - API reference for each shared library

## Testing Strategy

### Shared Library Tests

Tests for dtpyutil libraries live in `projects/dtpyutil/test/`:

```bash
projects/dtpyutil/test/
├── test_menu.py           # Tests for menu system
├── test_logging.py        # Tests for logging utilities
└── fixtures/              # Shared test fixtures
    └── sample_menus.json
```

Run with:

```bash
cd $DIVTOOLS/projects/dtpyutil
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/
```

### Project-Specific Tests

Tests for projects using dtpyutil stay with the project:

```bash
projects/ads/test/
├── test_ads_menu.py       # Tests ADS-specific menu logic
└── test_ads_core.py       # Tests ADS business logic
```

Run with:

```bash
cd $DIVTOOLS/projects/ads
$DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/
```

## Development Workflow

### Working on Shared Libraries

1. **Make changes** to code in `projects/dtpyutil/src/`
2. **Add/update tests** in `projects/dtpyutil/test/`
3. **Run tests** to verify changes:

   ```bash
   cd $DIVTOOLS/projects/dtpyutil
   $DIVTOOLS/scripts/venvs/dtpyutil/bin/python -m pytest test/
   ```

4. **Update documentation** in `projects/dtpyutil/docs/`
5. **Test integration** with dependent projects (ads, hass, etc.)

### Working on Project Using dtpyutil

1. **Develop project code** in `projects/myproject/`
2. **Import from dtpyutil** as needed:

   ```python
   from dtpyutil.src.menu import pmenu_menu
   ```

3. **Use dtpyutil venv** for execution:

   ```bash
   $DIVTOOLS/scripts/venvs/dtpyutil/bin/python myproject.py
   ```

4. **Keep project docs** in `projects/myproject/docs/`

### Chat Context Separation

For focused development, use separate chat sessions:

- **dtpyutil chat**: "Working on dtpyutil menu system improvements"
  - Context: `projects/dtpyutil/` folder
  - History: `docs/PROJECT-HISTORY.md`
  
- **ads chat**: "Working on ADS application development"
  - Context: `projects/ads/` folder
  - History: `projects/ads/docs/PROJECT-HISTORY.md`
  - Dependencies: Imports from dtpyutil, uses dtpyutil venv

This keeps chat histories focused and prevents context overload.

## Critical Lessons Learned (from dtpmenu)

### ⚠️ NEVER Use Command Substitution with Textual TUI

**Problem**: `choice=$(python dtpmenu.py ...)` pipes stdout to a buffer, breaking Textual's terminal detection and centering.

**Solution**: Use `--output-file` flag to write results to a file, then read the file after TUI exits.

See `docs/BASH-INTEGRATION.md` for full details. This was the PRIMARY lesson from the dtpmenu project that led to this architectural shift.

### Why This Architecture Exists

The decision to create dtpyutil came from discovering that:

1. **Bash + Python TUI = Broken** when using command substitution
2. **Multiple venvs = Installation Hell** for users
3. **Shared code = Better** than duplicating menu logic in every project

This architecture solves all three problems.

## ❓ OUTSTANDING - Qn1: Cross-Project Import Mechanism

**Question:** What is the preferred method for projects to import dtpyutil libraries?

- **Option A**: Modify PYTHONPATH in each project's launcher script

  ```bash
  export PYTHONPATH="$DIVTOOLS/projects/dtpyutil:$PYTHONPATH"
  python myproject.py
  ```
  
- **Option B**: Use relative imports within Python code

  ```python
  sys.path.insert(0, str(Path(__file__).parent.parent / "dtpyutil"))
  from src.menu import pmenu_menu
  ```
  
- **Option C**: Install dtpyutil as editable package in venv

  ```bash
  cd $DIVTOOLS/scripts/venvs/dtpyutil
  ./bin/pip install -e $DIVTOOLS/projects/dtpyutil
  # Then in any project: from dtpyutil.menu import pmenu_menu
  ```

**Context/Impact:** This affects how maintainable and portable the import mechanism is. Option C is most "Pythonic" but adds complexity. Option A is simplest but requires env var management. Option B is explicit but verbose.

**Recommendation:** Option C (editable install) for cleanliness and standard Python packaging practices.

### Answer

**Decision:**
I would choose Option C.
I assume I can still edit the dtpyutil files?
If I do, what is the mechinism for "updating" the packages in the dtpyutil VENV?

---

## ❓ OUTSTANDING - Qn2: Menu System File-Based Return Value Implementation

**Question:** How should dtpmenu.py implement the `--output-file` flag to fix the command substitution centering issue?

- **Option A**: Add `--output-file` CLI argument, write selection to file on exit

  ```python
  if args.output_file:
      with open(args.output_file, 'w') as f:
          f.write(self.selected_value)
  ```
  
- **Option B**: Use environment variable `PMENU_OUTPUT_FILE` for file path

  ```python
  output_file = os.getenv('PMENU_OUTPUT_FILE')
  if output_file:
      with open(output_file, 'w') as f:
          f.write(self.selected_value)
  ```
  
- **Option C**: Both - check env var first, CLI arg overrides

  ```python
  output_file = args.output_file or os.getenv('PMENU_OUTPUT_FILE')
  if output_file:
      with open(output_file, 'w') as f:
          f.write(self.selected_value)
  ```

**Context/Impact:** This is the critical fix needed to make bash integration work properly. Must be implemented in dtpmenu.py before migration to dtpyutil.

**Recommendation:** Option C (both CLI arg and env var) for maximum flexibility.

### Answer

**Decision:**
I choose Option C.
In most cases, the dtpmenu will use NO special output, since it will be called from a Python file, and will work flawlessly, but if it is ever called from BASH it should check both CLI and the ENV Var to determine if it needs to save to a file for later retrieval by the calling Bash Script.

---

## ❓ OUTSTANDING - Qn3: dtpmenu Folder Fate

**Question:** What should happen to `projects/dtpmenu/` after migration to dtpyutil?

- **Option A**: Delete entirely once migration is verified
  
- **Option B**: Rename to `projects/dtpmenu-deprecated/` and keep for historical reference
  
- **Option C**: Keep as-is but add README stating it's deprecated in favor of dtpyutil

**Context/Impact:** The folder contains significant development history and lessons learned. Deleting loses that context, but keeping it may cause confusion about which project to use.

**Recommendation:** Option B (rename to deprecated) to preserve history while making deprecation clear.

### Answer

**Decision:**
I choose Option B.
Nothing is using it, so it is not a problem to rename it.
It also makes it VERY CLEAR that it is not to be used.
It is there for history only.
It should also have the README updated to indicate it is deprectated and why just incase any of those files get opened externally or individually.
At some point, I may move the entire folder to an ARCHIVE folder.

---
**FINAL COMMENTS:** 1/14/2026 12:35:39 PM
I agree with the Recommended folder structure above.
It preserves the location of the venv files ALWAYS being in ./scripts/venvs/ which is where I want them to ALWAYS be for DIVTOOLS.
It also puts src in an easy place to find.
It makes it easy to add new projects (like ads) and have them easily use the dtpyutil venv gaining access to the entire dtpyutil functionality.

---

## Current Status

- **Project Created**: Yes (empty folder structure exists)
- **Documentation**: In progress (this file being created)
- **Venv**: Not yet created (will be created by install_dtpyutil_deps.sh)
- **Code Migration**: Not started (dtpmenu code still in original location)
- **Outstanding Questions**: 3 questions awaiting user input

## Next Steps

1. **Answer Outstanding Questions** above
2. **Create folder structure** in `projects/dtpyutil/` per recommendations
3. **Create install_dtpyutil_deps.sh** (copy from dtpmenu, rename venv to dtpyutil)
4. **Implement `--output-file` support** in dtpmenu.py before migration
5. **Migrate dtpmenu code** to `src/menu/` in dtpyutil
6. **Create PROJECT-HISTORY.md** with condensed history from dtpmenu development
7. **Test imports** from another project (ads) to verify cross-project usage works
8. **Update Copilot Instructions** with dtpyutil venv usage guidelines
9. **Deprecate dtpmenu project** (rename folder or add deprecation notice)

## References

- **Original dtpmenu project**: `$DIVTOOLS/projects/dtpmenu/`
- **Critical bash integration docs**: `dtpmenu/docs/BASH-INTEGRATION.md`
- **PRD that led to this decision**: `projects/ads/native/docs/PRD-TUI.md`
- **Copilot Instructions**: `.github/copilot-instructions.md`
