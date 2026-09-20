# Keyboard shortcuts

The setup uses Vim's normal-mode movement keys as the common language. `h/j/k/l`
means left/down/up/right. Prefix means press `Ctrl-a`, release it, then press
the next key. Native Neovim keys such as `Ctrl-w h/j/k/l` remain available.

| Where | Keys | Action |
| --- | --- | --- |
| Neovim normal mode | `Ctrl-h/j/k/l` | Move to a split; at an edge, move to the adjacent tmux pane. |
| Neovim normal mode | `Ctrl-\` | Previous Neovim split, or previous tmux pane at an edge. |
| Neovim normal mode | `Space v` / `Space s` | Vertical / horizontal split. |
| Neovim normal mode | `Space w` / `Space q` | Write / quit the current window. |
| Neovim normal mode | `Space h` | Clear search highlighting. |
| Neovim normal mode | `[b` / `]b` | Previous / next buffer. |
| Neovim normal mode | `Space f f` / `Space f g` | Find files / search project text. |
| Neovim normal mode | `Space f b` / `Space f r` | Find open buffers / recent files. |
| Neovim normal mode | `Space f h` / `Space f k` | Find help / search all keybindings. |
| Neovim normal mode | `]h` / `[h` | Next / previous Git change. |
| Neovim normal mode | `Space g h` / `Space g b` | Preview Git change / blame line. |
| Neovim normal mode | `gcc` / visual `gc` | Toggle comment on a line / selection. |
| Neovim normal mode | `ys` + motion + character | Surround text, for example `ysiw"` quotes a word. |
| Neovim normal mode | `ds` + character / `cs` + old + new | Delete / replace surrounding text. |
| Neovim normal mode | `gd` / `K` | Go to definition / show hover help when LSP is attached. |
| Neovim normal mode | `Space c a` / `Space c r` | Code action / rename symbol. |
| Neovim normal mode | `Space c f` / `Space c d` | Format buffer / show diagnostics. |
| Neovim | `y` / `p` | Yank to / put from the host clipboard when a native provider is available. |
| tmux | Prefix `h/j/k/l` | Move left/down/up/right between panes. Repeat direction keys briefly without another prefix. |
| tmux | Prefix `v` / `s` | Vertical / horizontal split, starting in the current directory. |
| tmux | Prefix `a` / `z` | Previous pane / zoom pane. |
| tmux | Prefix `c` | New window in the current directory. |
| tmux | Prefix `t` / `T` | Next / previous window in the session. |
| tmux | Prefix `p` | Find or create a tmux session for a directory with sesh. |
| tmux | Prefix `L` | Return to the last session. |
| tmux | Prefix `w` | Browse sessions and windows. |
| tmux | Prefix `d` | Detach; `tmux attach` resumes the session later. |
| tmux | Prefix `?` | Show tmux keys, including descriptions of custom bindings. |
| tmux | Prefix `[` then `v`, `y` | Enter copy mode, select text, then copy to tmux and the host. Prefix `]` pastes from tmux. |
| tmux | Prefix `R` | Reload the tmux configuration. |
| Zsh insert mode | `Esc` | Enter Vim command mode; `i` returns to insert mode. |
| Zsh command mode | `v` | Edit the command line in `$EDITOR`. |
| Zsh | `Ctrl-r` / Up Arrow | Search local command history with Atuin. |
| Zsh | `Ctrl-t`, `Alt-c` | Find a file or directory with fzf. |
| Zsh | `Ctrl-p` / `Ctrl-n` | Previous / next Zsh history entry. |

Press `Space` and wait briefly for a hint menu showing the next keys. The
editor still uses standard Vim motions, operators, and text objects. Completion
appears automatically; use `Ctrl-n`/`Ctrl-p` to choose and `Ctrl-y` to accept.

`Ctrl-h/j/k/l` are mapped only **inside Neovim**. Shell programs retain their
normal Ctrl keys; use the tmux prefix from a shell. Press prefix twice to send
`Ctrl-a` to a program inside tmux. Neovim insert-mode Backspace and newline keep
their normal meanings.

The Starship prompt marks Vim insert mode with `❯` and command mode with `❮`.
Its icons use Nerd Font glyphs; select a Nerd Font in the outer terminal if
symbols render as boxes. This is a terminal setting, including on Windows
Terminal when using WSL2.
