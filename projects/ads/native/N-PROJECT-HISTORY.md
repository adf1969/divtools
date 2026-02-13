# Native ADS Project History

## 01/13/2026 - TUI Library PRD Creation
- **User Feedback:** User reported significant issues with `gum` usage in `gum_util.sh`, specifically regarding "Boxed" layouts and selection errors.
- **Action:**
    - Analyzed limitations of `gum` for "boxed" interactive menus (it is designed for inline flows).
    - Removed broken "Fake Box" implementation from `gum_util.sh` to prevent user confusion.
    - Created **PRD-TUI.md** in `docs/` to analyze alternatives (FZF, Whiptail, Custom Go) and propose a robust solution.
- **Decision:** Recommended switching to FZF or Whiptail for reliable "Boxed" menus on Ubuntu.
- **Status:** Completed. Platform switched to Python/Textual.

## 01/13/2026 - Implementation of `dtpmenu` (Python/Textual)
- **User Decision:** Switched from `gum`/`go` to Python + Textual library for the TUI system.
- **Action:**
    - Developed `dtpmenu.py` using Textual for high-quality TUI elements.
    - Implemented a bash wrapper library `scripts/util/dt_pmenu_lib.sh` that utilizes a virtual environment to avoid PEP 668 issues.
    - Added support for `border_title`, hotkey selection (1-9), and line numbers in menus.
    - Created `projects/dtpmenu/demo_menu.sh` for interactive verification.
- **Fixes:**
    - Resolved `InvalidThemeError` by properly registering themes.
    - Resolved `MountError` by fixing generator yielding in `compose`.
    - Fixed `demo_menu.sh` hang and added timing/debug/result capture features.
- **Current Version:** 01/13/2026 04:30 PM CDT
- **Status:** Ready for final user testing.
