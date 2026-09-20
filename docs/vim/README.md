# vim

GNU Stow package for Vim configuration. Install Vim and GNU Stow with your
platform's package manager, then from the repository root:

```sh
stow -n -v --target="$HOME" --no-folding vim
stow --target="$HOME" --no-folding vim
```

This links `vim/.vimrc` to `~/.vimrc`.

The configuration uses stock Vim with no plugin dependency. Press `Space` as
the leader key: `Space v` and `Space s` open vertical and horizontal splits;
`Space w` writes; `Space q` quits; `Space h` clears search highlighting.
`Ctrl-h/j/k/l` navigates splits and crosses into tmux at an edge. See the
[complete shortcut guide](../keybindings.md).
Use `[b` and `]b` to cycle buffers.

Swap, backup, and persistent undo state live under `~/.vim`. The configuration
creates those directories on startup if they are missing.
