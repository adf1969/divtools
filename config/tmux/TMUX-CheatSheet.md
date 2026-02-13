# tmux Cheat Sheet – Prefix: Ctrl+j or Ctrl+f  
(Your prefix is **`Ctrl+j`** or **`Ctrl+f`** – default **`Ctrl+b`** is **not** used)

### No-Prefix Movement Keys

| `Alt` + ← → ↑ ↓       | `Shift` + ← →         | `Ctrl` + `Shift` + ← →         |
|-----------------------|-----------------------|--------------------------------|
| Move between panes    | Prev / Next window    | Reorder window left / right    |


| Sessions / General                                      | Windows                                                | Panes                                                    | Copy Mode & Misc                                       |
|---------------------------------------------------------|--------------------------------------------------------|----------------------------------------------------------|--------------------------------------------------------|
| **New session**                                         | **Create new window**                                  | **Vertical split** (split -v)                            | **Enter copy mode**                                    |
| `tmux` / `tmux new`                                     | `Prefix` + c                                           | `Prefix` + s                                             | `Prefix` + [                                           |
| `tmux new -s name`                                      | `Prefix` + `Ctrl+c`                                    | **Horizontal split** (split -h)                          | **Start selection**                                    |
|                                                         |                                                        | `Prefix` + v                                             | Space                                                  |
| **Attach / Detach**                                     | **Rename window**                                      | **Move between panes**                                   | **Copy selection**                                     |
| `tmux a` / `tmux attach`                                | `Prefix` + r                                           | h = left, j = down, k = up, l = right                    | Enter                                                  |
| `tmux a -t name`                                        |                                                        | `Prefix` + h/j/k/l                                       | **Cancel selection**                                   |
| **Detach**                                              | **Kill window**                                        | **Next / Previous pane**                                 | Esc                                                    |
| `Prefix` + `Ctrl+d`                                     | `Prefix` + &                                           | `Prefix` + o (next)                                      | **Quit copy mode**                                     |
|                                                         |                                                        | `Prefix` + ; (last active)                               | q                                                      |
| **Next / Previous session**                             | **Next / Previous window**                             | **Last active pane**                                     | **Search forward/backward**                            |
| `Prefix` + ) / (                                        | `Prefix` + n / p                                       | `Prefix` + ;                                             | /  (forward)    ?  (backward)                          |
|                                                         | Shift+Left / Shift+Right (no prefix)                   |                                                          |                                                        |
| **Rename session**                                      | **Select window by number**                            | **Move pane left/right**                                 | **Paste from buffer**                                  |
| `Prefix` + $                                            | `Prefix` + 0…9                                         | `Prefix` + { / }                                         | `Prefix` + ]                                           |
|                                                         |                                                        |                                                          |                                                        |
| **List sessions**                                       | **List / Choose window**                               | **Kill pane**                                            | **Reload config**                                      |
| `tmux ls`                                               | `Prefix` + w                                           | `Prefix` + x                                             | `Prefix` + R                                           |
|                                                         |                                                        |                                                          |                                                        |
| **Synchronize panes**                                   | **Reorder windows**                                    | **Resize pane** (repeatable)                             | **Toggle mouse mode**                                  |
| `Prefix` + y   or   `Prefix` + *                        | Ctrl+Shift+Left / Ctrl+Shift+Right (no prefix)         | `Prefix` + , . - =                                       | `Prefix` + m                                           |
| (toggle on/off)                                         |                                                        | (left/right/down/up)                                     |                                                        |
|                                                         | **Jump to window by name**                             | **Zoom / Unzoom pane**                                   | **Last window**                                        |
|                                                         | `Prefix` + " (choose-window)                           | `Prefix` + z                                             | `Prefix` + `Ctrl+a`                                    |