# PRD: TUI Menu System Library

## 1. Overview

The goal is to develop a robust, reusable, and visually consistent Text User Interface (TUI) menu system for Bash scripts. This library must allow scripts to present interactive menus, message boxes, and input forms without the overhead of complex programming environments (like Python venvs) or fragile styling workarounds.

## 2. Requirements

### 2.1 Functional Requirements

- **Menu Selection:**
  - Display a list of options.
  - Return the selected Item Value (Tag) cleanly (e.g., "1", "install", "exit").
  - Support cancel/exit operations.
- **Visual Presentation:**
  - **Boxed Interface:** The menu must be contained within a visible border/box (e.g., Unicode lines `╔═╗`).
  - **Centering:** The box must be centered horizontally and vertically (or reasonably prioritized) on the screen.
  - **Header/Title:** Support for a clear title.
  - **Color:** Support for coloring specific text in menus or in other displays of text. This could be done with raw ANSI fed to the the app or with codes that are intepreted by the App.
- **Platform Compatibility:**
  - Must run on Ubuntu 22.04 LTS and 24.04 LTS.
  - Must be callable from standard Bash scripts.
- **Dependencies:**
  - Minimal prerequisites.
  - Avoid high-friction environments (e.g., requiring Python virtual environment activation for every simple script run).

### 2.2 Usability Requirements

- **Simple API:** The Bash function signature should be intuitive.
  - Example: `tui_menu "Title" "Option 1" "Option 2" ...`
- **Reliability:** Must handle user input errors gracefully (no crashes on invalid selection).

---

## 3. Technology Analysis & Options

The following tools were evaluated against the "Boxed Menu" requirement and Ubuntu compatibility.

| Feature | **Gum** (Charmbracelet) | **FZF** (Fuzzy Finder) | **Whiptail / Dialog** | **Custom Go Binary** |
| :--- | :--- | :--- | :--- | :--- |
| **Boxed Menu** | ❌ **Poor.** `gum choose` does not support a border around the list. Workarounds are fragile. | ✅ **Good.** Supports `--border`, `--header`, and margins natively. | ✅ **Excellent.** Built specifically as a windowed UI. | ✅ **Perfect.** Can be programmed exactly to spec. |
| **Visual Style** | Modern, inline, flat. | Minimalist, terminal-native. | Retro (Blue/Gray), ncurses style. | Fully customizable. |
| **Install** | External binary / Repo. | `apt install fzf` (easy). | Pre-installed on Ubuntu. | Requires build/install. |
| **Bash Usage** | Very easy. | Easy (pipe input). | Clunky (stdout/stderr redirection). | Very easy. |
| **Pros** | Beautiful *individual* elements. | Fast, filtering built-in. | Standard, trusted. | No limits on design. |
| **Cons** | **Cannot create a proper menu box** interactively. | Search-first paradigm might confuse some users. | Hard to style/modernize. | Maintenance overhead. |

---

## 4. Recommendations

### Option A: FZF (Recommended for Modern + Simple)

**Why:** FZF is lightweight, widely available, and surprisingly capable as a menu system. It supports borders, headers, and layout options (`--height`, `--reverse`, `--border`) out of the box.
**Visuals:** Clean, bordered box.
**Install:** `sudo apt install fzf`
**USER:** fzf will NOT WORK. WE tried that earlier. It was worse than gum. Ignore the fzf fever dream. It sucks.

### Option B: Whiptail (Recommended for Stability)

**Why:** It is the standard for Ubuntu installers. It guarantees the "Box" look because that is all it does.
**Visuals:** Retro ncurses (blue background).
**Install:** Pre-installed.
**USER:** Whiptail is lame for UI. COlors are garbage. It doesn't support ANY in-line colors in Menus, so it is a NON-STARTER!

### Option C: Custom Go Tool (Recommended for Specific Aesthetic)

**Why:** If the specific look of `gum` (colors/unicode) is desired BUT with a box, a small Go program using `bubbletea` is the only way to get exactly that combination.
**Visuals:** Exact match to requirements.
**Install:** Need to compile and place binary in `$DIVTOOLS/bin`.
**USER:** This may be the best option. Would it be possible to write the menu lib in Go using bubbletea and compile it, similar to what gum is then use that for the TUI?
How complicated would it be to build a simple Go binary that can be installed?
We could create a project for this and add the binary to Divtools and then it would be available on ALL systems.
No install necessary, just build once, and the binary is there.
I've never coded in Go, but it looks fairly simple.
Proceed with writing a simple Go binary.
Put the code in the:
projects/dtmenu/ folder.
As with all projects in the projects folder, follow guidelines in the CoPilot Instructions.
Here are some links to docs:
Lip Gloss: <https://github.com/charmbracelet/lipgloss>
Bubble Tea: <https://github.com/charmbracelet/bubbletea>
Bubbles (for lists): <https://github.com/charmbracelet/bubbles>
Termenv (color handling): <https://github.com/muesli/termenv>

