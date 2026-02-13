# PRD: dtpmenu - Python/Textual Menu System

## 1. Overview

`dtpmenu` is a Python-based TUI (Text User Interface) library designed to replace `gum` and `whiptail` usage in Divtools bash scripts. It leverages the **Textual** library to provide a robust, visually accurate "boxed" interface with extensive capabilities for color, layout, and debugging.

The primary goal is to provide a "whiptail-replacement" that actually works with modern styling, centered layouts, and reliable tag returns, without the fragility of terminal escape code hacks.

## 2. Requirements

### 2.1 Functional Requirements (Component Parity with Whiptail)

The library must support the following modes, callable via command-line arguments:

1. **Menu (`--menu`)**
    - Display a scrollable list of items (Tag + Text).
    - Return the selected Tag (and optionally the Text).
    - Support arrow navigation and hotkeys.
    - Support "ESC" to exit from the menu/screen, back to prior or exit app.
    - **Selection:**
      - Visual highlight (invert colors).
      - User-selectable/specifiable colors for both Background and Foreground
      - Ability to select the menu item, press Enter and have it accept that as the input
      - Ability to press "Tab" once a menu item is selected, which navigates to Ok/Cancel buttons which can then be selected to process the Selected Item or Cancel.

2. **Message Box (`--msgbox`)**
    - Display a text message with an [OK] button.
    - Auto-wrap long text.
    - Support formatting (newlines, etc.).
    - Ability to Tab to buttons
3. **Yes/No (`--yesno`)**
    - Display a question with [Yes] and [No] buttons.
    - Return exit code 0 for Yes, 1 for No.
    - Ability to Tab to buttons
4. **Yes/No/Cancel (`--yesnocancel`)**
    - Display a question with [Yes] and [No] and [Cancel] buttons.
    - Return exit code 0 for Yes, 1 for No, -1 for Cancel.
    - Ability to Tab to buttons
5. **Input Box (`--inputbox`)**
    - Prompt for text input.
    - Return the typed string.
    - Ability to Tab to buttons
6. **Password Box (`--passwordbox`)**
    - Prompt for masked input.
    - Ability to Tab to buttons
7. **Text Box (`--textbox`)**
    - Display contents of a file (or stdin) in a scrollable view.
    - Support mouse selection.
    - Ability to Tab to buttons

### 2.2 Visual Requirements (The "Boxed" Standard)

- **Centered Window:** The UI essentially renders a "Dialog Window" centered horizontally and vertically on the terminal screen.
- **Borders:** The window must have a clear border (Double or Rounded style).
- **Title:**
  - Must be displayed **embedded in the top border**.
  - Must support ANSI coloring or Textual markup (e.g., `[bold red]My Title[/]`).
- **Dimensions:**
  - Support explicit `--width` and `--height` arguments.
  - Support percentage-based sizing (default to sensible auto-sizing).

### 2.3 Color & Styling Requirements

- **Configurable Colors:** The script must accept arguments to define the color scheme.
  - `--color-bg`: Background color of the box.
  - `--color-fg`: Text color.
  - `--color-select-bg`: Background of selected item.
  - `--color-select-fg`: Foreground of selected item.
  - `--color-button-fg`: Foreground of Button color
  - `--color-button-bg`: Background of Button color
- **Rich Text Support:**
  - Menu items and messages should support standard Rich/Textual markup (e.g., `[green]Success[/]`, `[red]Error[/]`). As well as RGB color codes (eg. [rgb(255,0,0)]red color[/]])
  - Menu items and messages should support icons and other special chars/emojis for display. These should also support coloring.
  - Menu item should also support an optional Selected Before/After char for accessibility to make identifying selected menu items easier (eg. --selected-before="[" --selected-after"]" would add [ menu text ] around menu items).
    - To add more space, it could be "[ " and " ]", otherwise, no space is added.
    - These extra chars would use:
    - `--color-bg` and `--color-fg` by default, but could also use:
    - `--color-select-char-bg` and `--color-select-char-fg` as the colors to use if specified.

### 2.4 Debugging Requirements

- **Debug Mode Flag (`--debug`):**
  - When enabled, preserve the exact line count requested.
  - Prepend a Line Number to **every line** of text displayed inside the box (e.g., `1: My Text`).
  - Update the Title to include the total line count (e.g., `My Title (14 lines)`).
  - This allows verification that no content is being truncated by the layout engine.

### 2.5 Technical Requirements

- **Language:** Python 3.10+ (System Python).
- **Library:** [Textual](https://textual.textualize.io/).
- **Environment:**
  - **No Virtual Environment:** Design to run with global packages if possible, or a single shared venv if absolutely necessary (but user prefers global install).
  - **Installation:** Script must check for `textual` and provide instructions/auto-install via `pip install --user textual` or `sudo pip install textual` if missing.
- **Wrapper Script:** Implementation must include a Bash wrapper (`dt_pmenu_lib.sh`) that makes calling the Python script feel native (like calling whiptail).

## 3. Implementation Strategy

### 3.1 Architecture

- **Core Script:** `projects/dtpmenu/dtpmenu.py`
  - Uses `argparse` to handle subcommands (`menu`, `msgbox`, etc.).
  - Uses `textual.app.App` to render the TUI.
  - Uses `textual.widgets` (Header, Footer, Static, Button, ListView).
  - CSS-based styling generated dynamically based on arguments.
- **Bash Wrapper:** `scripts/util/dt_pmenu_lib.sh`
  - Translates Bash function calls (`pmenu_msgbox "Title" ...`) into the Python command line.
  - Handles capture of stdout for results.

### 3.2 Installation & Dependencies

To ensure ease of use without venvs:

1. Check `python3 -c "import textual"`
2. If fail, `pip3 install --user textual` (User scope is cleaner than global).
3. Add `~/.local/bin` to PATH if needed.

**COMMENTS:** That DID not work. I had to do the following:

- sudo apt install python3-pip
- sudo apt install python3-textual
That is what was recommended for installing without a venv
Write an Install Script that can be used to install Python + Python-Textual.
The script should check if they exist, if they don't, it should ask if the user wants to install.
The script should check if they already exist, it should NOT re-install, but should output the version of each, check the latest version, and if they are different/newer, query the user if they want to "update" the current verions.

## 4. Proposed Command Line Usage

```bash
python3 dtpmenu.py menu \
    --title "System Setup" \
    --width 60 --height 20 \
    --color-select-bg "cyan" --color-select-fg "black" \
    "opt1" "Install Docker" \
    "opt2" "Check Status"
```

## 5. Timeline & Phases

1. **Phase 1: Basic Framework** - App loop, Argument parsing, Msgbox implementation.
2. **Phase 2: The Menu** - Scrollable list with "Tag" return value logic and Styling.
3. **Phase 3: Integration** - Debug mode implementation and Bash wrapper creation.
4. **Phase 4: Test Suite** - Write an entire test suite in pytest to test all options.
   - An entire TEST FRAME work exists here:
   - <https://textual.textualize.io/guide/testing/>
