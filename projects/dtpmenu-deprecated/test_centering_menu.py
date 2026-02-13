#!/home/divix/divtools/scripts/venvs/dtpmenu/bin/python
from textual.app import App, ComposeResult
from textual.containers import Container, Vertical, Horizontal
from textual.widgets import Static, ListView, ListItem, Label, Button
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

class TestCenteringWithMenu(App):
    CSS = """
    Screen {
        background: $background;
        color: $foreground;
        align: center middle;
    }
    #box {
        width: 70;
        height: 15;
        background: red;
        border: solid white;
        border-title-color: $primary;
        background: $surface;                
    }
    
    ListView {
        width: 100%;
        height: auto;
        max-height: 10;
        margin-bottom: 1;
    }
    
    Horizontal {
        width: 100%;
        height: auto;
    }
    """
    
    BINDINGS = [
        Binding("escape", "quit_app", "Exit"),
    ]
    
    def compose(self) -> ComposeResult:
        with Container(id="box"):
            # Create a simple menu
            items = [
                ListItem(Label("(1) Option 1"), id="item-1"),
                ListItem(Label("(2) Option 2"), id="item-2"),
                ListItem(Label("(3) Option 3"), id="item-3"),
            ]
            yield ListView(*items, id="menu-list")
            yield Horizontal(
                Button("OK", variant="primary", id="btn-ok"),
                Button("Cancel", variant="error", id="btn-cancel"),
            )
    
    def on_button_pressed(self, event: Button.Pressed):
        if event.button.id == "btn-ok":
            self.exit("ok")
        elif event.button.id == "btn-cancel":
            self.exit("cancel")
    
    def action_quit_app(self):
        self.exit()

if __name__ == "__main__":
    app = TestCenteringWithMenu()
    app.run()

