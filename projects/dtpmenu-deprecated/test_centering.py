from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Static

class TestCentering(App):
    CSS = """
    Screen {
        background: blue;
        align: center middle;
    }
    #box {
        width: 20;
        height: 5;
        background: red;
        border: solid white;
    }
    """
    def compose(self) -> ComposeResult:
        yield Container(id="box")

if __name__ == "__main__":
    app = TestCentering()
    app.run()
