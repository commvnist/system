# tmux

GNU Stow package for tmux configuration. Install tmux and GNU Stow with your
platform's package manager, then from the repository root:

```sh
stow -n -v --target="$HOME" --no-folding tmux
stow --target="$HOME" --no-folding tmux
```

This links `tmux/.tmux.conf` to `~/.tmux.conf`. Copy mode uses tmux OSC 52
clipboard support; the outer terminal must allow clipboard escape sequences.
The prefix is `Ctrl-a`; press it twice to send `Ctrl-a` to a program. Use
prefix `h/j/k/l` to move between panes. From inside Vim, use `Ctrl-h/j/k/l`
instead. See the [shortcut guide](../keybindings.md).
