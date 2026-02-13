# dtpmenu Project History

## 01/13/2026 - BREAKTHROUGH: Centering Fixed! ✅

**CRITICAL DISCOVERY:** Textual requires **exclusive stdout control** to properly center dialogs.

- **The Problem:** Users could not use `choice=$(dtpmenu_menu ...)` command substitution - menu appeared top-left, not centered
- **Root Cause Analysis:**
  - Command substitution `$()` pipes stdout to a buffer
  - Output redirection `>` redirects to file
  - Both break Textual's terminal detection (screen size = pipe/file size, not actual terminal)
  - Textual can't control terminal geometry → centering fails
- **Failed Attempts:**
  - Removed Container/Center/Middle wrappers
  - Applied CSS `align: center middle` (worked in test, not in wrapper)
  - Tried stdbuf utility (made it worse)
  - Tried PYTHONUNBUFFERED=1 with redirection (still broken)
- **The Fix:** 
  - **NO output capture during TUI execution** - allow direct terminal control
  - dtpmenu.py centers perfectly when called with `--h-center --v-center` flags
  - `demo_menu.sh` must run TUI directly without `$()` or `>`
  - Result: **PERFECT CENTERING** with clean, muted colors (Cyan/Grey/White)
- **Documentation:** Created [BASH-INTEGRATION.md](BASH-INTEGRATION.md) explaining:
  - Why command substitution breaks Textual
  - Correct patterns for bash wrappers
  - Debugging tips for terminal control issues
  - Real working examples from `demo_menu.sh`

**Status:** ✅ RESOLVED - Menu centers correctly, colors display properly

---

## 01/13/2026 - Project Initialization

- **Origin:** Created to replace Go (`dtmenu`) and Bash/Gum attempts.
- **Goal:** Robust "Centering Box" menu system using Python/Textual.
- **Status:** PRD Created. Pending User Approval.
- **Key Decisions:**
  - Use **Textual** library for layout engine.
  - Avoid custom Venv per script; aim for User/Global scope install.
  - Replicate `whiptail` feature set (`menu`, `msgbox`, `yesno`, `input`).
  - Explicit focus on visual correctness (Borders, Titles, Centering).

### ❓ OUTSTANDING - Qn: CSS Injection

**Question:** How to handle dynamic colors from CLI arguments in Textual?

- **Option A:** Generate a temporary `.css` file.
- **Option B:** Inject raw CSS string into `App.CSS` variable at runtime. (Preferred)

**Answer:**
(Pending Implementation) - Likely Option B is cleaner.
