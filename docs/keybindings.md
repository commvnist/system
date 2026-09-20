# Keyboard shortcuts

The setup uses Vim's normal-mode movement keys as the common language. `h/j/k/l`
means left/down/up/right. Prefix means press `Ctrl-a`, release it, then press
the next key. Native Vim keys such as `Ctrl-w h/j/k/l` remain available.

| Where | Keys | Action |
| --- | --- | --- |
| Vim normal mode | `Ctrl-h/j/k/l` | Move to a split; at an edge, move to the adjacent tmux pane. |
| Vim normal mode | `Ctrl-\` | Previous Vim split, or previous tmux pane at an edge. |
| Vim normal mode | `Space v` / `Space s` | Vertical / horizontal split. |
| Vim normal mode | `Space w` / `Space q` | Write / quit the current window. |
| Vim normal mode | `Space h` | Clear search highlighting. |
| Vim normal mode | `[b` / `]b` | Previous / next buffer. |
| tmux | Prefix `h/j/k/l` | Move left/down/up/right between panes. Repeat direction keys briefly without another prefix. |
| tmux | Prefix `v` / `s` | Vertical / horizontal split, starting in the current directory. |
| tmux | Prefix `a` / `z` | Previous pane / zoom pane. |
| tmux | Prefix `c` | New window in the current directory. |
| tmux | Prefix `[` then `v`, `y` | Enter copy mode, select text, then copy. Prefix `]` pastes. |
| tmux | Prefix `R` | Reload the tmux configuration. |
| Zsh insert mode | `Esc` | Enter Vim command mode; `i` returns to insert mode. |
| Zsh command mode | `v` | Edit the command line in `$EDITOR`. |
| Zsh | `Ctrl-r`, `Ctrl-t`, `Alt-c` | fzf history, file, and directory search when fzf is installed. |
| Zsh | Up/Down | Search history for the text already typed, when the plugin is installed. |

`Ctrl-h/j/k/l` are mapped only **inside Vim**. Shell programs retain their
normal Ctrl keys; use the tmux prefix from a shell. Press prefix twice to send
`Ctrl-a` to a program inside tmux. Vim insert-mode Backspace and newline keep
their normal meanings.

The Starship prompt marks Vim insert mode with `❯` and command mode with `❮`.
Its icons use Nerd Font glyphs; select a Nerd Font in the outer terminal if
symbols render as boxes. This is a terminal setting, including on Windows
Terminal when using WSL2.