Don't forget this requirement:

- **Color:** Support for coloring specific text in menus or in other displays of text. This could be done with raw ANSI fed to the the app or with codes that are intepreted by the App.
Probably the easiest way to do this is with Lipgoss, but it should also handle raw ANSI, not just begin/end flags to indicate specific styles or colors.

### Option D: Gum (NOT Recommended)

**Why:** As discovered, `gum` is designed for "inline" flows and fights against the concept of a stationary "windowed" box.

---

## 5. Proposed Implementation Strategy

We will implement a wrapper library `tui_lib.sh` that abstracts the underlying tool. This allows swapping the engine (Gum vs Fzf vs Whiptail) without changing the calling scripts.

### 5.1 Function Signature

```bash
# Display a menu and return the selected tag/value
# Usage: tui_menu "Title" "Tag1|Description1" "Tag2|Description2" ...
tui_menu() {
    local title="$1"
    shift
    local options=("$@")
    # ... Implementation ...
}
```

### 5.2 Next Steps

1. **Decision:** Select the primary engine (Recommend **FZF** or **Whiptail** for immediate stability).
2. **Develop:** Create `scripts/util/tui_lib.sh`.
3. **Refactor:** Update existing scripts to call `tui_menu`.

## COMMENTS: 1/14/2026 9:05:34 AM

It is clear that there is a BIG PROBLEM with attempting to call Python TUI code from Bash.
The entire system falls apart due to tty issues, basically:
```Command substitution $() / pipes / redirection ALWAYS breaks centering because they pipe stdout to a buffer (~4K x 0 size), making Textual think the "terminal" is tiny → top-left rendering.```
This makes writing ANY sort of "TUI Library" that is called from BASH impossible.
They all just fall apart due to the way the pipe/redirection is handled by BASH.
The ONLY solution is to dump BASH entirely.
If that is the only option, then migrating away from BASH calling any TUI/Python is the best approach.
To that end, I want you to implement the following:

- Create a venv to store ALL Divtools/Python Utilities. These would be utils that I might have previously written in Bash but will now be in Python.
  - That venv should be named: dtpyutil
- Install Python and Textual into that venv so it can be the place where dtpmenu runs from.
- Change dtpmenu so it runs from the dtpyutil venv
- Add content to CoPilot Instructions that for ALL Python Projects that use the library, they should use the dtpyutil venv.
- The goal will be that most python util scripts will use THAT venv since that will greatly simplify usage and install on this system and others.
- Those scripts will all be part of the dtpyutil project in the ./projects/dtpyutil/ folder.
- This means install_dtpmenu.deps.sh will be copied to the dtpyutil project.
  - It should be renamed to: install_dtpyutil_deps.sh
- Before implementing all of the changes, make recommendations as to the folder/file structure for *.py files added to that project. Recommend:
  - Should I create sub-folders for the "menu"?
  - Should I create sub-folders for "src" as well as "test" as well as "docs"?
  - Assume I will have multiple utilities that may exist here,, that use the menu system to test/run/operate. What about the "ads" project? It could use the dtpyutil venv to handle the menu, etc. How should I handle keeping these apps/projects separate and in their own dev box but allow them to still use differnet libraries/code that may be shared across apps?
  - I'm thinking just having them use a common "venv" to handle some components, but is it fine for an app in the "ads" folder to use a menu system or other library based code in the "dtpyutil" folder?
  - I need recommendations for how best to structure these items/files/folders.
  - Also assume that each project as it is developed, may have docs/test/comments during dev that I will want to track and store so when I make changes in the future, I can have have the history of development. Having ALL of that in one folder would be cumbersome, which is why breaking it out into "projects" folders is what I have done. I still want that separation, but I still will need projects in one dev folder the ability to access code/libs in another (eg. the ads project using dtpyutil menu code)
  - How can I best do that?
  - Put those project recommendations and other design details in the projects/dtpyutil/docs/PROJECT-DETAILS.md file. The purpose of the PROJECT-HISTORY.md is to store all of the HISTORY and ITERATIONS of Project Dev. The PROJECT-DETAILS.md should store the CURRENT project status.
    - This should be noted in that file.
  - Once the new project is created with the recommendations, I will answer any questions you have and then we will proceed with new project implementation/creation there.
  - Review the copilot instructions and use the Outstanding Questions format for any questions you have for the Project.
