# dtmenu Project History

## 01/13/2026 - Project Initialization
- **Origin:** Created as a solution to limitations found in `gum choose` and `whiptail` regarding "Boxed" interfaces.
- **Goal:** Create a standalone Go binary using Charmbracelet libraries to render a perfect TUI menu.
- **Status:** Initial Setup.
- **Architectural Decision:** 
    - Use `bubbletea` for the event loop.
    - Use `bubbles/list` for the core component.
    - Use `lipgloss` for windowing/borders.
    - Application logic: Parse args -> Convert to List Items -> Run Model -> Print Selection to Stdout.

### ❓ OUTSTANDING - Qn: ANSI Handling
**Question:** How to ensure ANSI codes in item descriptions don't break the list rendering (length calculations)?
- **Option A:** Strip ANSI for length calculation, keep for rendering. (Ideal)
- **Option B:** Rely on Bubbles native ANSI handling (might be partial).

**Context/Impact:** If users pass colored strings (e.g. Red "Exit"), the TUI might misalign borders if it counts escape codes as visible characters.

### Answer
**Decision:** Option A (Implicit).
Bubbles/list and Lipgloss generally handle ANSI well, but we should verify. The `DefaultDelegate` in bubbles/list handles rendering; we may need a custom delegate if we want complex styling, but standard `list.NewItem` might just pass the string through. We will test this.
