#!/home/divix/divtools/scripts/venvs/dtpmenu/bin/python
"""
dtpmenu - Textual-based TUI Dialog System for Bash Scripts

================================================================================
CRITICAL INTEGRATION INFORMATION
================================================================================

**⚠️ IMPORTANT FOR BASH INTEGRATION:**
- DO NOT capture stdout during execution: choice=$(dtpmenu ...) breaks centering
- DO NOT redirect output: dtpmenu ... > /tmp/file.txt breaks centering  
- DO allow Textual EXCLUSIVE terminal control for centering to work
- You CAN capture the exit code: dtpmenu...; status=$?
- You CAN capture printed output AFTER the TUI exits

================================================================================
USAGE MODES
================================================================================

1. MENU MODE
   Command: dtpmenu menu --h-center --v-center --title "Select Option" tag1 "Option 1" tag2 "Option 2"
   
   Args:
     - tag1 "Option 1" tag2 "Option 2" ...   (pairs of tag and description)
   
   Returns:
     - Prints selected tag to stdout when user clicks OK
     - Exit code 0 if selection made
     - Exit code 1 if user cancels
   
   Example:
     result=$(dtpmenu menu --title "Choose" a "Apple" b "Banana"; echo $?)
     # First line is the tag, second line is exit code
   
   Bash Pattern:
     pmenu_menu "Title" tag1 "Option 1" tag2 "Option 2"

2. MESSAGE BOX MODE
   Command: dtpmenu msgbox --h-center --v-center --title "Title" "Message text with \\\\n for newlines"
   
   Args:
     - Message text (supports \\n escapes for newlines)
   
   Returns:
     - Nothing printed to stdout
     - Exit code 0 on success
   
   Bash Pattern:
     pmenu_msgbox "Title" "Message with \\\\n newlines"

3. YES/NO DIALOG MODE
   Command: dtpmenu yesno --h-center --v-center --title "Title" "Question text"
   
   Args:
     - Question text
   
   Returns:
     - Nothing printed to stdout
     - Exit code 0 if user clicks "Yes"
     - Exit code 1 if user clicks "No"
   
   Example:
     dtpmenu yesno --title "Confirm" "Delete everything?"
     if [[ $? -eq 0 ]]; then
         echo "User confirmed YES"
     else
         echo "User chose NO"
     fi
   
   Bash Pattern:
     pmenu_yesno "Title" "Question text"

4. INPUT BOX MODE
   Command: dtpmenu inputbox --h-center --v-center --title "Title" "Prompt" --default "DefaultValue"
   
   Args:
     - Prompt text
     - --default "value" (optional)
   
   Returns:
     - Prints user input to stdout when user clicks OK
     - Exit code 0 if user clicks OK
     - Exit code 1 if user clicks Cancel
   
   Example:
     user_input=$(dtpmenu inputbox --title "Login" "Username:" --default "admin"; echo $?)
     # First line is the input text, second is exit code
   
   Bash Pattern:
     pmenu_inputbox "Title" "Prompt" "DefaultValue"

================================================================================
COMMON FLAGS
================================================================================

--h-center          Enable horizontal centering (REQUIRED for centering)
--v-center          Enable vertical centering (REQUIRED for centering)
--title "Text"      Dialog title (shown in border)
--width N           Override dialog width (default: 70)
--height N          Override dialog height (default: 15)
--debug             Enable debug output to stderr
--default "value"   Default input for inputbox mode (only for inputbox)

================================================================================
CAPTURING RESULTS IN BASH
================================================================================

THE WRONG WAY (BREAKS CENTERING):
  choice=$(pmenu_menu "Title" tag1 "Option 1")  # ❌ Command substitution!

THE RIGHT WAY (WORKS):
  pmenu_menu "Title" tag1 "Option 1"            # ✅ Direct execution
  # User interacts with TUI, selects, dialog closes
  # TUI output goes directly to terminal (no capture)

CAPTURING EXIT CODE (ALWAYS WORKS):
  pmenu_yesno "Confirm?" "Proceed?"
  if [[ $? -eq 0 ]]; then
      echo "User said yes"
  fi

CAPTURING OUTPUT + EXIT CODE (POST-EXECUTION):
  # For modes that print output (menu, inputbox)
  result=$(pmenu_menu "Title" tag1 "Option1"; echo $?)
  # Split the output into separate lines to get exit code and result
  exit_code=$(echo "$result" | tail -1)
  selection=$(echo "$result" | head -1)

================================================================================
WRAPPER LIBRARY (RECOMMENDED)
================================================================================

Use the bash wrapper library instead of calling dtpmenu directly:
  source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
  
  export PMENU_H_CENTER=1    # Enable centering
  export PMENU_V_CENTER=1

  # Menu
  pmenu_menu "Title" tag1 "Option 1" tag2 "Option 2"
  
  # Message box
  pmenu_msgbox "Title" "Message"
  
  # Yes/No (can check $? immediately after)
  pmenu_yesno "Confirm?" "Really delete?"
  if [[ $? -eq 0 ]]; then echo "Yes"; fi
  
  # Input box
  user_input=$(pmenu_inputbox "Login" "Username:" "admin")

The wrapper library automatically:
- Sets --h-center and --v-center flags
- Uses PYTHONUNBUFFERED=1 for proper I/O
- Respects PMENU_H_CENTER, PMENU_V_CENTER environment variables
- Respects DEBUG_MODE environment variable

See: $DIVTOOLS/scripts/util/dt_pmenu_lib.sh

================================================================================
EXAMPLE BASH SCRIPTS
================================================================================

EXAMPLE 1: Simple Menu Display
  #!/bin/bash
  source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
  export PMENU_H_CENTER=1 PMENU_V_CENTER=1
  
  pmenu_menu "Main Menu" \\
      "new" "Create New Item" \\
      "edit" "Edit Existing" \\
      "delete" "Delete Item" \\
      "exit" "Exit Program"

EXAMPLE 2: Decision Dialog with Action
  #!/bin/bash
  source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
  export PMENU_H_CENTER=1 PMENU_V_CENTER=1
  
  if pmenu_yesno "Dangerous Operation" "Delete user account?"; then
      # User confirmed (exit code 0)
      pmenu_msgbox "Success" "Account deleted"
  else
      # User cancelled (exit code 1)
      pmenu_msgbox "Cancelled" "Operation aborted"
  fi

EXAMPLE 3: Getting User Input
  #!/bin/bash
  source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
  export PMENU_H_CENTER=1 PMENU_V_CENTER=1
  
  # Direct execution (no capture) - user enters data
  pmenu_inputbox "Setup" "Enter system hostname:" "default-host"
  
  # After TUI completes, user has provided input
  # For actual input capture, modify dtpmenu.py to write to --output-file

EXAMPLE 4: chained Menus (with exit codes)
  #!/bin/bash
  source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
  export PMENU_H_CENTER=1 PMENU_V_CENTER=1
  
  while true; do
      pmenu_menu "Main Menu" "create" "Create" "delete" "Delete" "exit" "Exit"
      # Can check $? here for menu success/cancel
      break  # For demo
  done

================================================================================
ENVIRONMENT SETUP
================================================================================

The wrapper library requires:
  - $DIVTOOLS variable set
  - Virtual environment at: $DIVTOOLS/scripts/venvs/dtpmenu/

To install:
  cd $DIVTOOLS
  bash projects/dtpmenu/install_dtpmenu_deps.sh

To verify:
  source scripts/util/dt_pmenu_lib.sh
  check_dtpmenu_deps  # Returns 0 if ready, non-zero if missing

================================================================================
DOCUMENTATION
================================================================================

- BASH-INTEGRATION.md      : Detailed guide on bash wrapper patterns
- SOLUTION-SUMMARY.md      : How centering issue was solved
- QUICK-REFERENCE.md       : Quick lookup for common patterns
- PROJECT-HISTORY.md       : Development timeline and decisions

All docs in: $DIVTOOLS/projects/dtpmenu/docs/

================================================================================
"""

