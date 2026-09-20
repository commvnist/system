# tmux

Home Manager installs tmux and links `tmux/.tmux.conf` to `~/.tmux.conf`.
Run `bash bootstrap/home.sh switch` from the repository root after editing it.
Copy mode uses tmux OSC 52
clipboard support; the outer terminal must allow clipboard escape sequences.
The prefix is `Ctrl-a`; press it twice to send `Ctrl-a` to a program. Use
prefix `h/j/k/l` to move between panes. From inside Neovim, use `Ctrl-h/j/k/l`
instead. See the [shortcut guide](../keybindings.md).
