# tmux

GNU Stow package for tmux configuration.

## Dependencies

```sh
sudo pacman -S --needed tmux
```

No AUR package is required.

Copy-mode clipboard integration uses tmux OSC 52 support, so no separate
`xclip`, `xsel`, or Wayland clipboard helper is required. The outer terminal
must allow clipboard escape sequences.

## Install

From the repository root:

```sh
stow tmux
```

This links `tmux/.tmux.conf` to `~/.tmux.conf`.