# Tool for creating TUI menus using Textual
# Last Updated: 01/14/2026 12:45:00 PM CDT

import sys
import os
import argparse
import json
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, ListView, ListItem, Label, Button, Static, Input
from textual.containers import Container, Vertical, Horizontal
from textual.binding import Binding
from textual.theme import Theme

# Cyan/Grey/White theme - muted/dark palette (original colors)
DIVTOOLS_THEME = Theme(
    name="divtools",
    primary="#0087af",     # Muted Cyan (Titles) - was bright #00ffff
    secondary="#005f87",   # Dark cyan (Secondary)
    accent="#d0d0d0",      # Light grey (Borders/Accents) - was bright white
    foreground="#d0d0d0",  # Light grey (Text) - was bright white
    background="#000000",  # Black (Screen Background)
    surface="#1c1c1c",     # Very dark grey (Dialog Background)
    success="#00af00",     # Muted green
    error="#af0000",       # Muted red - was bright #ff0000
    warning="#afaf00",     # Muted yellow
)

class DtpMenuApp(App):
    # Disable mouse support to avoid trash characters in terminal
    # when user moves mouse. This prevents conflicts between Textual
    # mouse handling and terminal mouse support.
    ENABLE_COMMAND_PALETTE = False
    
    CSS = """
    Screen {
        background: $background;
        color: $foreground;
        align: center middle;
    }

    #dialog-window {
        width: 70;
        height: 15;
        background: $surface;
        border: thick $accent;
        border-title-align: center;
        border-title-color: $primary;
        padding: 1 2;
    }

    ListView {
        width: 100%;
        height: auto;
        max-height: 10;
        margin-bottom: 1;
        background: transparent;
    }

    ListItem {
        width: auto;
        padding: 0 1;
    }

    ListItem.--highlight {
        background: $primary;
        color: #000000;
    }

    .buttons {
        width: 100%;
        height: auto;
        margin-top: 1;
        align-horizontal: center;
    }

    Horizontal {
        width: 100%;
        height: auto;
    }

    Button {
        margin: 0 1;
    }

    .message-text {
        text-align: center;
        margin-bottom: 1;
        width: auto;
    }

    Input {
        margin-bottom: 1;
        border: solid $accent;
    }
    """
    
    
    BINDINGS = [
        Binding("escape", "quit_app", "Cancel/Exit"),
    ]

    def __init__(self, mode, title, content_data, width, height, colors, h_center=False, v_center=False, debug=False, output_file=None):
        super().__init__()
        # Disable mouse support to prevent trash characters in terminal
        self.mouse_support = False
        self.mode = mode
        self.title_text = title
        self.content_data = self._process_content_data(content_data)
        self.custom_width = width
        self.custom_height = height
        self.custom_colors = colors
        self.h_center = h_center
        self.v_center = v_center
        self.debug_mode = debug
        self.result = None
        self.exit_code = 1
        # File-based IPC for bash integration (fixes command substitution centering issue)
        # Priority: CLI arg > env var > None
        self.output_file = output_file or os.getenv('PMENU_OUTPUT_FILE')

    def _write_output_file(self, value):
        """Write result to output file for bash integration.
        
        This fixes the command substitution centering issue by allowing bash scripts
        to read results from a file AFTER the TUI exits, instead of capturing stdout
        during execution (which breaks Textual's terminal detection).
        """
        if self.output_file:
            try:
                with open(self.output_file, 'w') as f:
                    f.write(str(value))
                if self.debug_mode:
                    print(f"[DEBUG] Wrote result to file: {self.output_file}", file=sys.stderr)
            except IOError as e:
                if self.debug_mode:
                    print(f"[ERROR] Failed to write output file {self.output_file}: {e}", file=sys.stderr)

    def _process_content_data(self, data):
        if isinstance(data, str):
            return data.replace("\\n", "\n")
        elif isinstance(data, list):
            return [(tag, text.replace("\\n", "\n")) for tag, text in data]
        elif isinstance(data, dict):
            new_data = data.copy()
            if "text" in new_data:
                new_data["text"] = new_data["text"].replace("\\n", "\n")
            return new_data
        return data

    def on_mount(self) -> None:
        try:
            container = self.query_one("#dialog-window")
            if self.title_text:
                container.border_title = self.title_text
            
            if self.custom_width and self.custom_width > 0:
                container.styles.width = self.custom_width
            if self.custom_height and self.custom_height > 0:
                container.styles.height = self.custom_height
        except:
            pass

    def compose(self) -> ComposeResult:
        with Container(id="dialog-window"):
            if self.mode == "menu":
                yield from self._compose_menu()
            elif self.mode == "msgbox":
                yield from self._compose_msgbox()
            elif self.mode == "yesno":
                yield from self._compose_yesno()
            elif self.mode == "inputbox":
                yield from self._compose_inputbox()

    def _compose_menu(self):
        items = []
        if self.content_data:
            for i, (tag, text) in enumerate(self.content_data):
                display_text = f"({i+1}) {text}"
                items.append(ListItem(Label(display_text), id=f"item-{tag}"))
        
        yield ListView(*items, id="menu-list")
        yield Horizontal(
            Button("Select", variant="primary", id="btn-select"),
            Button("Cancel", variant="error", id="btn-cancel"),
            classes="buttons"
        )

    def _compose_msgbox(self):
        msg = self.content_data if self.content_data else ""
        yield Static(msg, classes="message-text")
        yield Horizontal(
            Button("OK", variant="primary", id="btn-ok"),
            classes="buttons"
        )

    def _compose_yesno(self):
        msg = self.content_data if self.content_data else ""
        yield Static(msg, classes="message-text")
        yield Horizontal(
            Button("Yes", variant="success", id="btn-yes"),
            Button("No", variant="error", id="btn-no"),
            classes="buttons"
        )

    def _compose_inputbox(self):
        msg = self.content_data.get("text", "")
        default = self.content_data.get("default", "")
        
        yield Static(msg, classes="message-text")
        yield Input(value=default, id="input-field")
        yield Horizontal(
             Button("OK", variant="primary", id="btn-ok"),
             Button("Cancel", variant="error", id="btn-cancel"),
             classes="buttons"
        )

    def on_list_view_selected(self, event: ListView.Selected):
        self.result = str(event.item.id).replace("item-", "")
        self.exit_code = 0
        self._write_output_file(self.result)
        self.exit(self.result)

    def on_button_pressed(self, event: Button.Pressed):
        btn_id = event.button.id
        if btn_id == "btn-select":
            list_view = self.query_one("#menu-list")
            if list_view.highlighted_child:
                self.result = str(list_view.highlighted_child.id).replace("item-", "")
                self.exit_code = 0
                self._write_output_file(self.result)
                self.exit(self.result)
        elif btn_id == "btn-cancel":
            self.exit_code = 1
            self.exit()
        elif btn_id == "btn-ok":
            if self.mode == "inputbox":
                self.result = self.query_one("#input-field").value
            else:
                self.result = "ok"
            self.exit_code = 0
            self._write_output_file(self.result)
            self.exit(self.result)
        elif btn_id == "btn-yes":
            self.result = "yes"
            self.exit_code = 0
            self._write_output_file("yes")
            self.exit("yes")
        elif btn_id == "btn-no":
            self.result = "no"
            self.exit_code = 1
            self._write_output_file("no")
            self.exit("no")

    def action_quit_app(self):
        self.exit_code = 1
        self.exit()

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
        
    parser = argparse.ArgumentParser()
    parser.add_argument("mode")
    parser.add_argument("--title", default="divtools")
    parser.add_argument("--default", default="")
    parser.add_argument("--width", type=int, default=0)
    parser.add_argument("--height", type=int, default=0)
    parser.add_argument("--colors")
    parser.add_argument("--h-center", action="store_true")
    parser.add_argument("--v-center", action="store_true")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--output-file", type=str, help="Write result to file instead of stdout (for bash integration)")
    parser.add_argument("--output-file", type=str, help="Write result to file instead of stdout (for bash integration)")
    
    args, remainder = parser.parse_known_args()
    
    content_data = None
    if args.mode == "menu":
        if len(remainder) >= 2:
            content_data = []
            for i in range(0, len(remainder), 2):
                if i + 1 < len(remainder):
                    content_data.append((remainder[i], remainder[i+1]))
        elif len(remainder) == 1:
            try:
                content_data = json.loads(remainder[0])
            except:
                content_data = remainder[0]
    elif args.mode == "inputbox":
        content_data = {"text": " ".join(remainder), "default": args.default}
    else:
        content_data = " ".join(remainder)

    app = DtpMenuApp(
        args.mode, 
        args.title, 
        content_data, 
        args.width, 
        args.height, 
        args.colors, 
        h_center=args.h_center, 
        v_center=args.v_center,
        debug=args.debug,
        output_file=args.output_file
    )
    
    app.run()
    if app.result is not None:
        print(app.result)
    sys.exit(app.exit_code)

if __name__ == "__main__":
    main()
